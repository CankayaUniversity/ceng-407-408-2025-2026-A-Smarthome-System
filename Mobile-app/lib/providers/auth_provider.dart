import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_auth_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;
  String? _successMessage;
  StreamSubscription<AuthState>? _authSub;

  User? get user => _user;
  Map<String, dynamic>? get profile => _profile;
  bool get loading => _loading;
  String? get error => _error;
  String? get successMessage => _successMessage;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _authSub = SupabaseAuthService.onAuthStateChange.listen((authState) {
      final session = authState.session;
      if (session != null) {
        _user = session.user;
        _loadProfile(session.user.id);
      } else {
        _user = null;
        _profile = null;
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
    await SupabaseAuthService.signOut();
    _user = null;
    _profile = null;
    notifyListeners();
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
