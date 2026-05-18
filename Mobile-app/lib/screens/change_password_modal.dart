import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

/// Full-screen, non-dismissible password change overlay shown when the
/// signed-in user has `force_password_change = true` in their metadata.
/// Mirrors `website/client/src/components/ChangePasswordModal.jsx`.
class ChangePasswordModal extends StatefulWidget {
  const ChangePasswordModal({super.key});

  @override
  State<ChangePasswordModal> createState() => _ChangePasswordModalState();
}

class _ChangePasswordModalState extends State<ChangePasswordModal> {
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _showNew = false;
  bool _showConfirm = false;
  bool _loading = false;
  bool _success = false;
  String? _error;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_newPasswordController.text.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    if (_newPasswordController.text != _confirmController.text) {
      return 'Passwords do not match.';
    }
    return null;
  }

  int _passwordStrength(String value) {
    if (value.isEmpty) return 0;
    var score = 0;
    if (value.length >= 8) score++;
    if (value.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(value)) score++;
    if (RegExp(r'[0-9]').hasMatch(value)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
    return score;
  }

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    final result = await auth.changePassword(_newPasswordController.text);

    if (!mounted) return;
    if (result.success) {
      setState(() {
        _loading = false;
        _success = true;
      });
      // Brief success view, then dismiss (parent listener stops showing it
      // because forcePasswordChange is now false).
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (mounted) Navigator.of(context).maybePop();
    } else {
      setState(() {
        _loading = false;
        _error = result.error ?? 'Failed to update password. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final auth = context.watch<AuthProvider>();
    final displayName =
        (auth.profile?['name'] ?? auth.user?.userMetadata?['name'] ?? 'User')
            .toString();

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.92),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: tokens.bgElevated,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: tokens.borderMedium),
                  ),
                  child: _success
                      ? _buildSuccess(tokens, displayName)
                      : _buildForm(tokens, displayName),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess(AppTokens tokens, String displayName) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tokens.jadeCore.withValues(alpha: 0.12),
            border:
                Border.all(color: tokens.jadeCore.withValues(alpha: 0.3), width: 2),
          ),
          child: Icon(Icons.verified_user, size: 36, color: tokens.jadeCore),
        ),
        const SizedBox(height: 18),
        Text(
          'Password Updated!',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your account is now secure. Welcome to SmartHome, $displayName.',
          textAlign: TextAlign.center,
          style: TextStyle(color: tokens.textMuted, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildForm(AppTokens tokens, String displayName) {
    final strength = _passwordStrength(_newPasswordController.text);
    final strengthLabel =
        ['', 'Weak', 'Fair', 'Good', 'Strong', 'Excellent'][strength];
    final strengthColors = <Color>[
      Colors.transparent,
      tokens.crimsonCore,
      tokens.amberCore,
      tokens.amberCore,
      tokens.jadeCore,
      tokens.jadeCore,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [tokens.emberCore, tokens.violetCore],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: tokens.emberCore.withValues(alpha: 0.35),
                  blurRadius: 32,
                ),
              ],
            ),
            child: const Icon(Icons.lock, color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Set Your Password',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Welcome, '),
              TextSpan(
                text: displayName,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const TextSpan(
                text:
                    '!\nThis is your first login. Please create a new secure password to continue.',
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: TextStyle(color: tokens.textMuted, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: tokens.amberCore.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tokens.amberCore.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, color: tokens.amberCore, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'You are setting up your account password. Choose a strong password to secure your profile.',
                  style: TextStyle(
                      color: tokens.amberCore, fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: tokens.crimsonCore.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: tokens.crimsonCore.withValues(alpha: 0.3)),
            ),
            child: Text(
              _error!,
              style: TextStyle(color: tokens.crimsonCore, fontSize: 13),
            ),
          ),
        ],
        const SizedBox(height: 18),
        _PasswordField(
          controller: _newPasswordController,
          label: 'New Password',
          hint: 'Minimum 8 characters',
          obscured: !_showNew,
          tokens: tokens,
          enabled: !_loading,
          autofocus: true,
          onToggle: () => setState(() => _showNew = !_showNew),
          onChanged: (_) => setState(() => _error = null),
        ),
        if (_newPasswordController.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              5,
              (i) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                  height: 3,
                  decoration: BoxDecoration(
                    color: i < strength
                        ? strengthColors[strength]
                        : tokens.borderSoft,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            strengthLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: strengthColors[strength],
            ),
          ),
        ],
        const SizedBox(height: 14),
        _PasswordField(
          controller: _confirmController,
          label: 'Confirm Password',
          hint: 'Repeat your new password',
          obscured: !_showConfirm,
          tokens: tokens,
          enabled: !_loading,
          borderColorOverride: _confirmController.text.isEmpty
              ? null
              : (_confirmController.text == _newPasswordController.text
                  ? tokens.jadeCore
                  : tokens.crimsonCore),
          onToggle: () => setState(() => _showConfirm = !_showConfirm),
          onChanged: (_) => setState(() => _error = null),
        ),
        if (_confirmController.text.isNotEmpty &&
            _confirmController.text != _newPasswordController.text) ...[
          const SizedBox(height: 4),
          Text(
            'Passwords do not match',
            style: TextStyle(color: tokens.crimsonCore, fontSize: 11),
          ),
        ],
        const SizedBox(height: 22),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _loading ||
                    _newPasswordController.text.isEmpty ||
                    _confirmController.text.isEmpty
                ? null
                : _submit,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.lock_outline, size: 18),
            label: const Text(
              'Set New Password',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.emberCore,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: TextButton(
            onPressed: _loading
                ? null
                : () async {
                    await context.read<AuthProvider>().logout();
                    if (mounted) Navigator.of(context).maybePop();
                  },
            child: Text(
              'Sign out instead',
              style: TextStyle(color: tokens.textMuted, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscured;
  final bool enabled;
  final bool autofocus;
  final AppTokens tokens;
  final Color? borderColorOverride;
  final VoidCallback onToggle;
  final ValueChanged<String> onChanged;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.obscured,
    required this.tokens,
    required this.onToggle,
    required this.onChanged,
    this.enabled = true,
    this.autofocus = false,
    this.borderColorOverride,
  });

  @override
  Widget build(BuildContext context) {
    final base =
        borderColorOverride ?? tokens.borderSoft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          autofocus: autofocus,
          obscureText: obscured,
          onChanged: onChanged,
          style: TextStyle(color: tokens.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: tokens.textWhisper, fontSize: 13),
            filled: true,
            fillColor: tokens.bgRaised,
            suffixIcon: IconButton(
              onPressed: onToggle,
              icon: Icon(
                obscured ? Icons.visibility : Icons.visibility_off,
                size: 18,
                color: tokens.textMuted,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: base),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: base),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: borderColorOverride ?? tokens.emberCore,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
