"""Flask HTTP wrapper for Supabase → FCM push (DigitalOcean Droplet)."""

from flask import Flask, jsonify, request

from push_logic import process_webhook

app = Flask(__name__)


@app.get("/health")
def health():
    return jsonify({"ok": True})


@app.post("/alarm")
@app.post("/v1/alarm")
def alarm():
    status, payload = process_webhook(
        request.get_data(as_text=True),
        {k: v for k, v in request.headers},
    )
    return jsonify(payload), status
