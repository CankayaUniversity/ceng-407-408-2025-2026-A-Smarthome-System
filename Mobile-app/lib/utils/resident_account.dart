import 'package:flutter/material.dart';

enum ResidentAccountTone { success, warning, info }

class ResidentAccountBadge {
  final String label;
  final String title;
  final IconData icon;
  final ResidentAccountTone tone;

  const ResidentAccountBadge({
    required this.label,
    required this.title,
    required this.icon,
    required this.tone,
  });
}

bool residentHasLoginAccount(Map<String, dynamic>? resident) {
  if (resident == null) return false;
  return resident['auth_user_id'] != null || resident['account_email'] != null;
}

String? getResidentAuthUserId(Map<String, dynamic>? resident) {
  return resident?['auth_user_id']?.toString();
}

bool _truthyFlag(dynamic value) => value == true || value == 'true';

ResidentAccountBadge? getResidentAccountBadge(Map<String, dynamic> resident) {
  if (!residentHasLoginAccount(resident)) return null;

  final status = resident['_authStatus'];
  final st = status is Map ? status : null;
  final email = resident['account_email']?.toString();

  if (st != null) {
    if (_truthyFlag(st['force_password_change'])) {
      return ResidentAccountBadge(
        label: 'Awaiting setup',
        title: email == null || email.isEmpty
            ? 'Invite sent; waiting for password setup.'
            : '$email must open the invite email and set a password.',
        icon: Icons.mark_email_unread_outlined,
        tone: ResidentAccountTone.warning,
      );
    }
    if (st['email_confirmed_at'] == null) {
      return ResidentAccountBadge(
        label: 'Awaiting email',
        title: email == null || email.isEmpty
            ? 'Waiting for email confirmation.'
            : 'Waiting for $email to confirm their email address.',
        icon: Icons.mail_outline,
        tone: ResidentAccountTone.warning,
      );
    }
    if (st['last_sign_in_at'] == null) {
      return ResidentAccountBadge(
        label: 'Setup pending',
        title: email == null || email.isEmpty
            ? 'Email confirmed; waiting for first sign-in.'
            : '$email has not signed in yet.',
        icon: Icons.schedule,
        tone: ResidentAccountTone.info,
      );
    }
    return ResidentAccountBadge(
      label: 'Account active',
      title: email == null || email.isEmpty
          ? 'Login account is active.'
          : '$email can sign in to their dashboard.',
      icon: Icons.check_circle,
      tone: ResidentAccountTone.success,
    );
  }

  if (getResidentAuthUserId(resident) == null) {
    return ResidentAccountBadge(
      label: 'Invite sent',
      title: email == null || email.isEmpty
          ? 'Login invite recorded.'
          : 'Login linked to $email. Refresh after Supabase auth status RPC is available.',
      icon: Icons.mail_outline,
      tone: ResidentAccountTone.warning,
    );
  }

  return ResidentAccountBadge(
    label: 'Invite sent',
    title: email == null || email.isEmpty
        ? 'Login invite pending.'
        : 'Login email: $email.',
    icon: Icons.mail_outline,
    tone: ResidentAccountTone.warning,
  );
}
