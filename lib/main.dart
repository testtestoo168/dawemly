import 'dart:convert';
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
import 'l10n/app_locale.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Shared prefs instance — loaded once, reused everywhere
late final SharedPreferences prefs;

Future<void> _initFirebase() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (_) {
    // Already initialized (Android auto-init via google-services.json)
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Run ALL critical init in parallel
  final results = await Future.wait([
    SharedPreferences.getInstance(),
    _initFirebase(),
    initializeDateFormatting('ar', null),
  ]);
  prefs = results[0] as SharedPreferences;

  // Initialize locale from saved prefs
  L.init();

  // Load token from the already-fetched prefs (synchronous, no IO)
  ApiService.loadTokenSync(prefs);

  // Lock to portrait only on mobile
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Use bundled fonts only — never download from network
  GoogleFonts.config.allowRuntimeFetching = false;

  // Non-blocking background tasks
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

    final channel = AndroidNotificationChannel(
      'dawemly_channel', L.tr('notif_channel_name'),
      description: L.tr('notif_channel_desc'),
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
            'dawemly_channel', L.tr('notif_channel_name'),
            channelDescription: L.tr('notif_channel_desc'),
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

  /// Call this from anywhere to rebuild the app (e.g. after locale change).
  static void rebuildApp(BuildContext context) {
    context.findAncestorStateOfType<_RasdAppState>()?.rebuild();
  }

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

  void rebuild() => setState(() {});

  void _loadDisplaySettings() async {
    if (!ApiService.isLoggedIn) return;
    // Read cached settings first (instant)
    final cached = prefs.getString('display_settings');
    if (cached != null) {
      _applySettings(jsonDecode(cached) as Map<String, dynamic>);
    }
    // Then refresh from API in background
    try {
      final res = await ApiService.get('admin.php?action=get_settings');
      final settings = res['settings'] as Map<String, dynamic>? ?? {};
      prefs.setString('display_settings', jsonEncode(settings));
      _applySettings(settings);
    } catch (_) {}
  }

  void _applySettings(Map<String, dynamic> settings) {
    if (!mounted) return;
    setState(() {
      _fontSize = settings['fontSize'] ?? 'medium';
      final dm = settings['darkMode'];
      _darkMode = dm == true || dm == 1 || dm == '1' || dm == 'true';
    });
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
      title: L.tr('app_name'),
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
          child: Directionality(textDirection: L.textDirection, child: child!),
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
    ApiService.onUnauthorized = () {
      if (mounted) setState(() => _user = null);
    };
    _fastStart();
  }

  @override
  void dispose() {
    ApiService.onUnauthorized = null;
    super.dispose();
  }

  void _fastStart() {
    // Use the global prefs (already loaded in main) — zero IO wait
    _onboardingDone = prefs.getBool('onboarding_done') ?? false;

    if (ApiService.isLoggedIn && ApiService.currentUser != null) {
      // Show cached user IMMEDIATELY — no API wait
      _user = ApiService.currentUser;
      _loading = false;
      // Verify session in background (if expired, auto-logout fires)
      _verifySessionInBackground();
    } else {
      _loading = false;
    }
  }

  void _verifySessionInBackground() async {
    try {
      final user = await AuthService().getCurrentUser();
      if (user != null && mounted) {
        setState(() => _user = user);
        AuthService.refreshFcmToken();
      } else {
        // Token expired
        await ApiService.clearToken();
        if (mounted) setState(() => _user = null);
      }
    } catch (_) {
      // Network error — keep cached user, don't logout
    }
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
            Text(L.tr('app_name'), style: GoogleFonts.tajawal(fontSize: 28, fontWeight: FontWeight.w800, color: C.pri)),
            const SizedBox(height: 12),
            Text(L.tr('dashboard_admin_only'),
              style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w700, color: C.text),
              textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(L.tr('use_mobile_app'),
              style: GoogleFonts.tajawal(fontSize: 14, color: C.sub, height: 1.6),
              textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: _onLogout,
              icon: const Icon(Icons.logout, size: 18, color: C.red),
              label: Text(L.tr('logout'),
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
        SharedPreferences.getInstance().then((p) => p.setBool('onboarding_done', true));
        if (mounted) setState(() => _onboardingDone = true);
      });
    }

    return EmployeeApp(user: _user!, onLogout: _onLogout);
  }
}
