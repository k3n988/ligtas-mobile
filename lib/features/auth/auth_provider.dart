import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Auth state ────────────────────────────────────────────────────────────────

class AuthState {
  final bool isLoggedIn;
  final bool isLoading;
  final String? username;

  const AuthState({
    this.isLoggedIn = false,
    this.isLoading  = false,
    this.username,
  });

  AuthState copyWith({
    bool?   isLoggedIn,
    bool?   isLoading,
    String? username,
    bool    clearUsername = false,
  }) => AuthState(
    isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    isLoading:  isLoading  ?? this.isLoading,
    username:   clearUsername ? null : (username ?? this.username),
  );
}

// ── Auth notifier — backed by Supabase Auth ───────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  final _client = Supabase.instance.client;
  StreamSubscription<dynamic>? _authSub;

  void _init() {
    // Restore session that supabase_flutter persisted on device
    final session = _client.auth.currentSession;
    if (session != null) {
      state = AuthState(
        isLoggedIn: true,
        username:   session.user.email ?? session.user.phone ?? 'User',
      );
    }

    // Keep in sync with any auth-state changes (token refresh, sign-out, etc.)
    _authSub = _client.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user;
      switch (data.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
        case AuthChangeEvent.userUpdated:
          if (user != null) {
            state = AuthState(
              isLoggedIn: true,
              username:   user.email ?? user.phone ?? 'User',
            );
          }
        case AuthChangeEvent.signedOut:
          state = const AuthState();
        default:
          break;
      }
    });
  }

  // ── Login ────────────────────────────────────────────────────────────────

  Future<String?> login(String contact, String password) async {
    if (contact.isEmpty || password.isEmpty) return 'Please fill in all fields.';
    if (password.length < 6) return 'Password must be at least 6 characters.';

    state = state.copyWith(isLoading: true);
    try {
      await _client.auth.signInWithPassword(
        email:    contact,
        password: password,
      );
      return null; // success — onAuthStateChange updates the state
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false);
      return _friendlyError(e.message);
    } catch (_) {
      state = state.copyWith(isLoading: false);
      return 'Login failed. Check your connection.';
    }
  }

  // ── Sign-up ───────────────────────────────────────────────────────────────

  Future<String?> signUp(String contact, String password) async {
    if (contact.isEmpty || password.isEmpty) return 'Please fill in all fields.';
    if (password.length < 6) return 'Password must be at least 6 characters.';

    state = state.copyWith(isLoading: true);
    try {
      final res = await _client.auth.signUp(
        email:    contact,
        password: password,
      );
      // If email confirmation is required, Supabase returns a user but no session
      if (res.session == null) {
        state = state.copyWith(isLoading: false);
        return 'Account created! Please check your email to confirm, then log in.';
      }
      return null; // confirmed immediately (email confirm disabled in dashboard)
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false);
      return _friendlyError(e.message);
    } catch (_) {
      state = state.copyWith(isLoading: false);
      return 'Sign up failed. Check your connection.';
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await _client.auth.signOut();
    // onAuthStateChange fires signedOut → state reset automatically
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _friendlyError(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('invalid login'))    return 'Incorrect email or password.';
    if (m.contains('already registered')) return 'An account with this email already exists.';
    if (m.contains('email not confirmed')) return 'Please confirm your email before logging in.';
    if (m.contains('rate limit'))       return 'Too many attempts. Please wait a moment.';
    return msg;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
