import 'package:cloud_firestore/cloud_firestore.dart';
import 'socket_service.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final SocketService _socketService = SocketService();

  /// إضافة إشعار جديد إلى Firestore
  static Future<void> addNotification(String userId, String message) async {
    await _firestore.collection('notifications').add({
      'user_id': userId,
      'message': message,
      'status': 'unread', // unread, read
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /// إرسال إشعار للمستخدم (يستخدم Firestore و Socket.IO معاً)
  static Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? additionalData,
  }) async {
    print('إرسال إشعار: userId=$userId, title=$title, body=$body');

    try {
      // إضافة الإشعار إلى Firestore للتخزين الدائم
      await _firestore.collection('notifications').add({
        'user_id': userId,
        'title': title,
        'message': body,
        'additional_data': additionalData,
        'status': 'unread',
        'created_at': FieldValue.serverTimestamp(),
      });

      // محاولة إرسال الإشعار عبر Socket.IO للتسليم في الوقت الفعلي
      try {
        await _socketService.sendNotification(
          receiverId: userId,
          title: title,
          body: body,
          additionalData: additionalData,
        );
      } catch (socketError) {
        print('تعذر إرسال الإشعار عبر Socket.IO: $socketError');
        // الإشعار سيظل متاحاً في Firestore حتى لو فشل إرسال Socket.IO
      }
    } catch (e) {
      print('خطأ في إرسال الإشعار: $e');
      rethrow;
    }

    print('تم إرسال الإشعار بنجاح إلى $userId');
  }

  /// إرسال إشعار إلى جميع المستخدمين
  static Future<void> sendBroadcastNotification({
    required String title,
    required String body,
    Map<String, dynamic>? additionalData,
  }) async {
    print('إرسال إشعار عام: $title, $body');

    try {
      // إضافة الإشعار إلى Firestore مع علامة توجيه للجميع
      await _firestore.collection('notifications').add({
        'to_all_users': true,
        'title': title,
        'message': body,
        'additional_data': additionalData,
        'status': 'unread',
        'created_at': FieldValue.serverTimestamp(),
      });

      // محاولة إرسال الإشعار عبر Socket.IO للتسليم في الوقت الفعلي
      try {
        await _socketService.sendBroadcastNotification(
          title: title,
          body: body,
          additionalData: additionalData,
        );
      } catch (socketError) {
        print('تعذر إرسال الإشعار العام عبر Socket.IO: $socketError');
        // الإشعار سيظل متاحاً في Firestore حتى لو فشل إرسال Socket.IO
      }
    } catch (e) {
      print('خطأ في إرسال الإشعار العام: $e');
    }

    print('تم إرسال الإشعار العام بنجاح');
  }

  /// الحصول على إشعارات مستخدم محدد
  static Stream<QuerySnapshot> getNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  /// وضع علامة على الإشعار كمقروء
  static Future<void> markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'status': 'read',
    });
  }

  /// حذف إشعار
  static Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
  }

  /// إرسال إشعار بانتهاء الجلسة
  static Future<void> sendSessionEndedNotification({
    required String userId,
    required String astrologerId,
    required String sessionId,
  }) async {
    try {
      // محاولة إرسال الإشعارات عبر Socket.IO
      try {
        await _socketService.sendSessionEndedNotification(
          userId: userId,
          astrologerId: astrologerId,
          sessionId: sessionId,
        );
      } catch (socketError) {
        print('تعذر إرسال الإشعار عبر Socket.IO: $socketError');

        // الرجوع إلى الطريقة التقليدية في حالة فشل Socket.IO
        // إرسال إشعار للمستخدم
        await sendNotification(
          userId: userId,
          title: 'انتهت الجلسة',
          body: 'تم إنهاء الجلسة بنجاح',
          additionalData: {
            'type': 'session_ended',
            'session_id': sessionId,
          },
        );

        // إرسال إشعار للفلكي
        await sendNotification(
          userId: astrologerId,
          title: 'انتهت الجلسة',
          body: 'تم إنهاء الجلسة بنجاح',
          additionalData: {
            'type': 'session_ended',
            'session_id': sessionId,
          },
        );
      }
    } catch (e) {
      print('خطأ في إرسال إشعارات إنهاء الجلسة: $e');
      // تسجيل الخطأ ولكن لا نرميه، حتى لا تتوقف عملية إنهاء الجلسة
    }
  }

  /// إرسال إشعار عند إنشاء بث مباشر جديد
  static Future<void> sendNewLiveStreamNotification({
    required String astrologistId,
    required String liveStreamId,
    required String title,
  }) async {
    try {
      // الحصول على معلومات المنجم
      final astrologistDoc =
          await _firestore.collection('users').doc(astrologistId).get();

      if (!astrologistDoc.exists) {
        print('لم يتم العثور على الفلكي للإشعار');
        return;
      }

      final astrologistData = astrologistDoc.data() as Map<String, dynamic>;
      final astrologistName = astrologistData['full_name'] ?? 'فلكي';

      // إنشاء الإشعار في Firestore
      await _firestore.collection('notifications').add({
        'title': 'بث مباشر جديد',
        'body': '$astrologistName بدأ بثًا مباشرًا: $title',
        'data': {
          'type': 'live_stream',
          'live_stream_id': liveStreamId,
          'astrologer_id': astrologistId,
        },
        'to_all_users': true,
        'created_at': FieldValue.serverTimestamp(),
        'is_read': false,
      });

      // إرسال إشعار عبر Socket.IO إلى جميع المستخدمين
      try {
        await _socketService.sendNewLiveStreamNotification(
          astrologistId: astrologistId,
          astrologistName: astrologistName,
          liveStreamId: liveStreamId,
          title: title,
        );
      } catch (socketError) {
        print('تعذر إرسال إشعار البث المباشر عبر Socket.IO: $socketError');
        // الإشعار سيظل متاحاً في Firestore حتى لو فشل إرسال Socket.IO
      }

      print('تم إرسال إشعار البث المباشر الجديد بنجاح');
    } catch (e) {
      print('خطأ في إرسال إشعار البث المباشر الجديد: $e');
    }
  }
}
