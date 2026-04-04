import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Role ──────────────────────────────────────────────────────────────────────

enum UserRole { admin, rescuer, citizen, unknown }

// ── Auth state ────────────────────────────────────────────────────────────────

class AuthState {
  final bool isLoggedIn;
  final bool isLoading;
  final String? username;
  final UserRole role;

  const AuthState({
    this.isLoggedIn = false,
    this.isLoading  = false,
    this.username,
    this.role = UserRole.unknown,
  });

  AuthState copyWith({
    bool?     isLoggedIn,
    bool?     isLoading,
    String?   username,
    UserRole? role,
    bool      clearUsername = false,
  }) => AuthState(
    isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    isLoading:  isLoading  ?? this.isLoading,
    username:   clearUsername ? null : (username ?? this.username),
    role:       role ?? this.role,
  );
}

// ── Test / dev accounts (bypass Supabase for short passwords) ─────────────────

const _testAccounts = {
  'asset@gmail.com':   (password: '123', role: UserRole.rescuer),
  'citizen@gmail.com': (password: '123', role: UserRole.citizen),
};

// ── Auth notifier ─────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  final _client = Supabase.instance.client;
  StreamSubscription<dynamic>? _authSub;

  void _init() {
    final session = _client.auth.currentSession;
    if (session != null) {
      state = AuthState(
        isLoggedIn: true,
        username:   session.user.email ?? 'User',
        role:       _roleFromUser(session.user),
      );
    }

    _authSub = _client.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user;
      switch (data.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
        case AuthChangeEvent.userUpdated:
          if (user != null) {
            state = AuthState(
              isLoggedIn: true,
              username:   user.email ?? 'User',
              role:       _roleFromUser(user),
            );
          }
        case AuthChangeEvent.signedOut:
          state = const AuthState();
        default:
          break;
      }
    });
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  Future<String?> login(String contact, String password) async {
    if (contact.isEmpty || password.isEmpty) return 'Please fill in all fields.';

    state = state.copyWith(isLoading: true);

    // ── Dev bypass for test accounts ─────────────────────────────────────
    final test = _testAccounts[contact.toLowerCase().trim()];
    if (test != null) {
      if (password != test.password) {
        state = state.copyWith(isLoading: false);
        return 'Incorrect password.';
      }
      state = AuthState(
        isLoggedIn: true,
        isLoading:  false,
        username:   contact,
        role:       test.role,
      );
      return null;
    }

    // ── Real Supabase auth ────────────────────────────────────────────────
    if (password.length < 6) {
      state = state.copyWith(isLoading: false);
      return 'Password must be at least 6 characters.';
    }

    try {
      await _client.auth.signInWithPassword(email: contact, password: password);
      return null;
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
        data:     {'role': 'citizen'},
      );
      if (res.session == null) {
        state = state.copyWith(isLoading: false);
        return 'Account created! Check your email to confirm, then log in.';
      }
      return null;
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
    // Dev accounts — just clear state
    if (_testAccounts.containsKey(state.username?.toLowerCase())) {
      state = const AuthState();
      return;
    }
    await _client.auth.signOut();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  UserRole _roleFromUser(User user) {
    final meta = user.userMetadata;
    final r    = meta?['role'] as String? ?? '';
    switch (r) {
      case 'rescuer': return UserRole.rescuer;
      case 'citizen': return UserRole.citizen;
      case 'admin':   return UserRole.admin;
      default:        return UserRole.admin;
    }
  }

  String _friendlyError(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('invalid login'))      return 'Incorrect email or password.';
    if (m.contains('already registered')) return 'An account with this email already exists.';
    if (m.contains('not confirmed'))      return 'Please confirm your email before logging in.';
    if (m.contains('rate limit'))         return 'Too many attempts. Please wait a moment.';
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
