import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

/// Mobile equivalent of `website/client/src/pages/ForgotPasswordPage.jsx`.
///
/// Collects an email address and calls
/// `AuthProvider.requestPasswordReset(email)` which in turn invokes
/// `supabase.auth.resetPasswordForEmail(redirectTo: io.cankaya.smarthome://login-callback/)`.
/// The deep-link handler installed by `DeepLinkService` will resume the flow
/// when the user taps the link in their inbox.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final res = await context.read<AuthProvider>().requestPasswordReset(email);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success) {
        _sent = true;
      } else {
        _error = res.error ?? 'Could not send reset email. Please try again.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gradientColors = isDark
        ? const [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)]
        : [tokens.bgVoid, tokens.bgRaised, tokens.bgElevated];

    final textOnGradient = isDark ? Colors.white : tokens.textPrimary;
    final mutedOnGradient = textOnGradient.withValues(alpha: 0.6);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: textOnGradient),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: _sent
                        ? _buildSent(tokens, textOnGradient, mutedOnGradient)
                        : _buildForm(
                            tokens, isDark, textOnGradient, mutedOnGradient),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(AppTokens tokens, bool isDark, Color textColor,
      Color mutedColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [
                tokens.emberCore,
                tokens.emberBright,
              ]),
              boxShadow: [
                BoxShadow(
                  color: tokens.emberCore.withValues(alpha: 0.35),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const Icon(Icons.lock_reset,
                color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Forgot your password?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: textColor,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the email you use to sign in and we will send you a secure link to set a new password.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: mutedColor, height: 1.45),
        ),
        const SizedBox(height: 24),
        if (_error != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: tokens.crimsonCore.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: tokens.crimsonCore.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline,
                    color: tokens.crimsonCore, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(
                        color: tokens.crimsonCore, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ],
        _EmailField(
          controller: _emailController,
          isDark: isDark,
          tokens: tokens,
          enabled: !_loading,
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.emberCore,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text(
                    'Send reset link',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(
              'Back to sign in',
              style: TextStyle(color: mutedColor, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSent(AppTokens tokens, Color textColor, Color mutedColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tokens.jadeCore.withValues(alpha: 0.15),
            border: Border.all(
                color: tokens.jadeCore.withValues(alpha: 0.4), width: 2),
          ),
          child: Icon(Icons.mark_email_read,
              color: tokens.jadeCore, size: 38),
        ),
        const SizedBox(height: 18),
        Text(
          'Check your inbox',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 8),
        Text(
          'If an account exists for that email, we have sent a secure link to set a new password. Open it on this device and the app will continue automatically.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: mutedColor, height: 1.45),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back, color: tokens.emberCore, size: 18),
            label: Text(
              'Back to sign in',
              style: TextStyle(
                color: tokens.emberCore,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: tokens.emberCore.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmailField extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final bool enabled;
  final AppTokens tokens;

  const _EmailField({
    required this.controller,
    required this.isDark,
    required this.enabled,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final fieldText = isDark ? Colors.white : tokens.textPrimary;
    final fillColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : tokens.bgSurface.withValues(alpha: 0.85);
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.1) : tokens.borderMedium;
    final hintColor = fieldText.withValues(alpha: 0.4);

    return Container(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.emailAddress,
        style: TextStyle(color: fieldText, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Email',
          hintStyle: TextStyle(color: hintColor),
          prefixIcon:
              Icon(Icons.email_outlined, color: hintColor, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
