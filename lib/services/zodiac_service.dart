import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import '../services/open_router_service.dart';

class ZodiacService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ترجمة اسم البرج من الإنجليزية إلى العربية
  static String getArabicZodiacName(String englishName) {
    switch (englishName.toLowerCase()) {
      case 'aries':
        return 'الحمل';
      case 'taurus':
        return 'الثور';
      case 'gemini':
        return 'الجوزاء';
      case 'cancer':
        return 'السرطان';
      case 'leo':
        return 'الأسد';
      case 'virgo':
        return 'العذراء';
      case 'libra':
        return 'الميزان';
      case 'scorpio':
        return 'العقرب';
      case 'sagittarius':
        return 'القوس';
      case 'capricorn':
        return 'الجدي';
      case 'aquarius':
        return 'الدلو';
      case 'pisces':
        return 'الحوت';
      default:
        return 'غير معروف';
    }
  }

  /// Determines zodiac sign based on birth date
  static String getZodiacSign(DateTime birthDate) {
    int day = birthDate.day;
    int month = birthDate.month;

    if ((month == 3 && day >= 21) || (month == 4 && day <= 19)) {
      return 'aries';
    } else if ((month == 4 && day >= 20) || (month == 5 && day <= 20)) {
      return 'taurus';
    } else if ((month == 5 && day >= 21) || (month == 6 && day <= 20)) {
      return 'gemini';
    } else if ((month == 6 && day >= 21) || (month == 7 && day <= 22)) {
      return 'cancer';
    } else if ((month == 7 && day >= 23) || (month == 8 && day <= 22)) {
      return 'leo';
    } else if ((month == 8 && day >= 23) || (month == 9 && day <= 22)) {
      return 'virgo';
    } else if ((month == 9 && day >= 23) || (month == 10 && day <= 22)) {
      return 'libra';
    } else if ((month == 10 && day >= 23) || (month == 11 && day <= 21)) {
      return 'scorpio';
    } else if ((month == 11 && day >= 22) || (month == 12 && day <= 21)) {
      return 'sagittarius';
    } else if ((month == 12 && day >= 22) || (month == 1 && day <= 19)) {
      return 'capricorn';
    } else if ((month == 1 && day >= 20) || (month == 2 && day <= 18)) {
      return 'aquarius';
    } else {
      return 'pisces';
    }
  }

  /// Saves user's zodiac sign information to Firestore
  static Future<void> saveUserZodiac(String userId, DateTime birthDate) async {
    String zodiacSign = getZodiacSign(birthDate);

    await _firestore.collection('users').doc(userId).set({
      'birth_date': birthDate.toIso8601String(),
      'zodiac_sign': zodiacSign,
    }, SetOptions(merge: true));
  }

  /// Retrieves user's daily zodiac reading
  static Future<Map<String, dynamic>> getUserZodiacReading(
    String userId,
  ) async {
    try {
      // تسجيل بداية العملية للتشخيص
      print('بدء استرجاع قراءة البرج للمستخدم: $userId');

      // الحصول على برج المستخدم
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final zodiacSign = userDoc.data()?['zodiac_sign'] ?? 'aries';
      print('برج المستخدم: $zodiacSign');

      // الحصول على قراءة البرج مباشرة بدون استخدام subcollection
      try {
        print('محاولة استرجاع قراءة البرج من zodiac_readings/$zodiacSign');
        final doc = await _firestore
            .collection('zodiac_readings')
            .doc(zodiacSign)
            .get();

        if (doc.exists) {
          print('تم العثور على قراءة البرج: ${doc.data()}');
          final data = doc.data() ?? {};

          // إذا كان الحقل daily_reading موجودًا ولكن حقل reading غير موجود
          // فسنضيف حقل reading ليكون نسخة من daily_reading
          if (data.containsKey('daily_reading') &&
              !data.containsKey('reading')) {
            data['reading'] = data['daily_reading'];
            print('تم إضافة حقل reading من daily_reading للتوافق');
          }

          return data;
        } else {
          print('لم يتم العثور على قراءة للبرج: $zodiacSign');
          // استخدم برج الحمل كقيمة افتراضية إذا لم يتم العثور على قراءة
          final defaultDoc =
              await _firestore.collection('zodiac_readings').doc('aries').get();
          final defaultData = defaultDoc.data() ?? {};

          // نضيف حقل reading للبيانات الافتراضية أيضًا إذا لم يكن موجودًا
          if (defaultData.containsKey('daily_reading') &&
              !defaultData.containsKey('reading')) {
            defaultData['reading'] = defaultData['daily_reading'];
          }

          return defaultData;
        }
      } catch (readingError) {
        print('خطأ أثناء استرجاع قراءة البرج: $readingError');
        // إرجاع بيانات افتراضية في حالة الخطأ
        return {
          'daily_reading': 'غير متاح حاليًا. يرجى المحاولة لاحقًا.',
          'reading':
              'غير متاح حاليًا. يرجى المحاولة لاحقًا.', // إضافة حقل reading
          'updated_at': Timestamp.now(),
        };
      }
    } catch (e) {
      print('Error fetching zodiac reading: $e');
      return {
        'reading': 'حدث خطأ في استرجاع القراءة',
        'daily_reading': 'حدث خطأ في استرجاع القراءة'
      };
    }
  }

  /// Updates the daily reading for a specific zodiac sign
  /// Only admin users can update readings
  static Future<String> updateZodiacReading(
    String zodiacSign,
    String dailyReading,
  ) async {
    try {
      // تحقق من حالة المصادقة
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return 'يرجى تسجيل الدخول لتحديث القراءة اليومية';
      }

      // تحقق من صلاحيات المستخدم الإداري
      bool isAdmin = await AuthService.isCurrentUserAdmin();
      if (!isAdmin) {
        return 'ليس لديك صلاحية لتحديث القراءات اليومية';
      }

      // التحقق من صحة اسم البرج
      if (![
        'aries',
        'taurus',
        'gemini',
        'cancer',
        'leo',
        'virgo',
        'libra',
        'scorpio',
        'sagittarius',
        'capricorn',
        'aquarius',
        'pisces',
      ].contains(zodiacSign)) {
        return 'اسم البرج غير صحيح';
      }

      // تحديث القراءة اليومية مع حفظها في كلا الحقلين reading و daily_reading
      await _firestore.collection('zodiac_readings').doc(zodiacSign).set({
        'daily_reading': dailyReading,
        'reading': dailyReading, // إضافة حقل reading للتوافق مع واجهة المستخدم
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': currentUser.uid,
      }, SetOptions(merge: true));

      print('تم تحديث قراءة البرج $zodiacSign بنجاح مع إضافة حقل reading');
      return 'تم تحديث القراءة اليومية بنجاح';
    } catch (e) {
      return 'حدث خطأ أثناء تحديث القراءة اليومية: ${e.toString()}';
    }
  }

  /// يقوم بإنشاء قراءة يومية جديدة لبرج محدد باستخدام الذكاء الاصطناعي
  /// ثم يقوم بتحديثها في قاعدة البيانات
  /// فقط المشرفين يمكنهم استخدام هذه الدالة
  static Future<String> generateAndUpdateZodiacReading(
    String zodiacSign,
    String apiKey,
  ) async {
    try {
      // تحقق من حالة المصادقة
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return 'يرجى تسجيل الدخول لتحديث القراءة اليومية';
      }

      // تحقق من صلاحيات المستخدم الإداري
      bool isAdmin = await AuthService.isCurrentUserAdmin();
      if (!isAdmin) {
        return 'ليس لديك صلاحية لتحديث القراءات اليومية';
      }

      // التحقق من صحة اسم البرج
      if (![
        'aries',
        'taurus',
        'gemini',
        'cancer',
        'leo',
        'virgo',
        'libra',
        'scorpio',
        'sagittarius',
        'capricorn',
        'aquarius',
        'pisces',
      ].contains(zodiacSign)) {
        return 'اسم البرج غير صحيح';
      }

      // الحصول على اسم البرج بالعربية
      String arabicZodiacName = getArabicZodiacName(zodiacSign);

      // استخدام OpenRouter API لإنشاء قراءة باستخدام الذكاء الاصطناعي
      String generatedReading = await OpenRouterService.generateZodiacReading(
        zodiacSign: zodiacSign,
        arabicZodiacName: arabicZodiacName,
        apiKey: apiKey,
      );

      // التحقق مما إذا كانت هناك أخطاء في استجابة AI
      if (generatedReading.contains('خطأ:') || generatedReading.contains('حدث خطأ')) {
        return generatedReading; // إرجاع رسالة الخطأ
      }

      // تحديث القراءة اليومية في قاعدة البيانات
      await _firestore.collection('zodiac_readings').doc(zodiacSign).set({
        'daily_reading': generatedReading,
        'reading': generatedReading, // إضافة حقل reading للتوافق مع واجهة المستخدم
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': currentUser.uid,
        'generated_by_ai': true, // إضافة علامة لتوضيح أن القراءة تم إنشاؤها بواسطة الذكاء الاصطناعي
      }, SetOptions(merge: true));

      return 'تم إنشاء وتحديث القراءة اليومية لبرج $arabicZodiacName بنجاح باستخدام الذكاء الاصطناعي';
    } catch (e) {
      return 'حدث خطأ أثناء توليد وتحديث القراءة اليومية: ${e.toString()}';
    }
  }

  /// Gets all zodiac signs
  static List<String> getAllZodiacSigns() {
    return [
      'aries',
      'taurus',
      'gemini',
      'cancer',
      'leo',
      'virgo',
      'libra',
      'scorpio',
      'sagittarius',
      'capricorn',
      'aquarius',
      'pisces',
    ];
  }

  /// Retrieves the daily reading for a specific zodiac sign without requiring user authentication
  static Future<String> getZodiacReading(String zodiacSign) async {
    try {
      // التحقق من صحة اسم البرج
      if (!getAllZodiacSigns().contains(zodiacSign)) {
        return 'اسم البرج غير صحيح';
      }

      print('محاولة الحصول على قراءة البرج: $zodiacSign');

      DocumentSnapshot zodiacSnapshot =
          await _firestore.collection('zodiac_readings').doc(zodiacSign).get();

      if (!zodiacSnapshot.exists) {
        print('لم يتم العثور على قراءة للبرج: $zodiacSign');
        return 'لا توجد قراءة يومية متاحة لهذا البرج';
      }

      Map<String, dynamic> zodiacData =
          zodiacSnapshot.data() as Map<String, dynamic>;
      print('تم الحصول على قراءة البرج: ${zodiacData['daily_reading']}');
      return zodiacData['daily_reading'] ?? 'لا توجد قراءة متاحة';
    } catch (e) {
      print('حدث خطأ أثناء استرجاع القراءة اليومية: $e');
      return 'حدث خطأ أثناء استرجاع القراءة اليومية: ${e.toString()}';
    }
  }
}
