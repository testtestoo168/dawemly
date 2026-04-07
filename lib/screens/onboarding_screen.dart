import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pc = PageController();
  int _currentPage = 0;

  TextStyle _tj(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color);

  static const _slides = [
    _Slide(
      icon: Icons.dashboard_customize_rounded,
      title: 'مرحباً بك في داوِملي',
      subtitle: 'نظام إدارة الحضور والانصراف',
      color: Color(0xFF175CD3),
      bgColor: Color(0xFFE7EFFF),
    ),
    _Slide(
      icon: Icons.fingerprint_rounded,
      title: 'سجّل حضورك بسهولة',
      subtitle: 'بصمة الإصبع أو الوجه أو GPS',
      color: Color(0xFF17B26A),
      bgColor: Color(0xFFECFDF3),
    ),
    _Slide(
      icon: Icons.bar_chart_rounded,
      title: 'تابع سجلك',
      subtitle: 'سجل حضورك، إجازاتك، وطلباتك',
      color: Color(0xFF7F56D9),
      bgColor: Color(0xFFF4F3FF),
    ),
    _Slide(
      icon: Icons.check_circle_rounded,
      title: 'ابدأ الآن',
      subtitle: 'كل شيء جاهز لتبدأ رحلتك',
      color: Color(0xFFF79009),
      bgColor: Color(0xFFFFFAEB),
    ),
  ];

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    widget.onComplete();
  }

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _pc.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      _completeOnboarding();
    }
  }

  void _skip() {
    _completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.white,
      body: SafeArea(
        child: Column(children: [
          // Skip button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              if (_currentPage < _slides.length - 1)
                TextButton(
                  onPressed: _skip,
                  child: Text('تخطي', style: _tj(14, weight: FontWeight.w600, color: C.sub)),
                ),
            ]),
          ),

          // Pages
          Expanded(
            child: PageView.builder(
              controller: _pc,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemCount: _slides.length,
              itemBuilder: (ctx, i) {
                final slide = _slides[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon circle
                      Container(
                        width: 140, height: 140,
                        decoration: BoxDecoration(
                          color: slide.bgColor,
                          shape: BoxShape.circle,
                        ),
                        child: i == 0
                          ? ClipOval(
                              child: Padding(
                                padding: const EdgeInsets.all(28),
                                child: Image.asset('assets/app_icon_192.png', fit: BoxFit.contain),
                              ),
                            )
                          : Icon(slide.icon, size: 64, color: slide.color),
                      ),
                      const SizedBox(height: 40),
                      // Title
                      Text(
                        slide.title,
                        style: _tj(26, weight: FontWeight.w800, color: C.text),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      // Subtitle
                      Text(
                        slide.subtitle,
                        style: _tj(16, color: C.sub, weight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Dots + button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(children: [
              // Dots
              Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i ? C.pri : C.hint,
                    borderRadius: BorderRadius.circular(DS.radiusPill),
                  ),
                ),
              )),
              const SizedBox(height: 32),
              // Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: C.pri,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd)),
                    elevation: 0,
                  ),
                  child: Text(
                    _currentPage == _slides.length - 1 ? 'دخول' : 'التالي',
                    style: _tj(16, weight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Slide {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color bgColor;
  const _Slide({required this.icon, required this.title, required this.subtitle, required this.color, required this.bgColor});
}
