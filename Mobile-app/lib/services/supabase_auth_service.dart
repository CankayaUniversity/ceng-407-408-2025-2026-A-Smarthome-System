import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthService {
  static final _client = Supabase.instance.client;

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
}
