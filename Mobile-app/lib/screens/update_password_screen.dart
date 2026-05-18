import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

/// Mobile equivalent of `website/client/src/pages/UpdatePasswordPage.jsx`.
///
/// Rendered while [AuthProvider.isPasswordRecovery] is `true` (i.e. a
/// recovery session has been installed by the deep-link handler). The user
/// sets a new password; on success the session is closed and they return to
/// the login screen.
class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _showNew = false;
  bool _showConfirm = false;
  bool _loading = false;
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
    final res =
        await auth.completePasswordRecovery(_newPasswordController.text);

    if (!mounted) return;
    if (res.success) {
      // Provider clears state -> main.dart Consumer rebuilds into LoginScreen.
      // Surface a snackbar once we are back on the login surface.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Password updated. Sign in with your new password.'),
        ),
      );
    } else {
      setState(() {
        _loading = false;
        _error = res.error ?? 'Failed to update password. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

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
                  child: _buildForm(tokens),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(AppTokens tokens) {
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
            child: const Icon(Icons.lock_reset, color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Set a new password',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your password reset link is verified. Choose a strong new password to finish.',
          textAlign: TextAlign.center,
          style: TextStyle(color: tokens.textMuted, fontSize: 13, height: 1.5),
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
                : const Icon(Icons.check, size: 18),
            label: const Text(
              'Update password',
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
                    // Abandons the recovery session.
                    await context.read<AuthProvider>().logout();
                  },
            child: Text(
              'Cancel and sign out',
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
    final base = borderColorOverride ?? tokens.borderSoft;
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
