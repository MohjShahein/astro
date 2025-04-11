import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

class OpenRouterService {
  static const String _baseUrl =
      'https://openrouter.ai/api/v1/chat/completions';

  // مفتاح API - سيتم تخزينه بشكل آمن في الإنتاج
  // يُفضل استخدام متغيرات بيئية أو خدمات إدارة الأسرار في الإنتاج
  static String? _apiKey;

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _settingsCollection = 'app_settings';
  static const String _apiKeyDoc = 'api_keys';

  // تعيين مفتاح API محلياً
  static void setApiKey(String apiKey) {
    _apiKey = apiKey;
  }

  // الحصول على مفتاح API المخزن محلياً
  static String? getApiKey() {
    return _apiKey;
  }

  // حفظ مفتاح API في قاعدة البيانات Firestore
  static Future<bool> saveApiKeyToDatabase(String apiKey) async {
    try {
      // التحقق من صلاحيات المستخدم الإداري
      bool isAdmin = await AuthService.isCurrentUserAdmin();
      if (!isAdmin) {
        if (kDebugMode) {
          print('فشل حفظ المفتاح: المستخدم ليس لديه صلاحيات إدارية');
        }
        return false;
      }

      // حفظ المفتاح في قاعدة البيانات
      await _firestore.collection(_settingsCollection).doc(_apiKeyDoc).set({
        'openrouter_api_key': apiKey,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // تحديث القيمة المحلية أيضاً
      _apiKey = apiKey;

      if (kDebugMode) {
        print('تم حفظ مفتاح API في قاعدة البيانات بنجاح');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('خطأ أثناء حفظ مفتاح API: $e');
      }
      return false;
    }
  }

  // استرجاع مفتاح API من قاعدة البيانات Firestore
  static Future<String?> loadApiKeyFromDatabase() async {
    try {
      // التحقق من صلاحيات المستخدم الإداري
      bool isAdmin = await AuthService.isCurrentUserAdmin();
      if (!isAdmin) {
        if (kDebugMode) {
          print('فشل استرجاع المفتاح: المستخدم ليس لديه صلاحيات إدارية');
        }
        return null;
      }

      final docSnapshot = await _firestore
          .collection(_settingsCollection)
          .doc(_apiKeyDoc)
          .get();

      if (docSnapshot.exists &&
          docSnapshot.data()!.containsKey('openrouter_api_key')) {
        final apiKey = docSnapshot.data()!['openrouter_api_key'] as String;

        // تحديث القيمة المحلية
        _apiKey = apiKey;

        if (kDebugMode) {
          print('تم استرجاع مفتاح API من قاعدة البيانات بنجاح');
        }

        return apiKey;
      } else {
        if (kDebugMode) {
          print('لم يتم العثور على مفتاح API في قاعدة البيانات');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('خطأ أثناء استرجاع مفتاح API: $e');
      }
      return null;
    }
  }

  // دالة لإنشاء قراءة برج يومية باستخدام الذكاء الاصطناعي
  static Future<String> generateZodiacReading({
    required String zodiacSign,
    required String arabicZodiacName,
    String? apiKey,
  }) async {
    try {
      // التحقق من وجود مفتاح API
      String? key = apiKey;

      // إذا لم يتم تمرير مفتاح، نحاول الحصول عليه من الذاكرة المحلية
      if (key == null || key.isEmpty) {
        key = _apiKey;
      }

      // إذا لم يكن متوفراً في الذاكرة المحلية، نحاول الحصول عليه من قاعدة البيانات
      if (key == null || key.isEmpty) {
        key = await loadApiKeyFromDatabase();
      }

      // إذا لم نتمكن من الحصول على المفتاح، نرجع رسالة خطأ
      if (key == null || key.isEmpty) {
        return 'خطأ: لم يتم تعيين مفتاح API، يرجى تعيين مفتاح API أولاً';
      }

      // إعداد الهيدرز - إصلاح مشكلة الهيدر
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
        'HTTP-Referer': 'https://astrology-app.com', // استبدلها بموقع تطبيقك
        'X-Title':
            'Astrology App', // تغيير النص العربي إلى الإنجليزية لتجنب مشاكل الترميز
      };

      if (kDebugMode) {
        print('إعداد الهيدرز: $headers');
      }

      // إعداد محتوى الطلب - استخدام النموذج المجاني
      final body = jsonEncode({
        'model':
            'meta-llama/llama-4-maverick:free', // استخدام النموذج المجاني بدلاً من claude
        'messages': [
          {
            'role': 'user',
            'content': '''
            أنت خبير في علم التنجيم والأبراج. أريد منك كتابة قراءة يومية شاملة وإيجابية لبرج "$arabicZodiacName" (باللغة الإنجليزية: $zodiacSign).
            
            يجب أن تشمل القراءة:
            1. نظرة عامة إيجابية عن اليوم
            2. جانب العلاقات الشخصية والحب
            3. جانب العمل والمهنة
            4. جانب الصحة والعافية
            5. نصيحة روحانية أو إلهام
            
            اكتب القراءة باللغة العربية بأسلوب سلس وجذاب، وحافظ على طول معتدل (150-200 كلمة). لا تضع عناوين فرعية، بل اكتب فقرات متماسكة وسلسة. اجعل القراءة إيجابية ومُحفِّزة مع إضافة لمسة من التفاؤل والأمل، حتى عند الإشارة إلى التحديات المحتملة.
            '''
          }
        ],
        'max_tokens': 400, // تقليل العدد أكثر لتناسب الاعتمادات المتاحة
        'temperature': 0.7,
      });

      if (kDebugMode) {
        print('إرسال طلب لـ OpenRouter API باستخدام النموذج المجاني...');
        print('النموذج المستخدم: meta-llama/llama-4-maverick:free');
      }

      // إرسال الطلب
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: headers,
        body: body,
      );

      // تحويل الرد إلى كائن JSON
      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (kDebugMode) {
        print('الاستجابة الكاملة: ${response.body}');
      }

      // معالجة الاستجابة مع التحقق من وجود خطأ
      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('تم استلام رد من OpenRouter API بنجاح');
        }

        // التحقق من وجود حقل choices في الاستجابة
        if (responseData.containsKey('choices') &&
            responseData['choices'] is List &&
            responseData['choices'].isNotEmpty) {
          final message = responseData['choices'][0]['message'];
          String content = message['content'];

          // معالجة ترميز النص العربي
          if (kDebugMode) {
            print('النص الأصلي المستلم من API: $content');
          }

          // تنظيف النص من أي رموز Unicode غير صالحة
          content = _cleanArabicText(content,
              zodiacSign: zodiacSign, arabicZodiacName: arabicZodiacName);

          if (kDebugMode) {
            print('النص بعد المعالجة: $content');
          }

          return content;
        } else {
          if (kDebugMode) {
            print('هيكل استجابة غير متوقع: ${response.body}');
          }
          return 'تم تلقي استجابة من الخدمة ولكن بتنسيق غير متوقع. يرجى المحاولة مرة أخرى.';
        }
      } else {
        // التعامل مع أخطاء API
        String errorMessage = 'حدث خطأ أثناء توليد القراءة';

        if (responseData.containsKey('error') && responseData['error'] is Map) {
          final errorData = responseData['error'];

          if (errorData.containsKey('message')) {
            errorMessage = errorData['message'];
          }

          if (errorData.containsKey('code') && errorData['code'] == 402) {
            errorMessage =
                'رصيد غير كافٍ في حساب OpenRouter. يرجى ترقية الحساب أو محاولة استخدام نموذج أقل تكلفة.';
          }
        }

        if (kDebugMode) {
          print('خطأ في OpenRouter API: ${response.statusCode}');
          print('رسالة الخطأ: $errorMessage');
        }

        return 'حدث خطأ أثناء توليد القراءة: $errorMessage';
      }
    } catch (e) {
      if (kDebugMode) {
        print('استثناء في OpenRouter API: $e');
      }

      return 'حدث خطأ أثناء الاتصال بخدمة الذكاء الاصطناعي: $e';
    }
  }

  // دالة لتنظيف النص العربي من أي رموز غير صالحة
  static String _cleanArabicText(String text,
      {required String zodiacSign, required String arabicZodiacName}) {
    try {
      // إزالة أي رموز غير مرئية قد تكون موجودة في بداية النص
      text = text.trim();

      // في حالة استمرار المشكلة، يمكننا إجراء إعادة ترميز للنص
      List<int> bytes = utf8.encode(text);
      String decodedText = utf8.decode(bytes, allowMalformed: true);

      // التأكد من أن النص يظهر بشكل صحيح (بدون أحرف غريبة)
      if (decodedText.contains('') ||
          decodedText.contains('Ù') ||
          decodedText.contains('Ø')) {
        // إذا كان هناك خلل في الترميز، حاول طريقة بديلة
        if (kDebugMode) {
          print('تم اكتشاف مشكلة في الترميز، جاري استخدام طريقة بديلة');
        }

        // حل بديل للمشكلة - نص افتراضي قصير باستخدام اسم البرج بالعربية
        return 'قراءة اليوم لبرج $arabicZodiacName: اليوم مليء بالطاقة الإيجابية والفرص الجديدة. استمتع بالطاقة الكونية واستغل الفرص المتاحة لتحقيق أهدافك. علاقاتك الشخصية ستزدهر، وحياتك المهنية ستشهد تطوراً إيجابياً.';
      }

      return decodedText;
    } catch (e) {
      if (kDebugMode) {
        print('خطأ أثناء معالجة النص العربي: $e');
      }
      return text; // إرجاع النص الأصلي إذا فشلت المعالجة
    }
  }
}
