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
import 'services/api_service.dart';
import 'services/auth_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('ar', null);

  // Load saved token
  await ApiService.loadToken();

  // Setup FCM notifications
  if (!kIsWeb) {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true, badge: true, sound: true,
      );
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true,
      );

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'dawemly_channel', 'إشعارات داوملي',
        description: 'إشعارات نظام الحضور والانصراف',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      await flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_notification'),
          iOS: DarwinInitializationSettings(),
        ),
      );

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null) {
          flutterLocalNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                'dawemly_channel', 'إشعارات داوملي',
                channelDescription: 'إشعارات نظام الحضور والانصراف',
                importance: Importance.high,
                priority: Priority.high,
                icon: '@drawable/ic_notification',
                color: const Color(0xFF175CD3),
                largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
              ),
            ),
          );
        }
      });
    } catch (_) {}
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const RasdApp());
}

class RasdApp extends StatefulWidget {
  const RasdApp({super.key});
  @override
  State<RasdApp> createState() => _RasdAppState();
}

class _RasdAppState extends State<RasdApp> {
  String _fontSize = 'medium';

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
        setState(() => _fontSize = settings['fontSize'] ?? 'medium');
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
      theme: ThemeData(
        scaffoldBackgroundColor: C.bg,
        textTheme: GoogleFonts.tajawalTextTheme(),
        colorScheme: ColorScheme.fromSeed(seedColor: C.pri),
        useMaterial3: true,
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

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  void _checkExistingSession() async {
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
      return Scaffold(
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset('assets/app_icon_192.png', width: 80, height: 80, fit: BoxFit.cover),
          ),
          const SizedBox(height: 16),
          Text('داوِملي', style: GoogleFonts.tajawal(fontSize: 24, fontWeight: FontWeight.w800, color: C.pri)),
          const SizedBox(height: 8),
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: C.pri)),
        ])),
      );
    }

    if (_user == null) return LoginPage(onLogin: _onLogin);
    final role = _user!['role'] ?? 'employee';

    final isWeb = MediaQuery.of(context).size.width > 800;
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
    return EmployeeApp(user: _user!, onLogout: _onLogout);
  }
}
