import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// The Log — design system.
/// Strava athletic clarity × Mid-Century-Modern / Japandi warmth.
class AppColors {
  // Core
  static const bone = Color(0xFFECE7DD); // warm bone background
  static const boneDeep = Color(0xFFE3DCCF); // slightly deeper bone for cards/insets
  static const ink = Color(0xFF1E211C); // primary text
  static const sageGrey = Color(0xFF8A9080); // muted secondary text
  static const clay = Color(0xFFC56A3A); // primary energetic accent (burnt clay)
  static const forest = Color(0xFF2E382B); // deep forest for dark/headers

  // Macro semantic
  static const amber = Color(0xFFD9A648); // carbs
  static const rose = Color(0xFFB96A6A); // fat / warnings
  static const teal = Color(0xFF6E9B92); // fiber
  static const sage = Color(0xFF8FA079); // "good / hit" states

  // Surfaces
  static const card = Color(0xFFF4F0E8); // soft raised card on bone
  static const hairline = Color(0x1A1E211C); // 10% ink hairline dividers
  static const onForest = Color(0xFFECE7DD);

  /// Resolve a palette name (used by A2UI props) to a color.
  static Color named(String? name, {Color fallback = clay}) {
    switch (name) {
      case 'clay':
        return clay;
      case 'amber':
        return amber;
      case 'rose':
        return rose;
      case 'teal':
        return teal;
      case 'sage':
        return sage;
      case 'ink':
        return ink;
      case 'forest':
        return forest;
      default:
        return fallback;
    }
  }
}

class AppRadius {
  static const card = 20.0;
  static const chip = 14.0;
  static const pill = 999.0;
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

class AppType {
  // Bricolage Grotesque for display / big numbers / headers.
  static TextStyle display(double size, {FontWeight weight = FontWeight.w800, Color? color, double? height, double? letterSpacing}) {
    return GoogleFonts.bricolageGrotesque(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.ink,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // Inter for body / UI.
  static TextStyle body(double size, {FontWeight weight = FontWeight.w400, Color? color, double? height, double? letterSpacing}) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.ink,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle label(Color? color) => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: color ?? AppColors.sageGrey,
      );
}

class AppTheme {
  static ThemeData build() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bone,
      colorScheme: const ColorScheme.light(
        primary: AppColors.clay,
        onPrimary: AppColors.bone,
        secondary: AppColors.forest,
        onSecondary: AppColors.bone,
        surface: AppColors.bone,
        onSurface: AppColors.ink,
        error: AppColors.rose,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      dividerColor: AppColors.hairline,
      splashColor: AppColors.clay.withValues(alpha: 0.08),
      highlightColor: AppColors.clay.withValues(alpha: 0.04),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bone,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bone,
        selectedItemColor: AppColors.clay,
        unselectedItemColor: AppColors.sageGrey,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}

/// Soft, tactile MCM card.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.color = AppColors.card,
    this.radius = AppRadius.card,
    this.onTap,
    this.border,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final double radius;
  final VoidCallback? onTap;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap!();
        },
        child: content,
      ),
    );
  }
}

/// Honors the platform reduce-motion accessibility flag.
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;
