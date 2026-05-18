import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthService {
  static final _client = Supabase.instance.client;

  /// Web parity: `resetPasswordForEmail` redirect target.
  ///
  /// Default uses the mobile custom URL scheme so password-recovery / invite
  /// mails open the Flutter app via `DeepLinkService`. Override with
  /// `--dart-define=PASSWORD_RESET_REDIRECT_URL=https://your.site/update-password`
  /// when you want the link to land on the web `/update-password` page.
  ///
  /// Must stay aligned with AndroidManifest intent-filter (scheme +host).
  static const String passwordResetRedirectUrl = String.fromEnvironment(
    'PASSWORD_RESET_REDIRECT_URL',
    defaultValue: 'io.cankaya.smarthome://login-callback/',
  );

  static Stream<AuthState> get onAuthStateChange =>
      _client.auth.onAuthStateChange;

  static Session? get currentSession => _client.auth.currentSession;

  static User? get currentUser => _client.auth.currentUser;

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
    );
  }

  static Future<void> signOut() => _client.auth.signOut();

  /// Fetches the user profile from the `profiles` table.
  /// The row is created automatically by a DB trigger on sign-up.
  static Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return data;
    } catch (_) {
      return null;
    }
  }

  /// Updates profile fields (e.g. name).
  static Future<void> updateProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    await _client.from('profiles').update(updates).eq('id', userId);
  }

  // ---------------------------------------------------------------------------
  // Admin / invitation flow (web parity with `AuthContext.createResidentAccount`)
  // ---------------------------------------------------------------------------

  /// Admin creates a resident auth account with a random throwaway password and
  /// triggers Supabase to email the resident a password-setup link.
  ///
  /// Returns the new user's id on success, or throws on failure (caller wraps
  /// the call to surface a friendly error).
  ///
  /// Mirrors `website/client/src/context/AuthContext.jsx::createResidentAccount`.
  static Future<String> createResidentAccount({
    required String name,
    required String email,
  }) async {
    final dummyPassword = _generateThrowawayPassword();

    final response = await _client.auth.signUp(
      email: email,
      password: dummyPassword,
      data: {
        'name': name,
        'role': 'resident',
        'force_password_change': true,
      },
    );

    final newUser = response.user;
    if (newUser == null) {
      throw const AuthException(
        'Account creation returned no user. The email may already be registered.',
      );
    }

    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: passwordResetRedirectUrl,
      );
    } catch (_) {
      // Non-fatal: account exists; admin can retry the email later.
    }

    return newUser.id;
  }

  /// Resident sets a new password on first login and clears the
  /// `force_password_change` flag in user metadata.
  static Future<UserResponse> changePassword(String newPassword) {
    return _client.auth.updateUser(
      UserAttributes(
        password: newPassword,
        data: {'force_password_change': false},
      ),
    );
  }

  /// Web parity: `AuthContext.requestPasswordReset`.
  /// Sends the standard Supabase password-reset email pointing at
  /// [passwordResetRedirectUrl]. Throws on failure.
  static Future<void> requestPasswordReset(String email) {
    return _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: passwordResetRedirectUrl,
    );
  }

  /// Web parity: `AuthContext.completePasswordRecovery`.
  /// Sets a new password (clearing `force_password_change`) and immediately
  /// signs the user out so they re-authenticate with the new credentials.
  static Future<void> completePasswordRecovery(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(
        password: newPassword,
        data: {'force_password_change': false},
      ),
    );
    await _client.auth.signOut();
  }

  /// Web parity: `AuthContext.changePasswordWithVerification`.
  /// Re-authenticates with the current password, then rotates to [newPassword].
  /// Used by Settings → Change Password where we do NOT want to consume the
  /// invite/recovery-only `changePassword` path.
  static Future<UserResponse> changePasswordWithVerification({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = currentUser?.email;
    if (email == null || email.isEmpty) {
      throw const AuthException('No active session to re-authenticate.');
    }
    // Throws on bad credentials; caller catches AuthException and surfaces it.
    await _client.auth.signInWithPassword(
      email: email,
      password: currentPassword,
    );
    return _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  /// Admin-only: deletes an auth user via the `delete_auth_user` RPC
  /// (SECURITY DEFINER). Server-side enforces `profiles.role = 'admin'`.
  static Future<void> deleteAuthUser(String targetUserId) async {
    final data = await _client.rpc(
      'delete_auth_user',
      params: {'target_user_id': targetUserId},
    );
    if (data is Map && data['success'] == false) {
      throw Exception(data['error']?.toString() ?? 'Delete failed');
    }
  }

  /// Admin-only: fetches all profiles for the user-management screen.
  /// Relies on the RLS policy (`profiles_select_own_or_admin`) added in
  /// `supabase_setup_v2.sql` to let admins see every row.
  static Future<List<Map<String, dynamic>>> fetchAllProfiles() async {
    final data = await _client
        .from('profiles')
        .select('*')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static String _generateThrowawayPassword() {
    final rand = Random.secure();
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%^&*';
    return List.generate(48, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
