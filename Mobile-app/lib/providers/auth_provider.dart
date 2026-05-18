import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/fcm_registration_service.dart';
import '../services/supabase_auth_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;
  String? _successMessage;
  bool _isPasswordRecovery = false;
  StreamSubscription<AuthState>? _authSub;

  User? get user => _user;
  Map<String, dynamic>? get profile => _profile;
  bool get loading => _loading;
  String? get error => _error;
  String? get successMessage => _successMessage;
  bool get isAuthenticated => _user != null;

  /// Web parity: `profile?.role === 'admin'`.
  bool get isAdmin => (_profile?['role']?.toString() ?? '') == 'admin';

  /// Web parity: `user.user_metadata.force_password_change === true`.
  /// True when the resident has not yet rotated their invite password.
  bool get forcePasswordChange {
    if (_user == null) return false;
    final meta = _user!.userMetadata;
    return meta != null && meta['force_password_change'] == true;
  }

  /// Web parity: `AuthContext.isPasswordRecovery`.
  /// True while the user is inside a Supabase `passwordRecovery` session
  /// (deep link from a forgot-password / invite email).
  bool get isPasswordRecovery => _isPasswordRecovery;

  AuthProvider() {
    _authSub =
        SupabaseAuthService.onAuthStateChange.listen((authState) async {
      final session = authState.session;
      final event = authState.event;

      // Password-recovery deep link: enter recovery mode, suppress the
      // force-password modal so the dedicated UpdatePasswordScreen renders.
      if (event == AuthChangeEvent.passwordRecovery) {
        _user = session?.user;
        _isPasswordRecovery = true;
        _loading = false;
        if (_user != null) {
          await _loadProfile(_user!.id);
        }
        notifyListeners();
        return;
      }

      if (session != null) {
        _user = session.user;
        await _loadProfile(session.user.id);
      } else {
        _user = null;
        _profile = null;
        _isPasswordRecovery = false;
      }
      _loading = false;
      notifyListeners();
    });

    _initAuth();
  }

  Future<void> _initAuth() async {
    final session = SupabaseAuthService.currentSession;
    if (session != null) {
      _user = session.user;
      await _loadProfile(session.user.id);
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> _loadProfile(String userId) async {
    _profile = await SupabaseAuthService.fetchProfile(userId);
    await FcmRegistrationService.syncForCurrentUser();
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    try {
      _error = null;
      _successMessage = null;
      _loading = true;
      notifyListeners();

      final response = await SupabaseAuthService.signIn(
        email: email,
        password: password,
      );
      _user = response.user;
      if (_user != null) {
        await _loadProfile(_user!.id);
      }
      return _user != null;
    } on AuthException catch (e) {
      _error = _friendlyAuthError(e.message);
      return false;
    } catch (_) {
      _error = 'Connection error. Please check your network.';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Returns true if the sign-up request succeeded (email sent).
  /// Does NOT auto-login -- user must confirm email first.
  Future<bool> register(String name, String email, String password) async {
    try {
      _error = null;
      _successMessage = null;
      _loading = true;
      notifyListeners();

      await SupabaseAuthService.signUp(
        email: email,
        password: password,
        name: name,
      );

      // Sign-up succeeded. Supabase sends a confirmation email.
      // Do NOT set _user here -- there is no active session until
      // the user clicks the confirmation link.
      _successMessage =
          'A confirmation email has been sent to $email. '
          'Please check your inbox and confirm your account, then sign in.';
      return true;
    } on AuthException catch (e) {
      _error = _friendlyAuthError(e.message);
      return false;
    } catch (_) {
      _error = 'Connection error. Please check your network.';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await FcmRegistrationService.unregisterCurrentDevice();
    await SupabaseAuthService.signOut();
    _user = null;
    _profile = null;
    _isPasswordRecovery = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Admin / invitation flow (web parity)
  // ---------------------------------------------------------------------------

  /// Admin creates a resident auth account and triggers the password-setup
  /// email. Returns the new user's id on success.
  Future<({bool success, String? userId, String? error})>
      createResidentAccount({
    required String name,
    required String email,
  }) async {
    try {
      final userId = await SupabaseAuthService.createResidentAccount(
        name: name,
        email: email,
      );
      return (success: true, userId: userId, error: null);
    } on AuthException catch (e) {
      return (
        success: false,
        userId: null,
        error: _friendlyAuthError(e.message),
      );
    } catch (e) {
      return (success: false, userId: null, error: e.toString());
    }
  }

  /// Resident first-login password change. Updates Supabase auth password
  /// and clears the `force_password_change` flag in user metadata.
  Future<({bool success, String? error})> changePassword(
      String newPassword) async {
    try {
      final response = await SupabaseAuthService.changePassword(newPassword);
      _user = response.user ?? _user;
      notifyListeners();
      return (success: true, error: null);
    } on AuthException catch (e) {
      return (success: false, error: _friendlyAuthError(e.message));
    } catch (e) {
      return (success: false, error: e.toString());
    }
  }

  /// Admin-only: delete an auth user via `delete_auth_user` RPC.
  Future<({bool success, String? error})> deleteAuthUser(
      String targetUserId) async {
    try {
      await SupabaseAuthService.deleteAuthUser(targetUserId);
      return (success: true, error: null);
    } catch (e) {
      return (success: false, error: e.toString());
    }
  }

  /// Admin-only: list every profile (relies on the admin RLS policy).
  Future<List<Map<String, dynamic>>> fetchAllProfiles() {
    return SupabaseAuthService.fetchAllProfiles();
  }

  // ---------------------------------------------------------------------------
  // Password recovery (web parity)
  // ---------------------------------------------------------------------------

  /// Web parity: `AuthContext.requestPasswordReset`.
  /// Sends the recovery email; UI shows a generic success state regardless of
  /// whether the address is registered (no account enumeration).
  Future<({bool success, String? error})> requestPasswordReset(
      String email) async {
    try {
      await SupabaseAuthService.requestPasswordReset(email);
      return (success: true, error: null);
    } on AuthException catch (e) {
      return (success: false, error: _friendlyAuthError(e.message));
    } catch (e) {
      return (success: false, error: e.toString());
    }
  }

  /// Web parity: `AuthContext.completePasswordRecovery`.
  /// Persists the new password, clears `force_password_change`, signs the user
  /// out so they re-authenticate. Resets local recovery state on success.
  Future<({bool success, String? error})> completePasswordRecovery(
      String newPassword) async {
    try {
      await SupabaseAuthService.completePasswordRecovery(newPassword);
      _isPasswordRecovery = false;
      _user = null;
      _profile = null;
      notifyListeners();
      return (success: true, error: null);
    } on AuthException catch (e) {
      return (success: false, error: _friendlyAuthError(e.message));
    } catch (e) {
      return (success: false, error: e.toString());
    }
  }

  /// Web parity: `AuthContext.changePasswordWithVerification`.
  /// Used by Settings → Change Password (NOT the invite/recovery modal).
  Future<({bool success, String? error})> changePasswordWithVerification({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await SupabaseAuthService.changePasswordWithVerification(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _user = response.user ?? _user;
      notifyListeners();
      return (success: true, error: null);
    } on AuthException catch (e) {
      return (success: false, error: _friendlyAuthError(e.message));
    } catch (e) {
      return (success: false, error: e.toString());
    }
  }

  void clearError() {
    _error = null;
    _successMessage = null;
    notifyListeners();
  }

  /// Maps raw Supabase/network error messages to user-friendly strings.
  String _friendlyAuthError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials')) {
      return 'Invalid email or password.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please confirm your email before signing in.';
    }
    if (lower.contains('user already registered') ||
        lower.contains('already been registered')) {
      return 'An account with this email already exists.';
    }
    if (lower.contains('password') && lower.contains('short')) {
      return 'Password must be at least 6 characters.';
    }
    if (lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('connection') ||
        lower.contains('network')) {
      return 'Connection error. Please check your network and try again.';
    }
    return raw;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
