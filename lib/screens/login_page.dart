import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../l10n/app_locale.dart';
import '../main.dart' show RasdApp, prefs;

class LoginPage extends StatefulWidget {
  final Function(Map<String, dynamic>) onLogin;
  const LoginPage({super.key, required this.onLogin});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = AuthService();
  final _localAuth = LocalAuthentication();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  // Encrypted storage for biometric credentials (Android KeyStore / iOS Keychain).
  // On web, flutter_secure_storage is unreliable — fall back to SharedPreferences.
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );
  bool _showPass = false, _loading = false, _remember = false;
  String? _error;

  // Platform-aware read/write for biometric creds.
  Future<String?> _readCred(String key) async {
    if (kIsWeb) return prefs.getString(key);
    // One-time migration: move old plaintext creds into secure storage, then wipe.
    final legacy = prefs.getString(key);
    if (legacy != null && legacy.isNotEmpty) {
      await _secureStorage.write(key: key, value: legacy);
      await prefs.remove(key);
      return legacy;
    }
    return await _secureStorage.read(key: key);
  }

  Future<void> _writeCred(String key, String value) async {
    if (kIsWeb) {
      await prefs.setString(key, value);
    } else {
      await _secureStorage.write(key: key, value: value);
      // Ensure no plaintext copy lingers from older builds.
      if (prefs.containsKey(key)) await prefs.remove(key);
    }
  }

  static const _navy = Color(0xFF0C2D57);

  TextStyle _tj(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() { _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  // ─── Language switch ───
  void _switchLocale(String loc) async {
    await L.setLocale(loc);
    if (mounted) {
      RasdApp.rebuildApp(context);
      setState(() {});
    }
  }

  // ─── Auth methods ───
  void _biometricLogin() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Check if we have saved credentials from a previous login (encrypted on mobile)
      final savedEmail = await _readCred('bio_email');
      final savedPass = await _readCred('bio_pass');
      if (savedEmail == null || savedPass == null) {
        setState(() { _error = L.tr('err_biometric_email_first'); _loading = false; });
        return;
      }
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck && !isSupported) { setState(() { _error = L.tr('err_biometric_not_supported'); _loading = false; }); return; }
      final authenticated = await _localAuth.authenticate(localizedReason: L.tr('biometric_login_reason'), options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false));
      if (!authenticated) { setState(() { _error = L.tr('err_biometric_failed'); _loading = false; }); return; }
      // Use saved credentials to login via API
      final user = await _auth.loginWithEmail(savedEmail, savedPass);
      if (user != null) { widget.onLogin(user); } else { setState(() { _error = L.tr('err_login'); _loading = false; }); }
    } catch (e) {
      String msg = e.toString().replaceAll('Exception: ', '');
      if (msg.contains('SocketException') || msg.contains('TimeoutException')) msg = L.tr('err_network');
      setState(() { _error = msg; _loading = false; });
    }
  }

  void _emailLogin() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) { setState(() => _error = L.tr('err_enter_email_pass')); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final user = await _auth.loginWithEmail(_emailCtrl.text.trim(), _passCtrl.text);
      if (user != null) {
        // Save credentials for biometric quick-login (encrypted at rest on mobile)
        await _writeCred('bio_email', _emailCtrl.text.trim());
        await _writeCred('bio_pass', _passCtrl.text);
        widget.onLogin(user);
      } else { setState(() { _error = L.tr('err_login'); _loading = false; }); }
    } catch (e) {
      String msg = e.toString().replaceAll('Exception: ', '');
      if (msg.contains('SocketException') || msg.contains('TimeoutException') || msg.contains('HandshakeException')) {
        msg = L.tr('err_network');
      } else {
        msg = L.serverText(msg);
      }
      setState(() { _error = msg; _loading = false; });
    }
  }

  void _forgotPass() async {
    if (_emailCtrl.text.isEmpty) { setState(() => _error = L.tr('err_enter_email')); return; }
    _showMsg(L.tr('contact_admin_reset'));
  }

  void _showMsg(String msg) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: _tj(13, color: Colors.white)), backgroundColor: C.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd)))); }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 800;
    return Scaffold(
      backgroundColor: isWeb ? C.bg : const Color(0xFFF5F7FA),
      body: isWeb ? _webLayout() : _mobileLayout(),
    );
  }

  // ─── Language Selector Widget ───
  Widget _langSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _langBtn('العربية', 'ar'),
        const SizedBox(width: 4),
        _langBtn('English', 'en'),
      ]),
    );
  }

  Widget _langBtn(String label, String loc) {
    final isActive = L.locale == loc;
    return InkWell(
      onTap: () => _switchLocale(loc),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? C.pri : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.tajawal(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? Colors.white : C.sub,
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════
  //  MOBILE layout
  // ════════════════════════════════════════════
  Widget _mobileLayout() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // ─── Language Selector ───
              _langSelector(),

              const SizedBox(height: 20),

              // ─── Logo & Welcome ───
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: C.pri.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 6))],
                ),
                child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.asset('assets/app_icon_192.png', fit: BoxFit.cover)),
              ),
              const SizedBox(height: 16),
              Text(L.tr('welcome'), style: _tj(22, weight: FontWeight.w800, color: C.text)),
              const SizedBox(height: 4),
              Text(L.tr('login_subtitle'), style: _tj(14, color: C.sub)),

              const SizedBox(height: 32),

              // ─── Form Card ───
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: C.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    // Error
                    if (_error != null) Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: C.redL, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.redBd)),
                      child: Text(_error!, style: _tj(12, weight: FontWeight.w600, color: C.red), textAlign: L.isAr ? TextAlign.right : TextAlign.left),
                    ),

                    // Email/Username field
                    _formLabel(L.tr('username_email')),
                    _formField(
                      ctrl: _emailCtrl,
                      hint: L.tr('username_email'),
                      icon: Icons.person_outline_rounded,
                      isLtr: true,
                    ),

                    const SizedBox(height: 20),

                    // Password field
                    _formLabel(L.tr('password')),
                    _formField(
                      ctrl: _passCtrl,
                      hint: L.tr('password'),
                      icon: Icons.lock_outline_rounded,
                      isLtr: true,
                      isPass: true,
                    ),

                    const SizedBox(height: 12),

                    // Remember me + Forgot password
                    Row(
                      children: [
                        // Remember me
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(L.tr('remember_me'), style: _tj(12, weight: FontWeight.w500, color: C.sub)),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 20, height: 20,
                              child: Checkbox(
                                value: _remember,
                                onChanged: (v) => setState(() => _remember = v ?? false),
                                activeColor: C.pri,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                side: BorderSide(color: C.border, width: 1.5),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Forgot password
                        TextButton(
                          onPressed: _forgotPass,
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                          child: Text(L.tr('forgot_password'), style: _tj(12, weight: FontWeight.w600, color: C.pri)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Login button + Biometric
                    Row(
                      children: [
                        // Biometric button
                        InkWell(
                          onTap: _loading ? null : _biometricLogin,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              color: C.priLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: C.pri.withOpacity(0.2)),
                            ),
                            child: const Icon(Icons.fingerprint_rounded, size: 28, color: C.pri),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Login button
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _emailLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _loading ? C.muted : C.pri,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: _loading
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                : Text(L.tr('login'), style: _tj(16, weight: FontWeight.w700, color: Colors.white)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Footer
              Text(L.tr('app_footer_mobile', args: {'year': '${DateTime.now().year}'}), style: _tj(11, color: C.muted)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formLabel(String t) {
    return Align(
      alignment: L.isAr ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: _tj(13, weight: FontWeight.w600, color: C.sub)),
      ),
    );
  }

  Widget _formField({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    bool isLtr = false,
    bool isPass = false,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: isPass && !_showPass,
      textDirection: isLtr ? TextDirection.ltr : L.textDirection,
      textAlign: isLtr ? TextAlign.left : (L.isAr ? TextAlign.right : TextAlign.left),
      keyboardType: isPass ? TextInputType.visiblePassword : TextInputType.emailAddress,
      style: _tj(14, color: C.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: _tj(14, color: C.hint),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Icon(icon, size: 20, color: C.muted),
        ),
        suffixIconConstraints: const BoxConstraints(minWidth: 44),
        prefixIcon: isPass
          ? IconButton(
              icon: Icon(_showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: C.muted),
              onPressed: () => setState(() => _showPass = !_showPass),
            )
          : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: C.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: C.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.pri, width: 1.5)),
      ),
      onChanged: (_) { if (_error != null) setState(() => _error = null); },
    );
  }

  // ════════════════════════════════════════════
  //  WEB layout
  // ════════════════════════════════════════════
  Widget _webLayout() {
    return Row(textDirection: L.textDirection, children: [
      Expanded(
        flex: 45,
        child: Container(
          color: Colors.white,
          child: Center(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
            child: SizedBox(width: 400, child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              // Language selector at top
              _langSelector(),
              const SizedBox(height: 24),
              Text(L.tr('login'), style: _tj(28, weight: FontWeight.w800, color: _navy)),
              const SizedBox(height: 8),
              Text(L.tr('login_web_subtitle'), style: _tj(14, color: const Color(0xFF6B7280))),
              const SizedBox(height: 32),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFD1D5DB), width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 3))]),
                  child: ClipOval(child: Image.asset('assets/app_icon_192.png', fit: BoxFit.cover)),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(L.tr('app_name'), style: _tj(20, weight: FontWeight.w800, color: _navy)),
                  Text(L.tr('app_subtitle'), style: _tj(11, color: const Color(0xFF6B7280))),
                ]),
              ]),
              const SizedBox(height: 28),
              if (_error != null) Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFECACA))),
                child: Row(children: [Expanded(child: Text(_error!, style: _tj(13, color: const Color(0xFF991B1B)), textAlign: L.isAr ? TextAlign.right : TextAlign.left)), const SizedBox(width: 10), const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626))]),
              ),
              _webFormLabel(L.tr('email')),
              _webInput(_emailCtrl, L.tr('enter_email'), icon: Icons.person_outline, isLtr: true),
              const SizedBox(height: 22),
              _webFormLabel(L.tr('password')),
              _webInput(_passCtrl, L.tr('enter_password'), icon: Icons.lock_outline, isLtr: true, isPass: true),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
                onPressed: _loading ? null : _emailLogin,
                style: ElevatedButton.styleFrom(backgroundColor: _loading ? const Color(0xFF9CA3AF) : _navy, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.login_rounded, size: 16), const SizedBox(width: 8), Text(L.tr('login'), style: _tj(15, weight: FontWeight.w700, color: Colors.white))]),
              )),
              Padding(padding: const EdgeInsets.only(top: 48), child: Column(children: [
                Text(L.tr('app_footer_web', args: {'year': '${DateTime.now().year}'}), style: _tj(11, color: const Color(0xFF9CA3AF))),
                const SizedBox(height: 4),
                Text(L.tr('developer'), style: _tj(11, color: const Color(0xFF9CA3AF).withOpacity(0.7))),
              ])),
            ])),
          )),
        ),
      ),
      Expanded(
        flex: 55,
        child: Container(
          color: const Color(0xFFe8f4fd),
          child: Image.asset('assets/login_bg.png', fit: BoxFit.cover, width: double.infinity, height: double.infinity, alignment: Alignment.center),
        ),
      ),
    ]);
  }

  Widget _webFormLabel(String t) => Align(alignment: L.isAr ? Alignment.centerRight : Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t, style: _tj(13, weight: FontWeight.w600, color: const Color(0xFF374151)))));

  Widget _webInput(TextEditingController ctrl, String hint, {IconData? icon, bool isLtr = false, bool isPass = false}) {
    return TextField(
      controller: ctrl, obscureText: isPass && !_showPass,
      textDirection: isLtr ? TextDirection.ltr : L.textDirection, textAlign: isLtr ? TextAlign.left : (L.isAr ? TextAlign.right : TextAlign.left),
      keyboardType: isPass ? TextInputType.visiblePassword : TextInputType.emailAddress,
      style: _tj(14, color: const Color(0xFF1F2937)),
      decoration: InputDecoration(
        hintText: hint, hintStyle: _tj(14, color: const Color(0xFF9CA3AF)),
        filled: true, fillColor: const Color(0xFFFAFBFC),
        contentPadding: const EdgeInsets.only(left: 16, right: 44, top: 14, bottom: 14),
        suffixIcon: icon != null ? Padding(padding: const EdgeInsets.only(right: 14), child: Icon(icon, size: 14, color: const Color(0xFF9CA3AF))) : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 40),
        prefixIcon: isPass ? IconButton(icon: Icon(_showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 14, color: const Color(0xFF9CA3AF)), onPressed: () => setState(() => _showPass = !_showPass)) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0C2D57), width: 1.5)),
      ),
      onChanged: (_) { if (_error != null) setState(() => _error = null); },
    );
  }
}
