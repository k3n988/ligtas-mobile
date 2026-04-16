import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Role ──────────────────────────────────────────────────────────────────────

enum UserRole { admin, rescuer, citizen, unknown }

// ── Auth state ────────────────────────────────────────────────────────────────

class AuthState {
  // Helper to easily check admin status in your UI (like the Hazard Panel)
  bool get isAdmin => role == UserRole.admin;
  
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
  'admin@gmail.com':   (password: 'admin123', role: UserRole.admin),   // Added for testing the Hazard Panel
  'asset@gmail.com':   (password: '123', role: UserRole.rescuer),
  'citizen@gmail.com': (password: '123', role: UserRole.citizen),
};

// ── Auth notifier ─────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(isLoading: true)) {
    _init();
  }

  final _client = Supabase.instance.client;
  final _storage = const FlutterSecureStorage();
  StreamSubscription<dynamic>? _authSub;
  static const _authKey = 'ligtas_auth_state';

  Future<void> _init() async {
    await _restorePersistedAuth();

    final session = _client.auth.currentSession;
    if (session != null) {
      state = AuthState(
        isLoggedIn: true,
        isLoading:  false,
        username:   session.user.email ?? 'User',
        role:       _roleFromUser(session.user),
      );
    } else if (!state.isLoggedIn) {
      state = state.copyWith(isLoading: false);
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
              isLoading:  false,
              username:   user.email ?? 'User',
              role:       _roleFromUser(user),
            );
            unawaited(_persistAuthState());
          }
        case AuthChangeEvent.signedOut:
          state = const AuthState();
          unawaited(_clearPersistedAuth());
        default:
          break;
      }
    });
  }

  Future<void> _restorePersistedAuth() async {
    try {
      final raw = await _storage.read(key: _authKey);
      if (raw == null || raw.isEmpty) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final username = data['username'] as String?;
      final roleName = data['role'] as String?;
      if (username == null || roleName == null) return;
      final role = UserRole.values.firstWhere(
        (value) => value.name == roleName,
        orElse: () => UserRole.unknown,
      );
      if (role == UserRole.unknown) return;
      state = AuthState(
        isLoggedIn: true,
        isLoading: false,
        username: username,
        role: role,
      );
    } catch (_) {
      await _clearPersistedAuth();
    }
  }

  Future<void> _persistAuthState() async {
    if (!state.isLoggedIn || state.username == null) return;
    await _storage.write(
      key: _authKey,
      value: jsonEncode({
        'username': state.username,
        'role': state.role.name,
      }),
    );
  }

  Future<void> _clearPersistedAuth() async {
    await _storage.delete(key: _authKey);
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  Future<String?> login(String contact, String password, {bool isStaff = false}) async {
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
      await _persistAuthState();
      return null;
    }

    // ── Contact number: try asset (rescuer) first, then citizen ──────────
    if (_looksLikeContactNumber(contact)) {
      final normalised = _normaliseContact(contact);
      // Try rescuer/asset login first
      final assetResult = await _tryAssetLogin(normalised, password);
      if (assetResult == null) return null; // success
      // Fall back to citizen login
      return _citizenLogin(normalised, password);
    }

    // ── Real Supabase auth (email-based) ──────────────────────────────────
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

  // ── Password hashing — mirrors web: SHA-256(plain + 'LIGTAS_SALT_2025') ──

  String _hashPassword(String plain) {
    final bytes = utf8.encode('${plain}LIGTAS_SALT_2025');
    return sha256.convert(bytes).toString();
  }

  bool _looksLikeContactNumber(String input) {
    // Strip spaces, dashes, and + so +639... and 09... both match
    final cleaned = input.replaceAll(RegExp(r'[\s\-\+]'), '');
    return RegExp(r'^\d{10,13}$').hasMatch(cleaned) && !input.contains('@');
  }

  /// Normalise any PH mobile format to 09XXXXXXXXX (11 digits)
  String _normaliseContact(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[\s\-\+]'), '');
    // +639171234567 → 639171234567 (12 digits) → 09171234567
    if (cleaned.startsWith('63') && cleaned.length == 12) {
      return '0${cleaned.substring(2)}';
    }
    return cleaned;
  }

  Future<String?> _citizenLogin(String contact, String password) async {
    try {
      final rows = await _client
          .from('households')
          .select('citizen_password_hash')
          .eq('contact', contact)
          .limit(1);

      if (rows.isEmpty) {
        state = state.copyWith(isLoading: false);
        return 'Incorrect contact number or password.';
      }

      final computed = _hashPassword(password);
      final matched  = rows.any((r) => r['citizen_password_hash'] == computed);
      if (!matched) {
        state = state.copyWith(isLoading: false);
        return 'Incorrect contact number or password.';
      }

      state = AuthState(
        isLoggedIn: true,
        isLoading:  false,
        username:   contact,
        role:       UserRole.citizen,
      );
      await _persistAuthState();
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('[AUTH] _citizenLogin error: $e');
      state = state.copyWith(isLoading: false);
      return 'Login failed. Check your connection.';
    }
  }

  // ── Asset (rescuer / staff) login via assets table ───────────────────────

  /// Returns null on success, error string on failure.
  /// Does NOT set loading=false on failure so caller can fall through to citizen login.
  Future<String?> _tryAssetLogin(String contact, String password) async {
    try {
      final rows = await _client
          .from('assets')
          .select('asset_password_hash')
          .eq('contact', contact);

      if (rows.isEmpty) return 'no_match';

      final computed = _hashPassword(password);
      final matched  = rows.any((r) => r['asset_password_hash'] == computed);
      if (!matched) return 'no_match';

      state = AuthState(
        isLoggedIn: true,
        isLoading:  false,
        username:   contact,
        role:       UserRole.rescuer,
      );
      await _persistAuthState();
      return null; // success
    } catch (_) {
      return 'error'; // fall through to citizen login
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
    // Dev accounts, citizen, or rescuer logins have no Supabase session
    if (_testAccounts.containsKey(state.username?.toLowerCase()) ||
        state.role == UserRole.citizen ||
        state.role == UserRole.rescuer && _client.auth.currentSession == null) {
      state = const AuthState();
      await _clearPersistedAuth();
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
