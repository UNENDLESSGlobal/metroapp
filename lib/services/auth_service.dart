import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

/// Service for handling Supabase authentication
class AuthService {
  final SupabaseClient _supabase;

  AuthService(this._supabase);

  /// Get current user
  User? get currentUser => _supabase.auth.currentUser;

  /// Check if user is logged in
  bool get isLoggedIn => currentUser != null;

  /// Get auth state stream
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: name != null ? {'name': name} : null,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  /// Get current user profile
  UserProfile? getCurrentUserProfile() {
    final user = currentUser;
    if (user == null) return null;

    return UserProfile(
      id: user.id,
      email: user.email ?? '',
      name: user.userMetadata?['name'] ?? user.userMetadata?['full_name'],
      phone: user.phone,
      profileImageUrl: user.userMetadata?['avatar_url'],
      createdAt: DateTime.tryParse(user.createdAt),
    );
  }

  /// Update user profile
  Future<void> updateProfile({
    String? name,
    String? phone,
  }) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            if (name != null) 'name': name,
            if (phone != null) 'phone': phone,
          },
        ),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    }
  }
}
