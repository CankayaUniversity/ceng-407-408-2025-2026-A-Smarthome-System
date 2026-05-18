import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

/// Mobile equivalent of `website/client/src/pages/SettingsPage.jsx` →
/// "Change Password" form. Re-authenticates with the current password
/// (via [AuthProvider.changePasswordWithVerification]) before rotating.
class ChangeSelfPasswordScreen extends StatefulWidget {
  const ChangeSelfPasswordScreen({super.key});

  @override
  State<ChangeSelfPasswordScreen> createState() =>
      _ChangeSelfPasswordScreenState();
}

class _ChangeSelfPasswordScreenState extends State<ChangeSelfPasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_currentController.text.isEmpty) {
      return 'Please enter your current password.';
    }
    if (_newController.text.length < 8) {
      return 'New password must be at least 8 characters.';
    }
    if (_newController.text == _currentController.text) {
      return 'New password must differ from your current one.';
    }
    if (_newController.text != _confirmController.text) {
      return 'New passwords do not match.';
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
      setState(() {
        _error = err;
        _success = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    final res = await context.read<AuthProvider>().changePasswordWithVerification(
          currentPassword: _currentController.text,
          newPassword: _newController.text,
        );

    if (!mounted) return;
    if (res.success) {
      _currentController.clear();
      _newController.clear();
      _confirmController.clear();
      setState(() {
        _loading = false;
        _success = 'Password updated successfully.';
      });
    } else {
      setState(() {
        _loading = false;
        _error = res.error ?? 'Could not update password. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final strength = _passwordStrength(_newController.text);
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

    return Scaffold(
      backgroundColor: tokens.bgVoid,
      appBar: AppBar(
        title: const Text('Change Password'),
        backgroundColor: tokens.bgRaised,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: tokens.bgElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tokens.borderMedium),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: tokens.emberCore.withValues(alpha: 0.15),
                        ),
                        child: Icon(Icons.lock_outline,
                            color: tokens.emberCore, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Update your password',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: tokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Verify your current password to set a new one.',
                              style: TextStyle(
                                color: tokens.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_success != null) ...[
                    _BannerBox(
                      color: tokens.jadeCore,
                      icon: Icons.check_circle_outline,
                      text: _success!,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_error != null) ...[
                    _BannerBox(
                      color: tokens.crimsonCore,
                      icon: Icons.error_outline,
                      text: _error!,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _PwField(
                    controller: _currentController,
                    label: 'Current Password',
                    hint: 'Enter your current password',
                    obscured: !_showCurrent,
                    tokens: tokens,
                    enabled: !_loading,
                    onToggle: () =>
                        setState(() => _showCurrent = !_showCurrent),
                    onChanged: (_) => setState(() {
                      _error = null;
                      _success = null;
                    }),
                  ),
                  const SizedBox(height: 14),
                  _PwField(
                    controller: _newController,
                    label: 'New Password',
                    hint: 'Minimum 8 characters',
                    obscured: !_showNew,
                    tokens: tokens,
                    enabled: !_loading,
                    onToggle: () => setState(() => _showNew = !_showNew),
                    onChanged: (_) => setState(() {
                      _error = null;
                      _success = null;
                    }),
                  ),
                  if (_newController.text.isNotEmpty) ...[
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
                          color: strengthColors[strength]),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _PwField(
                    controller: _confirmController,
                    label: 'Confirm New Password',
                    hint: 'Re-enter the new password',
                    obscured: !_showConfirm,
                    tokens: tokens,
                    enabled: !_loading,
                    borderColorOverride: _confirmController.text.isEmpty
                        ? null
                        : (_confirmController.text == _newController.text
                            ? tokens.jadeCore
                            : tokens.crimsonCore),
                    onToggle: () =>
                        setState(() => _showConfirm = !_showConfirm),
                    onChanged: (_) => setState(() {
                      _error = null;
                      _success = null;
                    }),
                  ),
                  if (_confirmController.text.isNotEmpty &&
                      _confirmController.text != _newController.text) ...[
                    const SizedBox(height: 4),
                    Text('Passwords do not match',
                        style: TextStyle(
                            color: tokens.crimsonCore, fontSize: 11)),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _loading ||
                              _currentController.text.isEmpty ||
                              _newController.text.isEmpty ||
                              _confirmController.text.isEmpty
                          ? null
                          : _submit,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save, size: 18),
                      label: const Text(
                        'Update password',
                        style: TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.emberCore,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerBox extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  const _BannerBox(
      {required this.color, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: TextStyle(color: color, fontSize: 12.5))),
        ],
      ),
    );
  }
}

class _PwField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscured;
  final bool enabled;
  final AppTokens tokens;
  final Color? borderColorOverride;
  final VoidCallback onToggle;
  final ValueChanged<String> onChanged;

  const _PwField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.obscured,
    required this.tokens,
    required this.onToggle,
    required this.onChanged,
    this.enabled = true,
    this.borderColorOverride,
  });

  @override
  Widget build(BuildContext context) {
    final base = borderColorOverride ?? tokens.borderSoft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
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
