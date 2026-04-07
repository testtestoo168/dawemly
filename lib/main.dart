import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'theme/app_colors.dart';
import 'screens/login_page.dart';
import 'screens/employee/employee_app.dart';
import 'screens/admin/admin_app.dart';
import 'screens/superadmin/superadmin_app.dart';
import 'screens/onboarding_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/server_time_service.dart';
import 'screens/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Run critical init in parallel for fastest startup
  await Future.wait([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    initializeDateFormatting('ar', null),
    ApiService.loadToken(),
  ]);

  // Non-blocking: sync server time + setup FCM in background
  ServerTimeService().startPeriodicSync();
  _setupFcm();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const RasdApp());
}

/// FCM setup — runs in background, never blocks app startup
void _setupFcm() async {
  if (kIsWeb) return;
  try {
    await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );

    const channel = AndroidNotificationChannel(
      'dawemly_channel', 'إشعارات داوملي',
      description: 'إشعارات نظام الحضور والانصراف',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    final flnp = FlutterLocalNotificationsPlugin();
    await flnp.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await flnp.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_notification'),
      iOS: DarwinInitializationSettings(),
    ));

    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n != null) {
        flnp.show(n.hashCode, n.title, n.body, NotificationDetails(
          android: AndroidNotificationDetails(
            'dawemly_channel', 'إشعارات داوملي',
            channelDescription: 'إشعارات نظام الحضور والانصراف',
            importance: Importance.high, priority: Priority.high,
            icon: '@drawable/ic_notification',
            color: const Color(0xFF175CD3),
            largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        ));
      }
    });
  } catch (_) {}
}

class RasdApp extends StatefulWidget {
  const RasdApp({super.key});
  @override
  State<RasdApp> createState() => _RasdAppState();
}

class _RasdAppState extends State<RasdApp> {
  String _fontSize = 'medium';
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadDisplaySettings();
  }

  void _loadDisplaySettings() async {
    try {
      final res = await ApiService.get('admin.php?action=get_settings');
      final settings = res['settings'] as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _fontSize = settings['fontSize'] ?? 'medium';
          final dm = settings['darkMode'];
          _darkMode = dm == true || dm == 1 || dm == '1' || dm == 'true';
        });
      }
    } catch (_) {}
  }

  double get _fontScale {
    switch (_fontSize) {
      case 'small': return 0.88;
      case 'large': return 1.12;
      default: return 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'داوِملي',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        scaffoldBackgroundColor: C.bg,
        textTheme: GoogleFonts.tajawalTextTheme(),
        colorScheme: ColorScheme.fromSeed(seedColor: C.pri),
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      darkTheme: ThemeData(
        scaffoldBackgroundColor: CD.bg,
        textTheme: GoogleFonts.tajawalTextTheme(ThemeData.dark().textTheme),
        colorScheme: ColorScheme.fromSeed(seedColor: CD.pri, brightness: Brightness.dark),
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      builder: (ctx, child) {
        return MediaQuery(
          data: MediaQuery.of(ctx).copyWith(
            textScaler: TextScaler.linear(_fontScale),
          ),
          child: Directionality(textDirection: TextDirection.rtl, child: child!),
        );
      },
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  bool? _onboardingDone;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    // Register auto-logout callback for 401 responses
    ApiService.onUnauthorized = () {
      if (mounted) setState(() => _user = null);
    };
    _checkExistingSession();
  }

  @override
  void dispose() {
    ApiService.onUnauthorized = null;
    super.dispose();
  }

  void _checkExistingSession() async {
    // Load onboarding status
    final prefs = await SharedPreferences.getInstance();
    _onboardingDone = prefs.getBool('onboarding_done') ?? false;

    if (ApiService.isLoggedIn) {
      try {
        final user = await AuthService().getCurrentUser();
        if (user != null && mounted) {
          setState(() { _user = user; _loading = false; });
          AuthService.refreshFcmToken();
          return;
        }
      } catch (_) {}
      // Token expired or invalid
      await ApiService.clearToken();
    }
    if (mounted) setState(() => _loading = false);
  }

  void _onLogin(Map<String, dynamic> user) {
    setState(() => _user = user);
    AuthService.refreshFcmToken();
  }

  void _onLogout() async {
    await AuthService().logout();
    if (mounted) setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SplashScreen();
    }

    if (_user == null) return LoginPage(onLogin: _onLogin);
    final role = _user!['role'] ?? 'employee';

    final isWeb = MediaQuery.of(context).size.width > 800;

    // Super admin — web only
    if (role == 'superadmin' && isWeb) {
      return SuperadminApp(user: _user!, onLogout: _onLogout);
    }

    // Block non-admin, non-superadmin from web
    if (isWeb && role != 'admin') {
      return Scaffold(
        body: Center(child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset('assets/app_icon_192.png', width: 80, height: 80, fit: BoxFit.cover),
            ),
            const SizedBox(height: 24),
            Text('داوِملي', style: GoogleFonts.tajawal(fontSize: 28, fontWeight: FontWeight.w800, color: C.pri)),
            const SizedBox(height: 12),
            Text('لوحة التحكم متاحة للإدارة فقط',
              style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w700, color: C.text),
              textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('يرجى استخدام تطبيق الهاتف لتسجيل الحضور والانصراف',
              style: GoogleFonts.tajawal(fontSize: 14, color: C.sub, height: 1.6),
              textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: _onLogout,
              icon: const Icon(Icons.logout, size: 18, color: C.red),
              label: Text('تسجيل الخروج',
                style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: C.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: C.redBd),
                backgroundColor: C.redL,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            )),
          ]),
        )),
      );
    }

    if (role == 'admin') return AdminApp(user: _user!, onLogout: _onLogout);

    // Employee — show onboarding if not done yet
    if (_onboardingDone != true && !_showOnboarding && !isWeb) {
      // First time employee — show onboarding
      return OnboardingScreen(onComplete: () {
        if (mounted) setState(() => _onboardingDone = true);
      });
    }

    return EmployeeApp(user: _user!, onLogout: _onLogout);
  }
}
