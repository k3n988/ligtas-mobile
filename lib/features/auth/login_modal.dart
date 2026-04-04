import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import 'auth_provider.dart';

enum AuthTab { login, signUp }

class LoginModal extends ConsumerStatefulWidget {
  final AuthTab initialTab;
  const LoginModal({super.key, this.initialTab = AuthTab.login});

  @override
  ConsumerState<LoginModal> createState() => _LoginModalState();
}

class _LoginModalState extends ConsumerState<LoginModal> {
  late AuthTab _tab;
  final _contactCtrl  = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
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
    final confirm  = _confirmCtrl.text;

    if (_tab == AuthTab.signUp && password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    final notifier = ref.read(authProvider.notifier);
    final err = _tab == AuthTab.login
        ? await notifier.login(contact, password)
        : await notifier.signUp(contact, password);

    if (err != null) {
      setState(() => _error = err);
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _switchTab(AuthTab t) {
    setState(() {
      _tab  = t;
      _error = null;
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
                _tab == AuthTab.login ? 'Sign In' : 'Create Account',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 20),

              // ── Tabs ────────────────────────────────────────────────────────
              Row(
                children: [
                  _tab_(AuthTab.login, 'LOG IN'),
                  const SizedBox(width: 4),
                  _tab_(AuthTab.signUp, 'SIGN UP'),
                ],
              ),
              const Divider(color: Color(0xFF30363D), height: 1),
              const SizedBox(height: 16),

              // ── Blurb ───────────────────────────────────────────────────────
              Text(
                _tab == AuthTab.login
                    ? 'Use your email or household contact number and password to sign in.'
                    : 'Register using your email or household contact number.',
                style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 16),

              // ── Form ────────────────────────────────────────────────────────
              _label('Username'),
              _field(
                controller: _contactCtrl,
                hint: 'Email or 09XX-XXX-XXXX',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),

              _label('Password'),
              _field(
                controller: _passwordCtrl,
                hint: 'Min. 6 characters',
                obscure: true,
              ),

              if (_tab == AuthTab.signUp) ...[
                const SizedBox(height: 12),
                _label('Confirm Password'),
                _field(
                  controller: _confirmCtrl,
                  hint: 'Re-enter password',
                  obscure: true,
                  onSubmit: _submit,
                ),
              ],

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

              // ── Submit ──────────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: loading
                        ? const Color(0xFF21262D)
                        : AppColors.accent,
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
                          _tab == AuthTab.login ? 'LOG IN' : 'CREATE ACCOUNT',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              fontSize: 13),
                        ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Cancel ──────────────────────────────────────────────────────
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

  Widget _tab_(AuthTab t, String label) {
    final active = _tab == t;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchTab(t),
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
  }) {
    return TextField(
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
}
