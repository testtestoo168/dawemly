import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

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
  bool _showPass = false, _loading = false, _remember = false;
  String? _error;

  static const _navy = Color(0xFF0C2D57);

  TextStyle _tj(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() { _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  // ─── Auth methods ───
  void _biometricLogin() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Biometric requires an active session — user must log in with email first
      final currentUser = ApiService.currentUser;
      if (currentUser == null) {
        setState(() { _error = 'سجّل دخول بالبريد أولاً ثم استخدم البصمة'; _loading = false; });
        return;
      }
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck && !isSupported) { setState(() { _error = 'البصمة غير مدعومة على هذا الجهاز'; _loading = false; }); return; }
      final authenticated = await _localAuth.authenticate(localizedReason: 'استخدم البصمة لتسجيل الدخول', options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false));
      if (!authenticated) { setState(() { _error = 'فشل التحقق من البصمة'; _loading = false; }); return; }
      widget.onLogin(currentUser);
    } catch (e) { setState(() { _error = 'خطأ في البصمة — سجّل دخول بالبريد أولاً'; _loading = false; }); }
  }

  void _emailLogin() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) { setState(() => _error = 'يرجى إدخال البريد وكلمة المرور'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final user = await _auth.loginWithEmail(_emailCtrl.text.trim(), _passCtrl.text);
      if (user != null) { widget.onLogin(user); } else { setState(() { _error = 'خطأ في تسجيل الدخول'; _loading = false; }); }
    } catch (e) {
      String msg = 'خطأ في تسجيل الدخول';
      final errStr = e.toString();
      if (errStr.contains('user-not-found')) msg = 'البريد غير مسجل في النظام';
      else if (errStr.contains('wrong-password') || errStr.contains('invalid-credential')) msg = 'كلمة المرور غير صحيحة';
      else if (errStr.contains('invalid-email')) msg = 'البريد الإلكتروني غير صحيح';
      else if (errStr.contains('network')) msg = 'لا يوجد اتصال بالإنترنت';
      else if (errStr.contains('حسابك مفتوح على جهاز آخر') || errStr.contains('تسجيل الخروج من الجهاز')) msg = errStr.replaceAll('Exception: ', '');
      setState(() { _error = msg; _loading = false; });
    }
  }

  void _forgotPass() async {
    if (_emailCtrl.text.isEmpty) { setState(() => _error = 'يرجى إدخال البريد الإلكتروني'); return; }
    _showMsg('تواصل مع المدير لإعادة تعيين كلمة المرور');
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

  // ════════════════════════════════════════════
  //  📱 MOBILE — رصد style clean login
  // ════════════════════════════════════════════
  Widget _mobileLayout() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),

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
              Text('مرحباً بك,', style: _tj(22, weight: FontWeight.w800, color: C.text)),
              const SizedBox(height: 4),
              Text('يمكنك تسجيل الدخول في تطبيق داوِملي!', style: _tj(14, color: C.sub)),

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
                      child: Text(_error!, style: _tj(12, weight: FontWeight.w600, color: C.red), textAlign: TextAlign.right),
                    ),

                    // Email/Username field
                    _formLabel('اسم المستخدم / البريد'),
                    _formField(
                      ctrl: _emailCtrl,
                      hint: 'اسم المستخدم / البريد',
                      icon: Icons.person_outline_rounded,
                      isLtr: true,
                    ),

                    const SizedBox(height: 20),

                    // Password field
                    _formLabel('كلمة المرور'),
                    _formField(
                      ctrl: _passCtrl,
                      hint: 'كلمة المرور',
                      icon: Icons.lock_outline_rounded,
                      isLtr: true,
                      isPass: true,
                    ),

                    const SizedBox(height: 12),

                    // Remember me + Forgot password
                    Row(
                      children: [
                        // Remember me (RTL: appears on right)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('تذكرني', style: _tj(12, weight: FontWeight.w500, color: C.sub)),
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
                        // Forgot password (RTL: appears on left)
                        TextButton(
                          onPressed: _forgotPass,
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                          child: Text('نسيت كلمة المرور؟', style: _tj(12, weight: FontWeight.w600, color: C.pri)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Login button + Biometric
                    Row(
                      children: [
                        // Biometric button (RTL: appears on right)
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
                                : Text('تسجيل الدخول', style: _tj(16, weight: FontWeight.w700, color: Colors.white)),
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
              Text('داوِملي v1.0 — نظام إدارة الحضور © ${DateTime.now().year}', style: _tj(11, color: C.muted)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formLabel(String t) {
    return Align(
      alignment: Alignment.centerRight,
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
      textDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
      textAlign: isLtr ? TextAlign.left : TextAlign.right,
      keyboardType: isPass ? TextInputType.visiblePassword : TextInputType.emailAddress,
      style: _tj(14, color: C.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: _tj(14, color: C.hint),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        // Icon on right side (suffix in RTL context)
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Icon(icon, size: 20, color: C.muted),
        ),
        suffixIconConstraints: const BoxConstraints(minWidth: 44),
        // Eye icon for password on left side
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
  //  🖥️ WEB — URS style (unchanged)
  // ════════════════════════════════════════════
  Widget _webLayout() {
    return Row(textDirection: TextDirection.rtl, children: [
      Expanded(
        flex: 45,
        child: Container(
          color: Colors.white,
          child: Center(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
            child: SizedBox(width: 400, child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Text('تسجيل الدخول', style: _tj(28, weight: FontWeight.w800, color: _navy)),
              const SizedBox(height: 8),
              Text('أدخل بياناتك للوصول إلى لوحة التحكم', style: _tj(14, color: const Color(0xFF6B7280))),
              const SizedBox(height: 32),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFD1D5DB), width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 3))]),
                  child: ClipOval(child: Image.asset('assets/app_icon_192.png', fit: BoxFit.cover)),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('داوِملي', style: _tj(20, weight: FontWeight.w800, color: _navy)),
                  Text('نظام إدارة الحضور والانصراف', style: _tj(11, color: const Color(0xFF6B7280))),
                ]),
              ]),
              const SizedBox(height: 28),
              if (_error != null) Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFECACA))),
                child: Row(children: [Expanded(child: Text(_error!, style: _tj(13, color: const Color(0xFF991B1B)), textAlign: TextAlign.right)), const SizedBox(width: 10), const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626))]),
              ),
              _webFormLabel('البريد الإلكتروني'),
              _webInput(_emailCtrl, 'أدخل البريد الإلكتروني', icon: Icons.person_outline, isLtr: true),
              const SizedBox(height: 22),
              _webFormLabel('كلمة المرور'),
              _webInput(_passCtrl, 'أدخل كلمة المرور', icon: Icons.lock_outline, isLtr: true, isPass: true),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
                onPressed: _loading ? null : _emailLogin,
                style: ElevatedButton.styleFrom(backgroundColor: _loading ? const Color(0xFF9CA3AF) : _navy, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.login_rounded, size: 16), const SizedBox(width: 8), Text('تسجيل الدخول', style: _tj(15, weight: FontWeight.w700, color: Colors.white))]),
              )),
              Padding(padding: const EdgeInsets.only(top: 48), child: Column(children: [
                Text('داوِملي © ${DateTime.now().year}', style: _tj(11, color: const Color(0xFF9CA3AF))),
                const SizedBox(height: 4),
                Text('تطوير: م. أحمد حسام', style: _tj(11, color: const Color(0xFF9CA3AF).withOpacity(0.7))),
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

  Widget _webFormLabel(String t) => Align(alignment: Alignment.centerRight, child: Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t, style: _tj(13, weight: FontWeight.w600, color: const Color(0xFF374151)))));

  Widget _webInput(TextEditingController ctrl, String hint, {IconData? icon, bool isLtr = false, bool isPass = false}) {
    return TextField(
      controller: ctrl, obscureText: isPass && !_showPass,
      textDirection: isLtr ? TextDirection.ltr : TextDirection.rtl, textAlign: isLtr ? TextAlign.left : TextAlign.right,
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
