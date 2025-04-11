/// خدمة تسجيل سجلات البث المباشر
/// تستخدم لتوجيه رسائل السجل إلى وجهات مختلفة أثناء المحاكاة
class LiveStreamLogService {
  /// كائن مفرد (singleton) للخدمة
  static LiveStreamLogService instance = DefaultLiveStreamLogService();

  /// تسجيل رسالة
  void log(String message) {
    print(message);
  }
}

/// تنفيذ افتراضي لخدمة السجلات يستخدم print
class DefaultLiveStreamLogService extends LiveStreamLogService {
  @override
  void log(String message) {
    print(message);
  }
}

/// وظيفة نوع المستمع إلى السجلات
typedef LogListener = void Function(String message);

/// خدمة سجلات تستخدم دالة استماع خارجية
class CallbackLiveStreamLogService extends LiveStreamLogService {
  final LogListener listener;

  CallbackLiveStreamLogService(this.listener);

  @override
  void log(String message) {
    // طباعة الرسالة في الأصل
    print(message);
    // توجيه الرسالة إلى المستمع
    listener(message);
  }
}
