import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import 'auth_provider.dart';

enum AuthTab { login, signUp }

enum _LoginMode { citizen, staff }

class LoginModal extends ConsumerStatefulWidget {
  final AuthTab initialTab;
  const LoginModal({super.key, this.initialTab = AuthTab.login});

  @override
  ConsumerState<LoginModal> createState() => _LoginModalState();
}

class _LoginModalState extends ConsumerState<LoginModal> {
  late bool _isSignUp;
  _LoginMode _loginMode = _LoginMode.citizen;

  final _contactCtrl  = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialTab == AuthTab.signUp;
  }

  @override
  void dispose() {
    _contactCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final contact  = _contactCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (_isSignUp && password != _confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    final notifier = ref.read(authProvider.notifier);
    final err = _isSignUp
        ? await notifier.signUp(contact, password)
        : await notifier.login(contact, password, isStaff: _loginMode == _LoginMode.staff);

    if (err != null) {
      setState(() => _error = err);
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _switchTopTab(bool signUp) {
    setState(() {
      _isSignUp = signUp;
      _error = null;
      _contactCtrl.clear();
      _passwordCtrl.clear();
      _confirmCtrl.clear();
    });
  }

  void _switchMode(_LoginMode mode) {
    setState(() {
      _loginMode = mode;
      _error = null;
      _contactCtrl.clear();
      _passwordCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authProvider).isLoading;

    return Dialog(
      backgroundColor: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────────
              Text(
                'L.I.G.T.A.S. SYSTEM',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.accent,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isSignUp ? 'Create Account' : 'Sign In',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 20),

              // ── Top tabs: LOG IN | SIGN UP ───────────────────────────────────
              Row(
                children: [
                  _topTab('LOG IN',   !_isSignUp, () => _switchTopTab(false)),
                  const SizedBox(width: 4),
                  _topTab('SIGN UP',   _isSignUp, () => _switchTopTab(true)),
                ],
              ),
              const Divider(color: Color(0xFF30363D), height: 1),
              const SizedBox(height: 16),

              if (!_isSignUp) ...[
                // ── Mode toggle: CITIZEN | STAFF ─────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    children: [
                      _modeBtn('CITIZEN', Icons.person_outline, _LoginMode.citizen),
                      _modeBtn('STAFF',   Icons.badge_outlined,  _LoginMode.staff),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Hint banner ───────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: _loginMode == _LoginMode.citizen
                        ? AppColors.accent.withValues(alpha: 0.08)
                        : const Color(0xFF21262D),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _loginMode == _LoginMode.citizen
                          ? AppColors.accent.withValues(alpha: 0.3)
                          : const Color(0xFF30363D),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _loginMode == _LoginMode.citizen
                            ? Icons.phone_android
                            : Icons.admin_panel_settings_outlined,
                        size: 14,
                        color: _loginMode == _LoginMode.citizen
                            ? AppColors.accent
                            : const Color(0xFF8B949E),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _loginMode == _LoginMode.citizen
                              ? 'Enter the contact number and password issued by the LGU during registration.'
                              : 'Rescuers: use your contact number and auto-generated password. Admins: use your registered email.',
                          style: TextStyle(
                            color: _loginMode == _LoginMode.citizen
                                ? AppColors.accent
                                : const Color(0xFF8B949E),
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Contact / Email field ─────────────────────────────────────
                _label(_loginMode == _LoginMode.citizen ? 'Contact Number' : 'Email or Contact Number'),
                _field(
                  controller: _contactCtrl,
                  hint: _loginMode == _LoginMode.citizen ? '09XXXXXXXXX' : 'name@example.com or 09XXXXXXXXX',
                  keyboardType: _loginMode == _LoginMode.citizen
                      ? TextInputType.phone
                      : TextInputType.text,
                ),
                const SizedBox(height: 12),

                _label(_loginMode == _LoginMode.citizen ? 'LGU-Issued Password' : 'Password'),
                _field(
                  controller: _passwordCtrl,
                  hint: _loginMode == _LoginMode.citizen ? 'Password from LGU' : 'Enter your password',
                  obscure: _obscurePassword,
                  onSubmit: _submit,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xFF8B949E),
                      size: 18,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ] else ...[
                // ── Sign-up form ─────────────────────────────────────────────
                const Text(
                  'Create an account to access the Citizen Portal. Your submission will be reviewed by LGU staff.',
                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 14),
                _label('Email Address'),
                _field(
                  controller: _contactCtrl,
                  hint: 'name@example.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                _label('Password'),
                _field(
                  controller: _passwordCtrl,
                  hint: 'At least 6 characters',
                  obscure: true,
                ),
                const SizedBox(height: 12),
                _label('Confirm Password'),
                _field(
                  controller: _confirmCtrl,
                  hint: 'Re-enter password',
                  obscure: true,
                  onSubmit: _submit,
                ),
              ],

              // ── Error banner ─────────────────────────────────────────────────
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D1217),
                    border: Border.all(color: const Color(0xAAF85149)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFF85149), fontSize: 12),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ── Submit ───────────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        loading ? const Color(0xFF21262D) : AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    elevation: 0,
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _isSignUp ? 'CREATE ACCOUNT' : 'LOG IN',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              fontSize: 13),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF30363D)),
                    foregroundColor: const Color(0xFF8B949E),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sub-widgets ─────────────────────────────────────────────────────────────

  Widget _topTab(String label, bool active, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: active ? AppColors.accent : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: active ? AppColors.accent : const Color(0xFF8B949E),
              ),
            ),
          ),
        ),
      );

  Widget _modeBtn(String label, IconData icon, _LoginMode mode) {
    final active = _loginMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.accent.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14,
                  color: active ? AppColors.accent : const Color(0xFF8B949E)),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: active ? AppColors.accent : const Color(0xFF8B949E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF8B949E),
            fontSize: 10,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
    VoidCallback? onSubmit,
    Widget? suffixIcon,
  }) =>
      TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction:
            onSubmit != null ? TextInputAction.done : TextInputAction.next,
        onSubmitted: onSubmit != null ? (_) => onSubmit() : null,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF8B949E), fontSize: 14),
          filled: true,
          fillColor: const Color(0xFF0D1117),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFF30363D)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFF30363D)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: AppColors.accent),
          ),
        ),
      );
}
