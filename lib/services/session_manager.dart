import 'package:untitled/services/wallet_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:untitled/services/notification_service.dart';

class SessionManager {
  static const int SESSION_TIMEOUT_MINUTES = 30;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// التحقق من صلاحية إنشاء جلسة جديدة
  static Future<Map<String, dynamic>> validateSessionCreation(
    String userId,
    String astrologerId,
    Map<String, dynamic> rates,
    String sessionType,
  ) async {
    try {
      // التحقق من صحة المدخلات
      if (userId.isEmpty || astrologerId.isEmpty) {
        return {
          'isValid': false,
          'error': 'معرفات المستخدمين غير صالحة',
        };
      }

      // التحقق من المستخدم المصرح له
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {
          'isValid': false,
          'error': 'يجب تسجيل الدخول أولاً لإنشاء جلسة',
        };
      }

      // يجب أن يكون المستخدم الحالي هو نفسه الذي يحاول إنشاء الجلسة
      if (currentUser.uid != userId) {
        return {
          'isValid': false,
          'error': 'لا يمكنك إنشاء جلسة نيابة عن مستخدم آخر',
        };
      }

      // التحقق من وجود جلسة نشطة
      final activeSessions = await _firestore
          .collection('chat_sessions')
          .where('participants', arrayContains: userId)
          .where('status', isEqualTo: 'active')
          .get();

      if (activeSessions.docs.isNotEmpty) {
        return {
          'isValid': false,
          'error': 'لديك جلسة نشطة بالفعل',
        };
      }

      // التحقق من وجود الفلكي في قائمة الفلكيين المعتمدين
      final astrologerDoc = await _firestore
          .collection('approved_astrologers')
          .doc(astrologerId)
          .get();

      if (!astrologerDoc.exists) {
        return {
          'isValid': false,
          'error': 'الفلكي غير معتمد، لا يمكن إنشاء جلسة',
        };
      }

      // تحديد السعر المناسب حسب نوع الجلسة
      double ratePerMinute;
      switch (sessionType) {
        case 'text':
          ratePerMinute = rates['text_rate']?.toDouble() ?? 1.0;
          break;
        case 'audio':
          ratePerMinute = rates['audio_rate']?.toDouble() ?? 1.5;
          break;
        case 'video':
          ratePerMinute = rates['video_rate']?.toDouble() ?? 2.0;
          break;
        default:
          ratePerMinute = rates['text_rate']?.toDouble() ?? 1.0;
      }

      // التحقق من رصيد المحفظة
      final walletBalance = await WalletService.getWalletBalance(userId);
      if (walletBalance < ratePerMinute) {
        return {
          'isValid': false,
          'error': 'رصيد غير كافٍ لبدء الجلسة',
        };
      }

      return {
        'isValid': true,
        'ratePerMinute': ratePerMinute,
      };
    } catch (e) {
      print('خطأ في التحقق من صلاحية إنشاء الجلسة: $e');
      return {
        'isValid': false,
        'error': 'حدث خطأ أثناء التحقق من صلاحية إنشاء الجلسة',
      };
    }
  }

  /// التحقق من صلاحية إنهاء الجلسة
  static Future<Map<String, dynamic>> validateSessionEnd(
    String sessionId,
    String userId,
  ) async {
    try {
      // التحقق من المستخدم المصرح له
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {
          'isValid': false,
          'error': 'يجب تسجيل الدخول أولاً لإنهاء الجلسة',
        };
      }

      // الحصول على بيانات الجلسة
      final sessionDoc =
          await _firestore.collection('chat_sessions').doc(sessionId).get();

      if (!sessionDoc.exists) {
        return {
          'isValid': false,
          'error': 'الجلسة غير موجودة',
        };
      }

      final sessionData = sessionDoc.data() as Map<String, dynamic>;

      // التحقق من حالة الجلسة
      if (sessionData['status'] != 'active') {
        return {
          'isValid': false,
          'error': 'لا يمكن إنهاء جلسة غير نشطة',
          'status': sessionData['status'],
        };
      }

      // التحقق من أن المستخدم هو مشارك في الجلسة
      final sessionUserId = sessionData['user_id'];
      final sessionAstrologerId = sessionData['astrologer_id'];

      if (currentUser.uid != sessionUserId &&
          currentUser.uid != sessionAstrologerId) {
        return {
          'isValid': false,
          'error': 'لا يمكنك إنهاء جلسة لست مشاركًا فيها',
        };
      }

      return {
        'isValid': true,
        'error': '',
        'sessionData': sessionData,
      };
    } catch (e) {
      return {
        'isValid': false,
        'error': 'خطأ في التحقق من صلاحية إنهاء الجلسة: ${e.toString()}',
      };
    }
  }

  /// التحقق من انتهاء وقت الجلسات النشطة وإنهائها آليًا إذا تجاوزت المهلة
  static Future<void> checkSessionTimeout(String sessionId) async {
    try {
      final doc =
          await _firestore.collection('chat_sessions').doc(sessionId).get();

      if (doc.exists) {
        final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // التحقق فقط من الجلسات النشطة
        if (data['status'] != 'active') {
          return;
        }

        final Timestamp startTime = data['start_time'];
        final Duration difference =
            DateTime.now().difference(startTime.toDate());

        if (difference.inMinutes > SESSION_TIMEOUT_MINUTES) {
          // إنهاء الجلسة آليًا
          await _firestore.runTransaction((transaction) async {
            transaction.update(doc.reference, {
              'status': 'timeout',
              'end_time': FieldValue.serverTimestamp(),
              'auto_ended': true,
              'total_duration': SESSION_TIMEOUT_MINUTES,
            });

            // إشعار المستخدمين بانتهاء الجلسة
            String userId = data['user_id'];
            String astrologerId = data['astrologer_id'];

            await NotificationService.sendSessionEndedNotification(
              userId: userId,
              astrologerId: astrologerId,
              sessionId: sessionId,
            );
          });

          print('تم إنهاء الجلسة $sessionId آليًا بسبب تجاوز المهلة المحددة');
        }
      }
    } catch (e) {
      print('خطأ في التحقق من انتهاء وقت الجلسة: $e');
      // تسجيل الخطأ في Firestore
      await _firestore.collection('session_errors').add({
        'session_id': sessionId,
        'error': e.toString(),
        'created_at': FieldValue.serverTimestamp(),
      });
    }
  }

  /// التحقق من جميع الجلسات النشطة وإنهاء المنتهية منها
  static Future<void> checkAllActiveSessions() async {
    try {
      final activeSessions = await _firestore
          .collection('chat_sessions')
          .where('status', isEqualTo: 'active')
          .get();

      for (var session in activeSessions.docs) {
        await checkSessionTimeout(session.id);
      }

      print('تم التحقق من ${activeSessions.docs.length} جلسة نشطة');
    } catch (e) {
      print('خطأ في التحقق من الجلسات النشطة: $e');
      // تسجيل الخطأ في Firestore
      await _firestore.collection('session_errors').add({
        'error': e.toString(),
        'created_at': FieldValue.serverTimestamp(),
      });
    }
  }
}
