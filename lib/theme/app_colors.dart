import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Employee app colors (original bright blue)
class C {
  static const Color pri     = Color(0xFF175CD3);
  static const Color priDark = Color(0xFF1249A6);
  static const Color priLight= Color(0xFFE7EFFF);
  static const Color priBg   = Color(0xFFD1E4FF);

  static const Color bg      = Color(0xFFF3F4F6);
  static const Color white   = Color(0xFFFFFFFF);
  static const Color card    = Color(0xFFFFFFFF);

  static const Color text    = Color(0xFF1F2A37);
  static const Color sub     = Color(0xFF6C737F);
  static const Color muted   = Color(0xFF9DA4AE);
  static const Color hint    = Color(0xFFD0D5DD);

  static const Color border  = Color(0xFFE5E7EB);
  static const Color div     = Color(0xFFF0F2F5);

  static const Color green   = Color(0xFF17B26A);
  static const Color greenL  = Color(0xFFECFDF3);
  static const Color greenBd = Color(0xFFABEFC6);

  static const Color red     = Color(0xFFF04438);
  static const Color redL    = Color(0xFFFEF3F2);
  static const Color redBd   = Color(0xFFFECDCA);

  static const Color orange  = Color(0xFFF79009);
  static const Color orangeL = Color(0xFFFFFAEB);
  static const Color orangeBd= Color(0xFFFEDF89);

  static const Color purple  = Color(0xFF7F56D9);
  static const Color purpleL = Color(0xFFF4F3FF);

  static const Color teal    = Color(0xFF0BA5EC);
  static const Color dark    = Color(0xFF384250);
}

/// Admin web-only colors (pharmacy dark navy)
class AC {
  static const Color pri     = Color(0xFF0F3460);
  static const Color priDark = Color(0xFF0A2840);
  static const Color priLight= Color(0xFFE8EDF2);
  static const Color priBg   = Color(0xFFD0DAE8);

  static const Color bg      = Color(0xFFF4F5F7);
  static const Color white   = Color(0xFFFFFFFF);
  static const Color card    = Color(0xFFFFFFFF);

  static const Color text    = Color(0xFF1A1A2E);
  static const Color sub     = Color(0xFF64748B);
  static const Color muted   = Color(0xFF94A3B8);
  static const Color hint    = Color(0xFFD1D5DB);

  static const Color border  = Color(0xFFD1D5DB);
  static const Color div     = Color(0xFFE8EDF2);

  static const Color green   = Color(0xFF16A34A);
  static const Color greenL  = Color(0xFFDCFCE7);
  static const Color greenBd = Color(0xFFBBF7D0);

  static const Color red     = Color(0xFFD4183D);
  static const Color redL    = Color(0xFFFEE2E2);
  static const Color redBd   = Color(0xFFFECACA);

  static const Color orange  = Color(0xFFF59E0B);
  static const Color orangeL = Color(0xFFFEF9C3);
  static const Color orangeBd= Color(0xFFFDE68A);

  static const Color purple  = Color(0xFF3B82F6);
  static const Color purpleL = Color(0xFFDBEAFE);

  static const Color teal    = Color(0xFF0BA5EC);
  static const Color dark    = Color(0xFF1A1A2E);
}

/// Dark mode colors
class CD {
  static const Color pri     = Color(0xFF4B8BF5);
  static const Color priDark = Color(0xFF3A6FD8);
  static const Color priLight= Color(0xFF1E2D4A);
  static const Color priBg   = Color(0xFF1A2744);

  static const Color bg      = Color(0xFF121212);
  static const Color white   = Color(0xFF1E1E1E);
  static const Color card    = Color(0xFF1E1E1E);

  static const Color text    = Color(0xFFE0E0E0);
  static const Color sub     = Color(0xFF9E9E9E);
  static const Color muted   = Color(0xFF757575);
  static const Color hint    = Color(0xFF616161);

  static const Color border  = Color(0xFF333333);
  static const Color div     = Color(0xFF2A2A2A);

  static const Color green   = Color(0xFF4CAF50);
  static const Color greenL  = Color(0xFF1B3A1B);
  static const Color greenBd = Color(0xFF2E7D32);

  static const Color red     = Color(0xFFEF5350);
  static const Color redL    = Color(0xFF3A1B1B);
  static const Color redBd   = Color(0xFFC62828);

  static const Color orange  = Color(0xFFFFB74D);
  static const Color orangeL = Color(0xFF3A2E1B);
  static const Color orangeBd= Color(0xFFF57F17);

  static const Color purple  = Color(0xFFB39DDB);
  static const Color purpleL = Color(0xFF2A1F3A);

  static const Color teal    = Color(0xFF4FC3F7);
  static const Color dark    = Color(0xFFE0E0E0);
}

/// Adaptive colors: web=pharmacy, mobile=original
class W {
  static Color get pri      => kIsWeb ? AC.pri      : C.pri;
  static Color get priDark  => kIsWeb ? AC.priDark  : C.priDark;
  static Color get priLight => kIsWeb ? AC.priLight : C.priLight;
  static Color get priBg    => kIsWeb ? AC.priBg    : C.priBg;
  static Color get bg       => kIsWeb ? AC.bg       : C.bg;
  static Color get white    => AC.white;
  static Color get card     => AC.card;
  static Color get text     => kIsWeb ? AC.text     : C.text;
  static Color get sub      => kIsWeb ? AC.sub      : C.sub;
  static Color get muted    => kIsWeb ? AC.muted    : C.muted;
  static Color get hint     => kIsWeb ? AC.hint     : C.hint;
  static Color get border   => kIsWeb ? AC.border   : C.border;
  static Color get div      => kIsWeb ? AC.div      : C.div;
  static Color get green    => kIsWeb ? AC.green    : C.green;
  static Color get greenL   => kIsWeb ? AC.greenL   : C.greenL;
  static Color get greenBd  => kIsWeb ? AC.greenBd  : C.greenBd;
  static Color get red      => kIsWeb ? AC.red      : C.red;
  static Color get redL     => kIsWeb ? AC.redL     : C.redL;
  static Color get redBd    => kIsWeb ? AC.redBd    : C.redBd;
  static Color get orange   => kIsWeb ? AC.orange   : C.orange;
  static Color get orangeL  => kIsWeb ? AC.orangeL  : C.orangeL;
  static Color get orangeBd => kIsWeb ? AC.orangeBd : C.orangeBd;
  static Color get purple   => kIsWeb ? AC.purple   : C.purple;
  static Color get purpleL  => kIsWeb ? AC.purpleL  : C.purpleL;
  static Color get teal     => AC.teal;
  static Color get dark     => kIsWeb ? AC.dark     : C.dark;
}

/// Design system constants for premium UI
class DS {
  // Border radius
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusPill = 100;

  // Shadows
  static List<BoxShadow> get shadowSm => [
    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
  ];
  static List<BoxShadow> get shadowMd => [
    BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
  ];
  static List<BoxShadow> get shadowLg => [
    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8)),
  ];

  // Card decoration — classic style with border
  static BoxDecoration cardDecoration({Color? color, double radius = radiusMd, Color? borderColor}) => BoxDecoration(
    color: color ?? Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor ?? const Color(0xFFE5E7EB)),
  );

  // Gradient card for stat cards — classic with border
  static BoxDecoration gradientCard(Color accent, {double radius = radiusMd}) => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0xFFE5E7EB)),
  );
}
