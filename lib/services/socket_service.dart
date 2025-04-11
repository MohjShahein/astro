// TODO: قم بإضافة مكتبة Socket.IO في pubspec.yaml
// socket_io_client: ^2.0.0

import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';

class SocketService {
  // سيتم استخدام الوثائق الرسمية من Socket.IO (https://socket.io/)
  static final SocketService _instance = SocketService._internal();

  factory SocketService() {
    return _instance;
  }

  SocketService._internal();

  bool _isInitialized = false;

  // معرف الجلسة للاتصال
  String? _sessionId;

  // Socket أو client
  IO.Socket? _socket;

  // وظيفة استدعاء عند استلام إشعار جديد
  Function(Map<String, dynamic>)? onNotificationReceived;

  // حالة الاتصال
  ValueNotifier<bool> connectionStatus = ValueNotifier<bool>(false);

  /// تهيئة اتصال Socket.IO
  Future<void> initialize({required String userId}) async {
    if (_isInitialized) return;

    try {
      print('تهيئة اتصال Socket.IO للمستخدم: $userId');

      // عنوان خادم Socket.IO - يجب تغييره حسب بيئتك
      const String serverUrl = 'https://astrology-socket-server.herokuapp.com';

      _socket = IO.io(serverUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
        'query': {
          'userId': userId,
        }
      });

      // تعريف الأحداث
      _socket!.on('connect', (_) {
        print('تم الاتصال بـ Socket.IO');
        _sessionId = _socket!.id;
        connectionStatus.value = true;
      });

      _socket!.on('disconnect', (_) {
        print('تم قطع الاتصال بـ Socket.IO');
        connectionStatus.value = false;
      });

      _socket!.on('notification', (data) {
        print('تم استلام إشعار: $data');
        if (onNotificationReceived != null) {
          onNotificationReceived!(data);
        }
      });

      _socket!.on('error', (error) {
        print('خطأ في Socket.IO: $error');
      });

      _socket!.connect();

      _isInitialized = true;
      print('تم إعداد Socket.IO بنجاح');
    } catch (e) {
      print('خطأ في تهيئة Socket.IO: $e');
      _isInitialized = false;
      connectionStatus.value = false;
    }
  }

  /// إرسال إشعار عبر Socket.IO
  Future<void> sendNotification({
    required String receiverId,
    required String title,
    required String body,
    Map<String, dynamic>? additionalData,
  }) async {
    if (!_isInitialized || _socket == null) {
      print('خطأ: لم تتم تهيئة Socket.IO بعد');
      return;
    }

    if (!connectionStatus.value) {
      print('خطأ: Socket.IO غير متصل');
      return;
    }

    print('إرسال إشعار عبر Socket.IO: إلى $receiverId');

    final Map<String, dynamic> notificationData = {
      'receiverId': receiverId,
      'title': title,
      'body': body,
      'data': additionalData ?? {},
      'timestamp': DateTime.now().toIso8601String(),
    };

    _socket!.emit('send_notification', notificationData);
    print('تم إرسال الإشعار بنجاح عبر Socket.IO');
  }

  /// إرسال إشعار للجميع
  Future<void> sendBroadcastNotification({
    required String title,
    required String body,
    Map<String, dynamic>? additionalData,
  }) async {
    if (!_isInitialized || _socket == null) {
      print('خطأ: لم تتم تهيئة Socket.IO بعد');
      return;
    }

    if (!connectionStatus.value) {
      print('خطأ: Socket.IO غير متصل');
      return;
    }

    print('إرسال إشعار عام عبر Socket.IO');

    final Map<String, dynamic> notificationData = {
      'broadcast': true,
      'title': title,
      'body': body,
      'data': additionalData ?? {},
      'timestamp': DateTime.now().toIso8601String(),
    };

    _socket!.emit('broadcast_notification', notificationData);
    print('تم إرسال الإشعار العام بنجاح عبر Socket.IO');
  }

  /// إرسال إشعار بدء جلسة
  Future<void> sendSessionStartedNotification({
    required String userId,
    required String astrologerId,
    required String sessionId,
  }) async {
    await sendNotification(
      receiverId: userId,
      title: 'بدأت الجلسة',
      body: 'تم بدء الجلسة الاستشارية',
      additionalData: {
        'type': 'session_started',
        'session_id': sessionId,
        'astrologer_id': astrologerId,
      },
    );

    await sendNotification(
      receiverId: astrologerId,
      title: 'بدأت الجلسة',
      body: 'تم بدء الجلسة الاستشارية',
      additionalData: {
        'type': 'session_started',
        'session_id': sessionId,
        'user_id': userId,
      },
    );
  }

  /// إرسال إشعار إنهاء جلسة
  Future<void> sendSessionEndedNotification({
    required String userId,
    required String astrologerId,
    required String sessionId,
  }) async {
    await sendNotification(
      receiverId: userId,
      title: 'انتهت الجلسة',
      body: 'تم إنهاء الجلسة الاستشارية',
      additionalData: {
        'type': 'session_ended',
        'session_id': sessionId,
        'astrologer_id': astrologerId,
      },
    );

    await sendNotification(
      receiverId: astrologerId,
      title: 'انتهت الجلسة',
      body: 'تم إنهاء الجلسة الاستشارية',
      additionalData: {
        'type': 'session_ended',
        'session_id': sessionId,
        'user_id': userId,
      },
    );
  }

  /// إرسال إشعار بدء بث مباشر جديد
  Future<void> sendNewLiveStreamNotification({
    required String astrologistId,
    required String astrologistName,
    required String liveStreamId,
    required String title,
  }) async {
    // إرسال إشعار للجميع
    await sendBroadcastNotification(
      title: 'بث مباشر جديد',
      body: '$astrologistName بدأ بثًا مباشرًا: $title',
      additionalData: {
        'type': 'live_stream',
        'live_stream_id': liveStreamId,
        'astrologer_id': astrologistId,
      },
    );
  }

  /// قطع الاتصال بـ Socket.IO
  void disconnect() {
    if (!_isInitialized || _socket == null) return;

    _socket!.disconnect();
    _isInitialized = false;
    _sessionId = null;
    connectionStatus.value = false;
    print('تم قطع الاتصال بـ Socket.IO بنجاح');
  }

  /// التحقق من حالة الاتصال
  bool get isConnected {
    return connectionStatus.value;
  }
}
