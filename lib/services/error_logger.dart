import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// خدمة مركزية لتسجيل وإدارة الأخطاء في التطبيق
class ErrorLogger {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static bool _isFirebaseCrashlyticsAvailable = false;

  /// تهيئة خدمة تسجيل الأخطاء
  static Future<void> initialize() async {
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      _isFirebaseCrashlyticsAvailable = true;
    } catch (e) {
      print('خطأ في تهيئة Firebase Crashlytics: $e');
      _isFirebaseCrashlyticsAvailable = false;
    }
  }

  /// تسجيل خطأ مع معلومات إضافية
  static Future<void> logError(
    String category,
    String message,
    dynamic error, {
    Map<String, dynamic>? additionalData,
    StackTrace? stackTrace,
    String? userId,
  }) async {
    // طباعة الخطأ في وحدة التحكم للمطورين
    print('[$category] $message: $error');
    if (stackTrace != null) {
      print(stackTrace);
    }

    try {
      // تسجيل الخطأ في Firebase Crashlytics إذا كان متاحًا
      if (_isFirebaseCrashlyticsAvailable) {
        if (userId != null) {
          FirebaseCrashlytics.instance.setUserIdentifier(userId);
        }

        FirebaseCrashlytics.instance.setCustomKey('category', category);
        if (additionalData != null) {
          for (var entry in additionalData.entries) {
            if (entry.value != null) {
              FirebaseCrashlytics.instance.setCustomKey(
                entry.key,
                entry.value.toString(),
              );
            }
          }
        }

        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          reason: message,
        );
      }

      // تسجيل الخطأ في Firestore للمراقبة والتحليل
      await _firestore.collection('app_errors').add({
        'category': category,
        'message': message,
        'error': error.toString(),
        'user_id': userId,
        'additional_data': additionalData,
        'timestamp': FieldValue.serverTimestamp(),
        'stack_trace': stackTrace?.toString(),
      });
    } catch (e) {
      // في حالة فشل تسجيل الخطأ، نكتفي بالطباعة
      print('خطأ في تسجيل الخطأ: $e');
    }
  }

  /// تسجيل خطأ في معالجة الجلسات
  static Future<void> logSessionError(
    String message,
    dynamic error, {
    String? sessionId,
    String? userId,
    StackTrace? stackTrace,
  }) async {
    Map<String, dynamic> additionalData = {};
    if (sessionId != null) {
      additionalData['session_id'] = sessionId;
    }

    await logError(
      'session',
      message,
      error,
      additionalData: additionalData,
      stackTrace: stackTrace,
      userId: userId,
    );
  }

  /// تسجيل خطأ في معالجة المدفوعات
  static Future<void> logPaymentError(
    String message,
    dynamic error, {
    String? transactionId,
    String? userId,
    double? amount,
    StackTrace? stackTrace,
  }) async {
    Map<String, dynamic> additionalData = {};
    if (transactionId != null) {
      additionalData['transaction_id'] = transactionId;
    }
    if (amount != null) {
      additionalData['amount'] = amount;
    }

    await logError(
      'payment',
      message,
      error,
      additionalData: additionalData,
      stackTrace: stackTrace,
      userId: userId,
    );
  }
}
