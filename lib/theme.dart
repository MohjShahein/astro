import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// سمة التطبيق الرئيسية
class AppTheme {
  // ألوان السمة الرئيسية
  static const Color primaryColor = Color(0xFFF2C792); // بنفسجي داكن
  static const Color primaryVariantColor = Color(0xFFFCEEB6); // بنفسجي متوسط
  static const Color secondaryColor = Color(0xFF191923); // برتقالي
  static const Color secondaryVariantColor = Color(0xFF28263D); // برتقالي فاتح
  static const Color accentColor = Color(0xFF00BCD4); // أزرق فيروزي
  static const Color backgroundColor = Color(0xFF191923); // أسود غامق كوني
  static const Color surfaceColor = Color(0xFF191923); // رمادي داكن
  static const Color errorColor = Color(0xFFCF6679); // أحمر وردي

  // ألوان الخلفية الجديدة المتدرجة
  static const Color gradientTop = Color(0xFF28263D); // تدرج أفتح قليلاً
  static const Color gradientMiddle1 = Color(0xFF191923); // اللون الأساسي
  static const Color gradientMiddle2 = Color(0xFF16161F); // تدرج أغمق قليلاً
  static const Color gradientBottom = Color(0xFF13131A); // تدرج أغمق

  // ألوان الأبراج
  static const Map<String, Color> zodiacColors = {
    'aries': Color(0xFFE53935), // الحمل - أحمر
    'taurus': Color(0xFF43A047), // الثور - أخضر
    'gemini': Color(0xFFFFD54F), // الجوزاء - أصفر
    'cancer': Color(0xFF78909C), // السرطان - رمادي مزرق
    'leo': Color(0xFFFF9800), // الأسد - برتقالي
    'virgo': Color(0xFF8D6E63), // العذراء - بني
    'libra': Color(0xFF26C6DA), // الميزان - أزرق فيروزي
    'scorpio': Color(0xFF7B1FA2), // العقرب - بنفسجي
    'sagittarius': Color(0xFF5E35B1), // القوس - بنفسجي مزرق
    'capricorn': Color(0xFF455A64), // الجدي - رمادي داكن
    'aquarius': Color(0xFF1E88E5), // الدلو - أزرق
    'pisces': Color(0xFF26A69A), // الحوت - أخضر مزرق
  };

  /// دالة مساعدة للحصول على نمط نص باستخدام خط عربي
  static TextStyle arabicStyle({
    Color? color,
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w500,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    Color? backgroundColor,
    Paint? foreground,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
  }) {
    return GoogleFonts.tajawal(
      color: color ?? Colors.white,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      backgroundColor: backgroundColor,
      shadows: shadows,
      fontFeatures: fontFeatures,
    );
  }

  /// الخلفية المتدرجة للتطبيق
  static BoxDecoration get pageBackground => const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            gradientTop,
            gradientMiddle1,
            gradientMiddle2,
            gradientBottom
          ],
          stops: [0.0, 0.3, 0.6, 1.0],
        ),
      );

  /// الحصول على السمة الرئيسية للتطبيق
  static ThemeData getTheme() {
    return ThemeData(
      useMaterial3: true,
      // استخدام TextTheme مع خط Tajawal
      textTheme: TextTheme(
        bodyLarge: GoogleFonts.tajawal(
            color: Colors.white, fontWeight: FontWeight.w500),
        bodyMedium: GoogleFonts.tajawal(
            color: Colors.white, fontWeight: FontWeight.w500),
        bodySmall: GoogleFonts.tajawal(
            color: Colors.white, fontWeight: FontWeight.w500),
      ),
      colorScheme: _getColorScheme(),
      appBarTheme: _getAppBarTheme(),
      cardTheme: _getCardTheme(),
      elevatedButtonTheme: _getElevatedButtonTheme(),
      outlinedButtonTheme: _getOutlinedButtonTheme(),
      textButtonTheme: _getTextButtonTheme(),
      inputDecorationTheme: _getInputDecorationTheme(),
      tabBarTheme: _getTabBarTheme(),
      bottomNavigationBarTheme: _getBottomNavigationBarTheme(),
      dialogTheme: _getDialogTheme(),
      snackBarTheme: _getSnackBarTheme(),
      chipTheme: _getChipTheme(),
      switchTheme: _getSwitchTheme(),
      radioTheme: _getRadioTheme(),
      checkboxTheme: _getCheckboxTheme(),
      dividerTheme: _getDividerTheme(),
      listTileTheme: _getListTileTheme(),
      iconTheme: _getIconTheme(),
      scaffoldBackgroundColor: Colors.transparent,
    );
  }

  /// مخطط الألوان الرئيسي
  static ColorScheme _getColorScheme() {
    return const ColorScheme(
      primary: primaryColor,
      primaryContainer: primaryVariantColor,
      secondary: secondaryColor,
      secondaryContainer: secondaryVariantColor,
      surface: surfaceColor, // استخدام اللون العلوي من التدرج
      error: errorColor,
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: Colors.white,
      onError: Colors.white,
      brightness: Brightness.dark,
    );
  }

  /// سمة النصوص
  static TextTheme _getTextTheme() {
    const baseTextColor = Colors.white;

    return TextTheme(
      displayLarge: GoogleFonts.tajawal(
        color: baseTextColor,
        fontSize: 57,
        fontWeight: FontWeight.w400,
      ),
      displayMedium: GoogleFonts.tajawal(
        color: baseTextColor,
        fontSize: 45,
        fontWeight: FontWeight.w400,
      ),
      displaySmall: GoogleFonts.tajawal(
        color: baseTextColor,
        fontSize: 36,
        fontWeight: FontWeight.w500,
      ),
      headlineLarge: GoogleFonts.tajawal(
        color: baseTextColor,
        fontSize: 32,
        fontWeight: FontWeight.w500,
      ),
      headlineMedium: GoogleFonts.tajawal(
        color: baseTextColor,
        fontSize: 28,
        fontWeight: FontWeight.w500,
      ),
      headlineSmall: GoogleFonts.tajawal(
        color: baseTextColor,
        fontSize: 24,
        fontWeight: FontWeight.w500,
      ),
      titleLarge: GoogleFonts.tajawal(
        color: baseTextColor,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.tajawal(
        color: baseTextColor,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: GoogleFonts.tajawal(
        color: baseTextColor,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.tajawal(
        color: baseTextColor,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: GoogleFonts.tajawal(
        color: baseTextColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: GoogleFonts.tajawal(
        color: baseTextColor,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: GoogleFonts.tajawal(
        color: baseTextColor,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: GoogleFonts.tajawal(
        color: baseTextColor,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: GoogleFonts.tajawal(
        color: baseTextColor,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// سمة شريط التطبيق
  static AppBarTheme _getAppBarTheme() {
    return AppBarTheme(
      backgroundColor:
          Colors.transparent, // لجعل شريط التطبيق شفافاً ليظهر التدرج
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: GoogleFonts.tajawal(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// سمة البطاقات
  static CardTheme _getCardTheme() {
    return CardTheme(
      color: surfaceColor,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
    );
  }

  /// سمة الأزرار المرتفعة
  static ElevatedButtonThemeData _getElevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(const Color(0xFF21202F)),
        foregroundColor: WidgetStateProperty.all(Colors.white),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        ),
        shape: WidgetStateProperty.all(
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            side: BorderSide(color: Color(0xFFF2C792), width: 1.5),
          ),
        ),
        elevation: WidgetStateProperty.all(0),
        textStyle: WidgetStateProperty.all(
          GoogleFonts.tajawal(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        overlayColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.pressed)) {
            return const Color(0xFF21202F).withOpacity(0.8);
          }
          return const Color(0xFF21202F);
        }),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  /// زخرفة زر مع حد سفلي فقط
  static BoxDecoration get buttonWithBottomBorder => BoxDecoration(
        color: const Color(0xFF21202F),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: const Color(0xFFF2C792), width: 1.5),
      );

  /// سمة الأزرار المحاطة
  static OutlinedButtonThemeData _getOutlinedButtonTheme() {
    return OutlinedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(Colors.transparent),
        foregroundColor: WidgetStateProperty.all(Colors.white),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(
              color: Color(0xFFF2C792),
              width: 1.5,
              style: BorderStyle.solid,
            ),
          ),
        ),
        textStyle: WidgetStateProperty.all(
          GoogleFonts.tajawal(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        overlayColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.pressed)) {
            return const Color(0xFF21202F).withOpacity(0.2);
          }
          return Colors.transparent;
        }),
      ),
    );
  }

  /// سمة أزرار النص
  static TextButtonThemeData _getTextButtonTheme() {
    return TextButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(Colors.transparent),
        foregroundColor: WidgetStateProperty.all(const Color(0xFFF2C792)),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Colors.transparent, width: 0),
          ),
        ),
        textStyle: WidgetStateProperty.all(
          GoogleFonts.tajawal(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        overlayColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.pressed)) {
            return const Color(0xFFF2C792).withOpacity(0.1);
          }
          return Colors.transparent;
        }),
      ),
    );
  }

  /// سمة حقول الإدخال
  static InputDecorationTheme _getInputDecorationTheme() {
    return InputDecorationTheme(
      filled: true,
      fillColor: surfaceColor,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor.withOpacity(0.3), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorColor, width: 1),
      ),
      labelStyle: GoogleFonts.tajawal(
        color: Colors.white.withOpacity(0.7),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: GoogleFonts.tajawal(
        color: Colors.white.withOpacity(0.5),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  /// سمة شريط التبويب
  static TabBarTheme _getTabBarTheme() {
    return TabBarTheme(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white60,
      indicatorColor: secondaryColor,
      labelStyle: GoogleFonts.tajawal(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: GoogleFonts.tajawal(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  /// سمة شريط التنقل السفلي
  static BottomNavigationBarThemeData _getBottomNavigationBarTheme() {
    return BottomNavigationBarThemeData(
      backgroundColor: surfaceColor,
      selectedItemColor: secondaryColor,
      unselectedItemColor: Colors.white60,
      selectedLabelStyle: GoogleFonts.tajawal(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: GoogleFonts.tajawal(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    );
  }

  /// سمة نافذة الحوار
  static DialogTheme _getDialogTheme() {
    return DialogTheme(
      backgroundColor: surfaceColor,
      elevation: 16,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: GoogleFonts.tajawal(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: GoogleFonts.tajawal(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  /// سمة شريط الإشعارات
  static SnackBarThemeData _getSnackBarTheme() {
    return SnackBarThemeData(
      backgroundColor: surfaceColor,
      contentTextStyle: GoogleFonts.tajawal(
        color: Colors.white,
        fontSize: 16,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  /// سمة شرائح الاختيار
  static ChipThemeData _getChipTheme() {
    return ChipThemeData(
      backgroundColor: surfaceColor,
      selectedColor: primaryColor,
      disabledColor: surfaceColor.withOpacity(0.5),
      labelStyle: GoogleFonts.tajawal(
        color: Colors.white,
        fontSize: 14,
      ),
      secondaryLabelStyle: GoogleFonts.tajawal(
        color: Colors.white,
        fontSize: 14,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
  }

  /// سمة مفتاح التبديل
  static SwitchThemeData _getSwitchTheme() {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return secondaryColor;
        }
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return secondaryColor.withOpacity(0.5);
        }
        return Colors.white30;
      }),
    );
  }

  /// سمة زر الراديو
  static RadioThemeData _getRadioTheme() {
    return RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return secondaryColor;
        }
        return Colors.white;
      }),
    );
  }

  /// سمة مربع الاختيار
  static CheckboxThemeData _getCheckboxTheme() {
    return CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return secondaryColor;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.black),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: const BorderSide(color: Colors.white, width: 1.5),
    );
  }

  /// سمة الخط الفاصل
  static DividerThemeData _getDividerTheme() {
    return const DividerThemeData(
      color: Colors.white30,
      thickness: 1,
      space: 16,
    );
  }

  /// سمة عنصر القائمة
  static ListTileThemeData _getListTileTheme() {
    return const ListTileThemeData(
      textColor: Colors.white,
      iconColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    );
  }

  /// سمة الأيقونات
  static IconThemeData _getIconTheme() {
    return const IconThemeData(color: Colors.white, size: 24);
  }

  /// ألوان التدرج للسمة
  static LinearGradient get primaryGradient => const LinearGradient(
        colors: [primaryColor, primaryVariantColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get mysticalGradient => const LinearGradient(
        colors: [
          Color(0xFF2C3E50), // أزرق داكن
          Color(0xFF4A148C), // بنفسجي داكن
          Color(0xFF311B92), // بنفسجي غامق
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  static LinearGradient get cosmicGradient => const LinearGradient(
        colors: [
          gradientTop, // بنفسجي غامق
          gradientMiddle1, // أسود مائل للأزرق
          gradientMiddle2, // أسود مائل للبنفسجي
          gradientBottom, // أسود
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  /// الحصول على لون برج معين
  static Color getZodiacColor(String zodiacSign) {
    return zodiacColors[zodiacSign.toLowerCase()] ?? primaryColor;
  }

  /// زخارف وتأثيرات
  static BoxDecoration get mysticalCardDecoration => BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF311B92)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      );

  static BoxDecoration get zodiacCardDecoration => BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      );
}
