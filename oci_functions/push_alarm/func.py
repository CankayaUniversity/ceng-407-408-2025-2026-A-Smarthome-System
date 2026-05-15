"""
OCI Function (Fn): Supabase Database Webhook (public.events INSERT) → FCM HTTP v1.

Mevcut Supabase şeması: `events` satırında çoğu zaman yalnızca `device_id` dolu;
`user_id` boşsa `devices` tablosundan sahip okunur (current_supabase export).

Environment:
  WEBHOOK_SECRET, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, FCM_PROJECT_ID,
  GOOGLE_SERVICE_ACCOUNT_JSON, FCM_ANDROID_CHANNEL_ID (optional)

İsteğe bağlı filtreler (motion_detected gibi gürültülü olayları bastırmak için):
  PUSH_SKIP_EVENT_TYPES — virgülle ayrılmış küçük harf event_type (varsayılan: motion_detected)
  PUSH_MIN_PRIORITY — info | warning | high | critical — bu ve üzeri önceliklere push (varsayılan: warning)

Deploy: fn deploy --app <app>; API Gateway POST /v1/alarm → bu fonksiyon.
"""

from __future__ import annotations

import base64
import hmac
import io
import json
import logging
import os
from typing import Any, Dict, List, Optional, Tuple

import requests
from fdk import response

LOGGER = logging.getLogger(__name__)
LOGGER.setLevel(logging.INFO)

FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"

_PRIORITY_RANK = {"info": 0, "warning": 1, "high": 2, "critical": 3}


def handler(ctx, data: io.BytesIO = None):
    try:
        raw = data.getvalue().decode("UTF-8") if data else "{}"
    except Exception as exc:  # pylint: disable=broad-exception-caught
        LOGGER.exception("decode body")
        return _json_response(ctx, 400, {"error": "invalid_body", "detail": str(exc)})

    try:
        body: Dict[str, Any] = json.loads(raw or "{}")
    except json.JSONDecodeError as exc:
        return _json_response(ctx, 400, {"error": "invalid_json", "detail": str(exc)})

    try:
        secret_got = _header_ci(ctx, "x-webhook-secret") or os.environ.get(
            "HTTP_X_WEBHOOK_SECRET", ""
        )
    except Exception as exc:  # pylint: disable=broad-exception-caught
        LOGGER.warning("header read: %s", exc)
        secret_got = os.environ.get("HTTP_X_WEBHOOK_SECRET", "")

    secret_expected = os.environ.get("WEBHOOK_SECRET", "")
    if not _safe_equal(secret_expected, secret_got or ""):
        return _json_response(ctx, 401, {"error": "unauthorized"})

    record = body.get("record")
    if not isinstance(record, dict):
        record = (body.get("payload") or {}).get("record")
    if not isinstance(record, dict):
        return _json_response(ctx, 400, {"error": "missing_record"})

    supabase_url = os.environ.get("SUPABASE_URL", "").rstrip("/")
    service_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
    project_id = os.environ.get("FCM_PROJECT_ID", "")
    sa_raw = os.environ.get("GOOGLE_SERVICE_ACCOUNT_JSON", "")

    if not all([supabase_url, service_key, project_id, sa_raw]):
        LOGGER.error("missing required environment variables")
        return _json_response(ctx, 500, {"error": "server_misconfiguration"})

    should_push, skip_reason = _should_send_push(record)
    if not should_push:
        return _json_response(
            ctx,
            200,
            {"ok": True, "skipped": True, "reason": skip_reason},
        )

    try:
        user_id = _resolve_recipient_user_id(supabase_url, service_key, record)
    except requests.RequestException as exc:
        LOGGER.exception("resolve user")
        return _json_response(ctx, 502, {"error": "supabase_failed", "detail": str(exc)})

    if not user_id:
        return _json_response(
            ctx,
            404,
            {"error": "no_recipient_user", "detail": "events.user_id empty and devices.user_id missing"},
        )

    try:
        tokens = _fetch_fcm_tokens(supabase_url, service_key, str(user_id))
    except requests.RequestException as exc:
        LOGGER.exception("supabase rest")
        return _json_response(ctx, 502, {"error": "supabase_failed", "detail": str(exc)})

    if not tokens:
        return _json_response(ctx, 404, {"error": "no_fcm_tokens", "user_id": str(user_id)})

    try:
        access_token = _get_fcm_access_token(sa_raw)
    except Exception as exc:  # pylint: disable=broad-exception-caught
        LOGGER.exception("google oauth")
        return _json_response(ctx, 502, {"error": "oauth_failed", "detail": str(exc)})

    title, msg_body = _event_notification_copy(record)

    channel_id = os.environ.get("FCM_ANDROID_CHANNEL_ID", "smarthome_alerts")
    results: List[Dict[str, Any]] = []
    for tok in tokens:
        try:
            status, resp = _send_fcm_v1(
                project_id, access_token, tok, title, msg_body, record, channel_id
            )
            results.append(
                {"status": status, "token_tail": tok[-10:], "fcm": resp}
            )
        except requests.RequestException as exc:
            LOGGER.exception("fcm post")
            results.append({"token_tail": tok[-10:], "error": str(exc)})

    return _json_response(ctx, 200, {"ok": True, "deliveries": results})


def _should_send_push(record: Dict[str, Any]) -> Tuple[bool, str]:
    event_type = str(record.get("event_type") or "").strip().lower()
    raw_skip = os.environ.get("PUSH_SKIP_EVENT_TYPES", "motion_detected")
    skip_types = {
        x.strip().lower()
        for x in raw_skip.split(",")
        if x.strip()
    }
    if event_type in skip_types:
        return False, "skip_event_type"

    priority = str(record.get("priority") or "").strip().lower()
    min_p = os.environ.get("PUSH_MIN_PRIORITY", "warning").strip().lower()
    need = _PRIORITY_RANK.get(min_p, 1)
    have = _PRIORITY_RANK.get(priority, -1)
    if have < need:
        return False, "skip_priority"
    return True, ""


def _resolve_recipient_user_id(
    base_url: str, service_key: str, record: Dict[str, Any]
) -> Optional[str]:
    uid = record.get("user_id")
    if uid:
        return str(uid)

    device_id = record.get("device_id")
    if not device_id:
        return None

    r = requests.get(
        f"{base_url}/rest/v1/devices",
        params={"id": f"eq.{device_id}", "select": "user_id"},
        headers={
            "apikey": service_key,
            "Authorization": f"Bearer {service_key}",
        },
        timeout=20,
    )
    r.raise_for_status()
    rows = r.json()
    if not rows:
        return None
    owner = rows[0].get("user_id")
    return str(owner) if owner else None


def _json_response(ctx, status: int, obj: Dict[str, Any]):
    return response.Response(
        ctx,
        response_data=json.dumps(obj),
        headers={"Content-Type": "application/json"},
        status_code=status,
    )


def _safe_equal(expected: str, got: str) -> bool:
    if not expected or not got:
        return False
    if len(expected) != len(got):
        return False
    try:
        return hmac.compare_digest(expected.encode("utf-8"), got.encode("utf-8"))
    except Exception:  # pylint: disable=broad-exception-caught
        return False


def _header_ci(ctx, name: str) -> str | None:
    try:
        hdrs = ctx.Headers()
    except Exception:  # pylint: disable=broad-exception-caught
        return None
    if not hdrs:
        return None
    for key, val in hdrs.items():
        if str(key).lower() == name.lower():
            if isinstance(val, list) and val:
                return str(val[0])
            return str(val)
    return None


def _parse_service_account_json(raw: str) -> Dict[str, Any]:
    raw = raw.strip()
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        decoded = base64.b64decode(raw).decode("utf-8")
        return json.loads(decoded)


def _get_fcm_access_token(sa_raw: str) -> str:
    from google.auth.transport.requests import Request as GoogleAuthRequest
    from google.oauth2 import service_account

    info = _parse_service_account_json(sa_raw)
    creds = service_account.Credentials.from_service_account_info(
        info, scopes=[FCM_SCOPE]
    )
    creds.refresh(GoogleAuthRequest())
    if not creds.token:
        raise RuntimeError("empty access token after refresh")
    return creds.token


def _fetch_fcm_tokens(base_url: str, service_key: str, user_id: str) -> List[str]:
    params = {"user_id": f"eq.{user_id}", "select": "fcm_token"}
    r = requests.get(
        f"{base_url}/rest/v1/user_devices",
        params=params,
        headers={
            "apikey": service_key,
            "Authorization": f"Bearer {service_key}",
        },
        timeout=20,
    )
    r.raise_for_status()
    rows = r.json()
    out: List[str] = []
    for row in rows:
        t = row.get("fcm_token")
        if t:
            out.append(str(t))
    return out


def _event_notification_copy(record: Dict[str, Any]) -> Tuple[str, str]:
    event_type = str(record.get("event_type") or "Event")
    priority = str(record.get("priority") or "")
    title = event_type.replace("_", " ").title()
    if priority:
        title = f"{title} · {priority}"
    body = str(record.get("message") or "Smart home notification.")
    return title, body


def _send_fcm_v1(
    project_id: str,
    access_token: str,
    token: str,
    title: str,
    body: str,
    record: Dict[str, Any],
    channel_id: str,
) -> Tuple[int, Any]:
    url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
    event_id = str(record.get("id") or "")
    msg = {
        "message": {
            "token": token,
            "notification": {"title": title, "body": body},
            "data": {
                "event_id": event_id,
                "event_type": str(record.get("event_type") or ""),
                "priority": str(record.get("priority") or ""),
                "device_id": str(record.get("device_id") or ""),
            },
            "android": {
                "priority": "HIGH",
                "notification": {
                    "channel_id": channel_id,
                    "sound": "default",
                },
            },
            "apns": {
                "headers": {"apns-priority": "10"},
                "payload": {
                    "aps": {
                        "alert": {"title": title, "body": body},
                        "sound": "default",
                    }
                },
            },
        }
    }
    r = requests.post(
        url,
        headers={
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json; charset=UTF-8",
        },
        data=json.dumps(msg),
        timeout=25,
    )
    try:
        parsed = r.json()
    except Exception:  # pylint: disable=broad-exception-caught
        parsed = {"raw": r.text}
    return r.status_code, parsed
