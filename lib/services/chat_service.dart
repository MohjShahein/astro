import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'notification_service.dart';
import 'package:untitled/services/session_manager.dart';
import 'wallet_service.dart';
import 'socket_service.dart';

class ChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final SocketService _socketService = SocketService();
  static const int FREE_SESSION_LIMIT =
      3; // الحد الأقصى للجلسات المجانية يومياً
  static const int FREE_SESSION_DURATION = 15; // مدة الجلسة المجانية بالدقائق
  static const int SESSION_TIMEOUT_MINUTES = 30;

  /// Extension method to make int.toDouble() available
  static double toDouble(int value) {
    return value.toDouble();
  }

  /// التحقق من وجود جلسة نشطة للمستخدم
  static Future<bool> hasActiveSession(String userId) async {
    try {
      if (userId.isEmpty) {
        throw Exception('معرف المستخدم غير صالح');
      }

      // إضافة قفل للجلسة لتجنب مشاكل التزامن
      final lockRef = _firestore.collection('session_locks').doc(userId);

      // استخدام معاملة للتحقق وإضافة قفل في نفس الوقت
      return await _firestore.runTransaction<bool>((transaction) async {
        // التحقق من وجود جلسات نشطة
        final activeSessions = await _firestore
            .collection('chat_sessions')
            .where('participants', arrayContains: userId)
            .where('status', isEqualTo: 'active')
            .get();

        bool hasActive = activeSessions.docs.isNotEmpty;

        // إضافة قفل مؤقت إذا لم يكن هناك جلسة نشطة
        if (!hasActive) {
          transaction.set(lockRef, {
            'locked_at': FieldValue.serverTimestamp(),
            'expires_at': DateTime.now().add(const Duration(minutes: 2)),
          });
        }

        return hasActive;
      });
    } catch (e) {
      print('خطأ في التحقق من وجود جلسة نشطة: $e');
      return false;
    }
  }

  /// التحقق من وجود جلسة نشطة للفلكي
  static Future<bool> hasAstrologerActiveSession(String astrologerId) async {
    try {
      final activeSessions = await _firestore
          .collection('chat_sessions')
          .where('astrologer_id', isEqualTo: astrologerId)
          .where('status', isEqualTo: 'active')
          .get();

      return activeSessions.docs.isNotEmpty;
    } catch (e) {
      print('خطأ في التحقق من الجلسات النشطة للفلكي: $e');
      // في حالة الخطأ أو مشكلة في الأذونات، نفترض أن الفلكي مشغول لضمان وضع الجلسات في قائمة الانتظار
      return true;
    }
  }

  /// إلغاء قفل الجلسة بعد إنشائها أو فشل الإنشاء
  static Future<void> releaseSessionLock(String userId) async {
    try {
      await _firestore.collection('session_locks').doc(userId).delete();
    } catch (e) {
      print('Error releasing session lock: $e');
    }
  }

  /// التحقق من وجود الفلكي في قائمة الفلكيين المعتمدين
  static Future<bool> isApprovedAstrologer(String astrologerId) async {
    try {
      // التحقق من وجود الفلكي في جدول المستخدمين أولاً
      final userDoc =
          await _firestore.collection('users').doc(astrologerId).get();
      if (!userDoc.exists) {
        print('User document does not exist');
        return false;
      }

      final userData = userDoc.data();
      if (userData == null ||
          userData['user_type'] != 'astrologer' ||
          userData['astrologer_status'] != 'approved') {
        print('User is not an approved astrologer');
        return false;
      }

      // التحقق من وجود الفلكي في قائمة الفلكيين المعتمدين
      final approvedDoc = await _firestore
          .collection('approved_astrologers')
          .doc(astrologerId)
          .get();
      if (!approvedDoc.exists) {
        print('Astrologer is not in approved list');
        // إذا لم يكن في القائمة، أضفه
        await addToApprovedAstrologers(astrologerId);
        return true;
      }

      return true;
    } catch (e) {
      print('Error checking approved astrologer: $e');
      return false;
    }
  }

  /// إضافة فلكي إلى قائمة الفلكيين المعتمدين
  static Future<bool> addToApprovedAstrologers(String astrologerId) async {
    try {
      // التحقق من وجود الفلكي في جدول المستخدمين
      final userDoc =
          await _firestore.collection('users').doc(astrologerId).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data();
      if (userData == null ||
          userData['user_type'] != 'astrologer' ||
          userData['astrologer_status'] != 'approved') {
        // تحديث حالة المستخدم أولاً
        await _firestore.collection('users').doc(astrologerId).update({
          'user_type': 'astrologer',
          'astrologer_status': 'approved',
        });
      }

      // إضافة الفلكي إلى قائمة الفلكيين المعتمدين
      await _firestore
          .collection('approved_astrologers')
          .doc(astrologerId)
          .set({
        'approved_at': FieldValue.serverTimestamp(),
        'astrologer_id': astrologerId,
        'status': 'active',
      });

      print('Successfully added astrologer to approved list');
      return true;
    } catch (e) {
      print('Error adding to approved astrologers: $e');
      return false;
    }
  }

  /// التحقق من عدد الجلسات المجانية اليوم
  static Future<bool> hasReachedFreeSessionLimit(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      final freeSessions = await _firestore
          .collection('chat_sessions')
          .where('user_id', isEqualTo: userId)
          .where('is_free_session', isEqualTo: true)
          .where(
            'created_at',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where(
            'created_at',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
          )
          .get();

      final count = freeSessions.docs.length;
      print(
        'التحقق من حد الجلسات المجانية: المستخدم استخدم $count من أصل $FREE_SESSION_LIMIT جلسات',
      );
      return count >= FREE_SESSION_LIMIT;
    } catch (e) {
      print('Error checking free session limit: $e');
      // في حالة الخطأ، لا نفترض أن المستخدم وصل للحد الأقصى، ونسمح له بالمحاولة
      return false;
    }
  }

  /// الحصول على أسعار جلسات الفلكي
  static Future<Map<String, dynamic>> _getSessionRates(
    String astrologerId,
  ) async {
    try {
      // محاولة الحصول على أسعار الفلكي الخاصة
      final astrologerRatesDoc = await _firestore
          .collection('astrologer_rates')
          .doc(astrologerId)
          .get();

      if (astrologerRatesDoc.exists) {
        return astrologerRatesDoc.data() ?? {};
      }

      // إذا لم يكن لدى الفلكي أسعار خاصة، استخدم الأسعار الافتراضية
      final defaultRatesDoc =
          await _firestore.collection('default_rates').doc('default').get();

      return defaultRatesDoc.data() ?? {};
    } catch (e) {
      print('Error getting session rates: $e');
      return {};
    }
  }

  /// Creates a new message in a chat session
  static Future<void> sendMessage(
    String sessionId,
    String message,
    String senderId,
  ) async {
    try {
      print('محاولة إرسال رسالة في الجلسة: $sessionId من المستخدم: $senderId');

      // التحقق من وجود الجلسة وحالتها
      final sessionDoc =
          await _firestore.collection('chat_sessions').doc(sessionId).get();
      if (!sessionDoc.exists) {
        throw 'الجلسة غير موجودة';
      }

      final sessionData = sessionDoc.data();
      if (sessionData == null) {
        throw 'بيانات الجلسة غير موجودة';
      }

      // التحقق من أن الجلسة نشطة
      if (sessionData['status'] != 'active') {
        throw 'الجلسة غير نشطة';
      }

      print('بيانات الجلسة: ${sessionData.toString()}');

      // التحقق من أن المرسل هو أحد المشاركين في الجلسة
      List<dynamic> participants = sessionData['participants'] ?? [];
      String userId = sessionData['user_id'] ?? '';
      String astrologerId = sessionData['astrologer_id'] ?? '';

      print('المشاركون في الجلسة: $participants');
      print('معرف المستخدم: $userId، معرف الفلكي: $astrologerId');

      if (!participants.contains(senderId) &&
          senderId != userId &&
          senderId != astrologerId) {
        throw 'ليس لديك صلاحية لإرسال رسائل في هذه الجلسة';
      }

      // إنشاء الرسالة
      await _firestore
          .collection('chat_sessions')
          .doc(sessionId)
          .collection('messages')
          .add({
        'content': message,
        'sender_id': senderId,
        'created_at': FieldValue.serverTimestamp(),
      });

      print('تم إرسال الرسالة بنجاح');

      // تحديث آخر نشاط في الجلسة
      await _firestore.collection('chat_sessions').doc(sessionId).update({
        'last_message_at': FieldValue.serverTimestamp(),
        'last_activity': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  /// Retrieves all messages for a specific chat session
  static Stream<QuerySnapshot> getMessages(String sessionId) {
    return _firestore
        .collection('chat_sessions')
        .doc(sessionId)
        .collection('messages')
        .orderBy('created_at', descending: false)
        .snapshots();
  }

  /// الحصول على عدد الجلسات المجانية المستخدمة اليوم
  static Future<int> getUserFreeSessions(String userId) async {
    try {
      print('جاري التحقق من عدد الجلسات المجانية للمستخدم $userId');
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      final freeSessions = await _firestore
          .collection('chat_sessions')
          .where('user_id', isEqualTo: userId)
          .where('is_free_session', isEqualTo: true)
          .where(
            'created_at',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where(
            'created_at',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
          )
          .get();

      final count = freeSessions.docs.length;
      print(
        'عدد الجلسات المجانية المستخدمة اليوم: $count من أصل $FREE_SESSION_LIMIT',
      );

      return count;
    } catch (e) {
      print('خطأ في الحصول على عدد الجلسات المجانية: $e');
      // في حالة الخطأ، نعيد 0 بدلاً من إلقاء استثناء، مما يسمح للمستخدمين ببدء الجلسات
      return 0;
    }
  }

  /// Creates a new chat session
  static Future<String?> createChatSession(
    String userId,
    String astrologerId,
    String sessionType, {
    bool isFree = false,
    bool createNotifications = true,
  }) async {
    try {
      // التحقق من وجود جلسة نشطة للمستخدم
      final hasActive = await hasActiveSession(userId);
      if (hasActive) {
        throw 'لديك جلسة نشطة بالفعل، يرجى إنهاؤها قبل بدء جلسة جديدة';
      }

      // التحقق من الجلسات المجانية للجلسات المجانية فقط
      if (isFree) {
        final reachedLimit = await hasReachedFreeSessionLimit(userId);
        if (reachedLimit) {
          throw 'لقد وصلت إلى الحد الأقصى للجلسات المجانية اليوم ($FREE_SESSION_LIMIT)';
        }
      }

      // التحقق من وجود الفلكي في قائمة الفلكيين المعتمدين
      final isApproved = await isApprovedAstrologer(astrologerId);
      if (!isApproved) {
        throw 'الفلكي غير معتمد، لا يمكن إنشاء جلسة';
      }

      // الحصول على أسعار الفلكي للتحقق من الرصيد
      final rates = await getAstrologerRate(astrologerId);

      // التحقق من دعم الجلسات المجانية للجلسات المجانية
      if (isFree && !(rates['is_free'] ?? false)) {
        throw 'هذا الفلكي لا يقدم جلسات مجانية';
      }

      // تحديد سعر الدقيقة بناءً على نوع الجلسة
      double ratePerMinute = 0;
      switch (sessionType) {
        case 'text':
          ratePerMinute = (rates['text_rate'] is num)
              ? (rates['text_rate'] as num).toDouble()
              : 0.0;
          break;
        case 'audio':
          ratePerMinute = (rates['audio_rate'] is num)
              ? (rates['audio_rate'] as num).toDouble()
              : 0.0;
          break;
        case 'video':
          ratePerMinute = (rates['video_rate'] is num)
              ? (rates['video_rate'] as num).toDouble()
              : 0.0;
          break;
        default:
          ratePerMinute = (rates['text_rate'] is num)
              ? (rates['text_rate'] as num).toDouble()
              : 0.0;
      }

      // التحقق من رصيد المستخدم للجلسات المدفوعة
      if (!isFree) {
        final requiredAmount = ratePerMinute * SESSION_TIMEOUT_MINUTES;
        print(
            'التحقق من رصيد المستخدم للجلسة المدفوعة: المطلوب $requiredAmount');

        double userBalance = await WalletService.getWalletBalance(userId);
        print('رصيد المستخدم الحالي: $userBalance');

        bool hasEnoughBalance =
            await WalletService.validateBalance(userId, requiredAmount);
        if (!hasEnoughBalance) {
          throw 'رصيد المحفظة غير كافٍ لبدء الجلسة المدفوعة. الرصيد المطلوب: $requiredAmount كوينز، الرصيد الحالي: $userBalance كوينز';
        }

        print('الرصيد كافٍ لبدء الجلسة المدفوعة');
      }

      // البحث عن أي جلسات نشطة للفلكي - طريقة أكثر أمانًا للتحقق
      bool astrologerBusy = false;
      try {
        // نستخدم الطريقة الأبسط للتحقق دون البحث المباشر الذي قد يواجه مشاكل صلاحيات
        // نحصل على وثائق الجلسات النشطة من الفلكي ضمن حدود صلاحياتنا
        final activeSessions = await _firestore
            .collection('chat_sessions')
            .where('status', isEqualTo: 'active')
            .get();

        // نفلتر الوثائق التي تخص الفلكي بعد استلامها
        final astrologerActiveSessions = activeSessions.docs
            .where((doc) => doc.data()['astrologer_id'] == astrologerId)
            .toList();

        astrologerBusy = astrologerActiveSessions.isNotEmpty;

        print('الفلكي لديه جلسة نشطة: $astrologerBusy');
      } catch (e) {
        print('خطأ في التحقق من الجلسات النشطة للفلكي: $e');
        // في حالة الخطأ، نفترض أن الفلكي مشغول للسلامة
        astrologerBusy = true;
      }

      // تحديد حالة الجلسة بناءً على حالة الفلكي
      String sessionStatus = astrologerBusy ? 'pending' : 'active';

      // إنشاء معرف للجلسة
      final sessionId = const Uuid().v4();

      // إنشاء جلسة جديدة في Firestore
      print(
        'إنشاء جلسة ${isFree ? "مجانية" : "مدفوعة"} جديدة، النوع: $sessionType، السعر: $ratePerMinute، الحالة: $sessionStatus',
      );

      await _firestore.collection('chat_sessions').doc(sessionId).set({
        'session_id': sessionId,
        'user_id': userId,
        'astrologer_id': astrologerId,
        'participants': [userId, astrologerId],
        'status': sessionStatus,
        'created_at': FieldValue.serverTimestamp(),
        'start_time':
            sessionStatus == 'active' ? FieldValue.serverTimestamp() : null,
        'end_time': null,
        'last_message_at': FieldValue.serverTimestamp(),
        'session_type': sessionType,
        'rate_per_minute': ratePerMinute,
        'is_paid': !isFree,
        'is_free_session': isFree,
        'total_duration': 0.0,
        'total_cost': 0.0,
        'free_session_limit': isFree ? toDouble(FREE_SESSION_DURATION) : 0.0,
      });

      // إزالة قفل الجلسة بعد الإنشاء
      await releaseSessionLock(userId);

      String messageStatus =
          sessionStatus == 'active' ? 'نشطة' : 'قيد الانتظار';
      print('تم إنشاء الجلسة بنجاح: $sessionId، الحالة: $messageStatus');

      // إضافة إشعار للفلكي إذا تم طلب الإشعارات
      if (createNotifications) {
        try {
          String notificationMessage = '';
          if (sessionStatus == 'active' && isFree) {
            notificationMessage =
                'لديك جلسة مجانية جديدة. المدة: $FREE_SESSION_DURATION دقيقة';
          } else if (sessionStatus == 'active' && !isFree) {
            notificationMessage = 'تم بدء جلسة مدفوعة جديدة.';
          } else {
            notificationMessage =
                'لديك طلب جلسة جديد في قائمة الانتظار. يرجى التحقق من الجلسات المعلقة.';
          }

          await NotificationService.addNotification(
            astrologerId,
            notificationMessage,
          );
        } catch (e) {
          print('خطأ في إضافة إشعار للفلكي: $e');
          // نتجاهل الخطأ ونستمر
        }
      }

      return sessionId;
    } catch (e) {
      print('خطأ في إنشاء الجلسة: $e');
      // إزالة القفل في حالة فشل الإنشاء
      await releaseSessionLock(userId);
      throw 'فشل في إنشاء الجلسة: $e';
    }
  }

  /// إنشاء جلسة محادثة مدفوعة
  static Future<String?> createPaidChatSession(
    String userId,
    String astrologerId, {
    required String sessionType,
  }) async {
    // استخدام createChatSession لتوحيد المنطق وتجنب تكرار الكود
    return await createChatSession(
      userId,
      astrologerId,
      sessionType,
      isFree: false,
      createNotifications: true,
    );
  }

  /// تعيين أسعار جلسات الفلكي
  static Future<void> setAstrologerRates(
    String astrologerId,
    double textRate,
    double audioRate,
    double videoRate, {
    bool isFree = false,
  }) async {
    try {
      // طباعة القيم الواردة للتشخيص
      print('-------------- معلومات حفظ أسعار الفلكي --------------');
      print('الفلكي: $astrologerId');
      print('سعر المحادثة: $textRate');
      print('سعر المكالمة الصوتية: $audioRate');
      print('سعر مكالمة الفيديو: $videoRate');
      print('مجاني: $isFree');

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw 'يجب تسجيل الدخول أولاً';
      }

      // التحقق من صلاحيات المستخدم
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        throw 'لم يتم العثور على بيانات المستخدم';
      }

      final userData = userDoc.data();
      if (userData == null) {
        throw 'بيانات المستخدم غير صالحة';
      }

      final isAdmin = userData['is_admin'] ?? false;
      if (!isAdmin && currentUser.uid != astrologerId) {
        throw 'عذراً، لا يمكنك تغيير أسعار فلكي آخر';
      }

      // ملاحظة تشخيصية إذا كانت الجلسات مجانية
      if (isFree) {
        print(
          'الجلسات مجانية، الأسعار ستبقى كما هي: text=$textRate, audio=$audioRate, video=$videoRate',
        );
      }

      // التحقق من القيم السالبة
      if (textRate < 0 || audioRate < 0 || videoRate < 0) {
        throw 'لا يمكن أن تكون الأسعار سالبة';
      }

      // تأكد من وجود الفلكي في الـ users
      final astrologerSnapshot =
          await _firestore.collection('users').doc(astrologerId).get();
      if (!astrologerSnapshot.exists) {
        throw 'لم يتم العثور على بيانات الفلكي';
      }

      // حفظ الأسعار في Firestore
      await _firestore.collection('astrologer_rates').doc(astrologerId).set({
        'text_rate': textRate,
        'audio_rate': audioRate,
        'video_rate': videoRate,
        'is_free': isFree,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': currentUser.uid,
      });

      // تحديث حالة الجلسات المجانية في بيانات الفلكي
      await _firestore.collection('users').doc(astrologerId).update({
        'offers_free_sessions': isFree,
        'last_updated': FieldValue.serverTimestamp(),
        'last_updated_by': currentUser.uid,
      });

      print(
        'تم حفظ أسعار الفلكي بنجاح: text_rate=$textRate, audio_rate=$audioRate, video_rate=$videoRate, is_free=$isFree',
      );
      return;
    } catch (e) {
      print('خطأ في حفظ أسعار الفلكي: $e');
      rethrow;
    }
  }

  /// الحصول على سعر الدقيقة للفلكي
  static Future<Map<String, dynamic>> getAstrologerRate(
    String astrologerId,
  ) async {
    try {
      // التحقق من وجود الفلكي في قائمة الفلكيين المعتمدين
      final approvedDoc = await _firestore
          .collection('approved_astrologers')
          .doc(astrologerId)
          .get();

      if (!approvedDoc.exists) {
        print('الفلكي غير معتمد، سيتم استخدام الأسعار الافتراضية');
      }

      // محاولة الحصول على أسعار الفلكي الخاصة
      final rateDoc = await _firestore
          .collection('astrologer_rates')
          .doc(astrologerId)
          .get();

      if (rateDoc.exists) {
        final data = rateDoc.data() as Map<String, dynamic>;
        return {
          'text_rate': data['text_rate'] ?? 1.0,
          'audio_rate': data['audio_rate'] ?? 1.5,
          'video_rate': data['video_rate'] ?? 2.0,
          'is_free': data['is_free'] ?? false,
        };
      }

      // إذا لم يكن لدى الفلكي أسعار خاصة، استخدم الأسعار الافتراضية
      print(
        'لم يتم العثور على أسعار خاصة للفلكي، سيتم استخدام الأسعار الافتراضية',
      );
      final defaultRates = await getDefaultRates();
      return defaultRates;
    } catch (e) {
      print('Error getting astrologer rate: $e');
      // إرجاع أسعار افتراضية في حالة حدوث خطأ
      return {
        'text_rate': 1.0,
        'audio_rate': 1.5,
        'video_rate': 2.0,
        'is_free': false,
      };
    }
  }

  /// Accepts a pending paid chat session (for astrologers)
  static Future<void> acceptPaidChatSession(String sessionId) async {
    try {
      String userId = '';
      String astrologerId = '';

      // استخدام المعاملة بشكل صحيح بنقل جميع عمليات القراءة داخل المعاملة
      await _firestore.runTransaction((transaction) async {
        // 1. قراءة بيانات الجلسة داخل المعاملة
        final sessionRef =
            _firestore.collection('chat_sessions').doc(sessionId);
        final session = await transaction.get(sessionRef);

        if (!session.exists) {
          throw 'لم يتم العثور على الجلسة المطلوبة';
        }

        // التأكد من أن الجلسة معلقة
        final sessionData = session.data() as Map<String, dynamic>;
        if (sessionData['status'] != 'pending') {
          throw 'لا يمكن قبول الجلسة لأنها ليست في حالة الانتظار';
        }

        // استخراج معلومات المشاركين
        astrologerId = sessionData['astrologer_id'];
        userId = sessionData['user_id']; // المستخدم العادي

        // 2. قبول الجلسة الحالية وتغييرها إلى نشطة (عملية كتابة)
        transaction.update(
          sessionRef,
          {'status': 'active', 'start_time': FieldValue.serverTimestamp()},
        );
      });

      // للتعامل مع الجلسات الأخرى، نتحقق منها خارج المعاملة الأولى
      // وجعلها في معاملة منفصلة لتجنب مشاكل القراءة والكتابة
      // الحصول على كل الجلسات النشطة الأخرى للفلكي
      final activeSessions = await _firestore
          .collection('chat_sessions')
          .where('astrologer_id', isEqualTo: astrologerId)
          .where('status', isEqualTo: 'active')
          .where(FieldPath.documentId, isNotEqualTo: sessionId)
          .get();

      // إذا كان هناك جلسات أخرى نشطة، قم بتعليقها
      if (activeSessions.docs.isNotEmpty) {
        final batch = _firestore.batch();

        // تغيير حالة أي جلسات نشطة أخرى (باستثناء الجلسة الحالية) إلى معلقة
        for (var doc in activeSessions.docs) {
          batch.update(
            _firestore.collection('chat_sessions').doc(doc.id),
            {'status': 'pending'},
          );

          // إرسال إشعار للمستخدم المتأثر
          final docData = doc.data();
          String? affectedUserId = docData['user_id'];
          if (affectedUserId != null) {
            await NotificationService.addNotification(
              affectedUserId,
              'تم تعليق جلستك مؤقتًا حيث يعمل الفلكي على جلسة أخرى الآن. سيتم استئناف جلستك قريبًا.',
            );
          }
        }

        // تنفيذ جميع التحديثات دفعة واحدة
        await batch.commit();
      }

      // إرسال إشعار للمستخدم
      await NotificationService.addNotification(
        userId,
        'تم قبول طلب الجلسة الخاصة بك. يمكنك البدء الآن.',
      );

      print('تم قبول الجلسة بنجاح: $sessionId');
    } catch (e) {
      print('خطأ في قبول الجلسة: $e');
      throw 'فشل في قبول الجلسة: $e';
    }
  }

  /// Checks and handles session timeout
  static Future<void> checkAndHandleTimeout(String sessionId) async {
    await SessionManager.checkSessionTimeout(sessionId);
  }

  /// إنهاء الجلسة
  static Future<void> endSession(String sessionId) async {
    try {
      print('بدء عملية إنهاء الجلسة: $sessionId');

      // قراءة بيانات الجلسة أولاً لاستخدامها لاحقًا في الإشعارات
      String userId = '';
      String astrologerId = '';
      double cost = 0.0;

      // استخدام المعاملة بشكل صحيح مع نقل جميع عمليات القراءة داخل المعاملة
      await _firestore.runTransaction((transaction) async {
        // 1. قراءة بيانات الجلسة داخل المعاملة (قبل أي عمليات كتابة)
        final sessionRef =
            _firestore.collection('chat_sessions').doc(sessionId);
        final sessionDoc = await transaction.get(sessionRef);

        if (!sessionDoc.exists) {
          throw Exception('الجلسة غير موجودة');
        }

        final sessionData = sessionDoc.data() as Map<String, dynamic>;

        // التحقق من أن الجلسة نشطة
        if (sessionData['status'] != 'active') {
          print(
              'لا يمكن إنهاء جلسة غير نشطة - الحالة الحالية: ${sessionData['status']}');
          return;
        }

        userId = sessionData['user_id'] as String;
        astrologerId = sessionData['astrologer_id'] as String;
        final startTime = (sessionData['start_time'] as Timestamp).toDate();
        final rate = (sessionData['rate_per_minute'] as num).toDouble();

        // حساب المدة والتكلفة
        final now = DateTime.now();
        final durationInMinutes = now.difference(startTime).inMinutes;

        // ضمان مدة دنيا (ولو كانت صفر)
        final actualDuration = durationInMinutes > 0 ? durationInMinutes : 1;
        cost = rate * actualDuration;

        // 3. قراءة محفظة المنجم داخل المعاملة (قبل أي عمليات كتابة)
        final astrologerWalletRef =
            _firestore.collection('wallets').doc(astrologerId);
        final astrologerWalletDoc = await transaction.get(astrologerWalletRef);

        // الآن بعد اكتمال جميع عمليات القراءة، يمكننا بدء عمليات الكتابة

        // 2. تحديث حالة الجلسة (عملية كتابة)
        transaction.update(sessionRef, {
          'status': 'completed',
          'end_time': FieldValue.serverTimestamp(),
          'total_duration': actualDuration,
          'total_cost': cost,
        });

        // 4. تحديث محفظة المنجم (عملية كتابة)
        if (astrologerWalletDoc.exists) {
          final currentBalance =
              (astrologerWalletDoc.data()?['balance'] as num?)?.toDouble() ??
                  0.0;
          transaction
              .update(astrologerWalletRef, {'balance': currentBalance + cost});
        } else {
          transaction.set(
              astrologerWalletRef, {'balance': cost, 'user_id': astrologerId});
        }

        // 5. إنشاء سجل معاملة (عملية كتابة)
        final transactionRef = _firestore.collection('transactions').doc();
        transaction.set(transactionRef, {
          'user_id': userId,
          'astrologer_id': astrologerId,
          'session_id': sessionId,
          'amount': cost,
          'transaction_type': 'session',
          'status': 'completed',
          'created_at': FieldValue.serverTimestamp(),
          'other_party_id': astrologerId,
        });

        // إنشاء سجل معاملة للفلكي أيضًا
        final astrologerTransactionRef =
            _firestore.collection('transactions').doc();
        transaction.set(astrologerTransactionRef, {
          'user_id': astrologerId,
          'astrologer_id': astrologerId,
          'session_id': sessionId,
          'amount': cost,
          'transaction_type': 'earning',
          'status': 'completed',
          'created_at': FieldValue.serverTimestamp(),
          'other_party_id': userId,
        });
      });

      print('تم إنهاء الجلسة بنجاح: $sessionId');

      // إرسال إشعار بانتهاء الجلسة باستخدام البيانات المحفوظة
      try {
        await NotificationService.sendSessionEndedNotification(
          userId: userId,
          astrologerId: astrologerId,
          sessionId: sessionId,
        );
      } catch (e) {
        print('خطأ في إرسال إشعار انتهاء الجلسة: $e');
        // نستمر بالرغم من خطأ الإشعار لأن الجلسة قد انتهت بالفعل
      }
    } catch (e) {
      print('خطأ في إنهاء الجلسة: $e');
      rethrow;
    }
  }

  /// Cancels a paid chat session
  static Future<void> cancelPaidChatSession(
    String sessionId,
    String reason,
  ) async {
    DocumentSnapshot session =
        await _firestore.collection('chat_sessions').doc(sessionId).get();
    Map<String, dynamic> sessionData = session.data() as Map<String, dynamic>;
    List<dynamic> participants = sessionData['participants'];
    String userId = participants[0];

    // Calculate partial refund if session was active
    if (sessionData['status'] == 'active' && sessionData['is_paid']) {
      Timestamp startTime = sessionData['start_time'];
      Timestamp now = Timestamp.now();
      int durationInMinutes = ((now.seconds - startTime.seconds) / 60).ceil();

      // التأكد من أن rate_per_minute هو قيمة عددية
      double ratePerMinute = 0.0;
      if (sessionData['rate_per_minute'] is double) {
        ratePerMinute = sessionData['rate_per_minute'];
      } else if (sessionData['rate_per_minute'] is int) {
        ratePerMinute = (sessionData['rate_per_minute'] as int).toDouble();
      } else {
        print(
          'خطأ: rate_per_minute ليس قيمة عددية صالحة. استخدام 1.0 كقيمة افتراضية.',
        );
        ratePerMinute = 1.0;
      }

      double partialCost = durationInMinutes * ratePerMinute;
      double refundAmount =
          ratePerMinute * SessionManager.SESSION_TIMEOUT_MINUTES - partialCost;

      if (refundAmount > 0) {
        await WalletService.processRefund(
          userId,
          refundAmount,
          isPartial: true,
        );
      }
    }

    await _firestore.collection('chat_sessions').doc(sessionId).update({
      'status': 'cancelled',
      'cancellation_reason': reason,
      'end_time': FieldValue.serverTimestamp(),
    });

    // Notify both participants
    for (String participantId in participants) {
      await NotificationService.addNotification(
        participantId,
        'تم إلغاء الجلسة. السبب: $reason',
      );
    }
  }

  /// Retrieves all chat sessions for a user
  static Stream<QuerySnapshot> getUserChatSessions(String userId) {
    return _firestore
        .collection('chat_sessions')
        .where('participants', arrayContains: userId)
        .snapshots();
  }

  /// الحصول على جلسات المستخدم حسب الحالة
  static Stream<QuerySnapshot> getUserSessionsByStatus(
    String userId,
    String status,
  ) {
    try {
      print(
          'استعلام عن جلسات المستخدم حسب الحالة: userId=$userId, status=$status');

      // نستخدم استعلام بسيط بدون ترتيب لتجنب مشكلة الفهرس المركب
      // يمكن إجراء الترتيب على جانب العميل بعد استلام البيانات
      return _firestore
          .collection('chat_sessions')
          .where('participants', arrayContains: userId)
          .where('status', isEqualTo: status)
          .snapshots();
    } catch (e) {
      print('خطأ في الحصول على جلسات المستخدم حسب الحالة: $e');

      // في حالة حدوث خطأ، نستخدم الاستعلام الأبسط
      return _firestore
          .collection('chat_sessions')
          .where('status', isEqualTo: status)
          .snapshots();
    }
  }

  /// الحصول على جلسات الفلكي
  static Stream<QuerySnapshot> getAstrologerSessions(String astrologerId) {
    try {
      print('استعلام عن جميع جلسات الفلكي: astrologerId=$astrologerId');

      return _firestore
          .collection('chat_sessions')
          .where('astrologer_id', isEqualTo: astrologerId)
          .snapshots();
    } catch (e) {
      print('خطأ في الحصول على جلسات الفلكي: $e');
      rethrow;
    }
  }

  /// الحصول على جلسات الفلكي حسب الحالة
  static Stream<QuerySnapshot> getAstrologerSessionsByStatus(
    String astrologerId,
    String status,
  ) {
    try {
      print(
        'استعلام عن جلسات الفلكي حسب الحالة: astrologerId=$astrologerId, status=$status',
      );

      // نستخدم استعلام بسيط بدون ترتيب لتجنب مشكلة الفهرس المركب
      // يمكن إجراء الترتيب على جانب العميل بعد استلام البيانات
      return _firestore
          .collection('chat_sessions')
          .where('astrologer_id', isEqualTo: astrologerId)
          .where('status', isEqualTo: status)
          .snapshots();
    } catch (e) {
      print('خطأ في الحصول على جلسات الفلكي حسب الحالة: $e');
      rethrow;
    }
  }

  /// Updates the last message timestamp of a chat session
  static Future<void> updateLastMessageTime(String sessionId) async {
    await _firestore.collection('chat_sessions').doc(sessionId).update({
      'last_message_at': FieldValue.serverTimestamp(),
    });
  }

  /// Gets the default rates for chat sessions
  static Future<Map<String, dynamic>> getDefaultRates() async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('default_rates').doc('default').get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'text_rate': data['text_rate'] ?? 1.0,
          'audio_rate': data['audio_rate'] ?? 1.5,
          'video_rate': data['video_rate'] ?? 2.0,
          'is_free': data['is_free'] ?? false,
        };
      } else {
        // إرجاع قيم افتراضية إذا لم تكن موجودة
        return {
          'text_rate': 1.0,
          'audio_rate': 1.5,
          'video_rate': 2.0,
          'is_free': false,
        };
      }
    } catch (e) {
      print('خطأ في الحصول على الأسعار الافتراضية: $e');
      // إرجاع قيم افتراضية في حالة حدوث خطأ
      return {
        'text_rate': 1.0,
        'audio_rate': 1.5,
        'video_rate': 2.0,
        'is_free': false,
      };
    }
  }

  /// Retrieves paid chat sessions for an astrologer based on status
  static Stream<QuerySnapshot> getAstrologerPaidSessions(
    String astrologerId,
    String status,
  ) {
    try {
      print(
        'استعلام عن جلسات الفلكي: astrologerId=$astrologerId, status=$status',
      );

      // استخدام استعلام بسيط بدون ترتيب للتغلب على مشاكل الفهرسة
      return _firestore
          .collection('chat_sessions')
          .where('astrologer_id', isEqualTo: astrologerId)
          .where('status', isEqualTo: status)
          .snapshots();
    } catch (e) {
      print('Error getting astrologer paid sessions: $e');
      // في حالة الخطأ، نلقي الاستثناء ليتم التعامل معه في الواجهة
      rethrow;
    }
  }

  /// تعيين الأسعار الافتراضية للجلسات (للمشرف فقط)
  static Future<void> setDefaultRates(
    double textRate,
    double audioRate,
    double videoRate, {
    bool isFree = false,
  }) async {
    try {
      // طباعة القيم الواردة للتشخيص
      print('-------------- معلومات حفظ الأسعار الافتراضية --------------');
      print('سعر المحادثة: $textRate');
      print('سعر المكالمة الصوتية: $audioRate');
      print('سعر مكالمة الفيديو: $videoRate');
      print('مجاني: $isFree');

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw 'يجب تسجيل الدخول أولاً';
      }

      // التحقق من صلاحيات المستخدم
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        throw 'لم يتم العثور على بيانات المستخدم';
      }

      final userData = userDoc.data();
      if (userData == null) {
        throw 'بيانات المستخدم غير صالحة';
      }

      final isAdmin = userData['is_admin'] ?? false;
      if (!isAdmin) {
        throw 'عذراً، فقط المشرفون يمكنهم تعيين الأسعار الافتراضية';
      }

      // ملاحظة تشخيصية إذا كانت الجلسات مجانية
      if (isFree) {
        print(
          'الجلسات الافتراضية مجانية، الأسعار ستبقى كما هي: text=$textRate, audio=$audioRate, video=$videoRate',
        );
      }

      // التحقق من القيم السالبة
      if (textRate < 0 || audioRate < 0 || videoRate < 0) {
        throw 'لا يمكن أن تكون الأسعار سالبة';
      }

      // حفظ الأسعار في Firestore
      await _firestore.collection('default_rates').doc('default').set({
        'text_rate': textRate,
        'audio_rate': audioRate,
        'video_rate': videoRate,
        'is_free': isFree,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': currentUser.uid,
      });

      print(
        'تم حفظ الأسعار الافتراضية بنجاح: text_rate=$textRate, audio_rate=$audioRate, video_rate=$videoRate, is_free=$isFree',
      );
      return;
    } catch (e) {
      print('خطأ في حفظ الأسعار الافتراضية: $e');
      rethrow;
    }
  }

  /// التحقق من البيانات المخزنة في Firestore
  static Future<void> verifyFirestoreData() async {
    try {
      print('======= التحقق من بيانات Firestore =======');

      // التحقق من الأسعار الافتراضية
      print('--- التحقق من الأسعار الافتراضية ---');
      final defaultRatesDoc =
          await _firestore.collection('default_rates').doc('default').get();
      if (defaultRatesDoc.exists) {
        final data = defaultRatesDoc.data();
        print('الأسعار الافتراضية: $data');
      } else {
        print('لا توجد أسعار افتراضية محددة');
      }

      // التحقق من أسعار الفلكيين
      print('--- التحقق من أسعار الفلكيين ---');
      final astrologerRatesDocs =
          await _firestore.collection('astrologer_rates').get();
      print('عدد وثائق أسعار الفلكيين: ${astrologerRatesDocs.docs.length}');
      for (var doc in astrologerRatesDocs.docs) {
        print('معرف الفلكي: ${doc.id}, البيانات: ${doc.data()}');
      }

      // التحقق من الفلكيين المعتمدين
      print('--- التحقق من الفلكيين المعتمدين ---');
      final approvedAstrologersDocs =
          await _firestore.collection('approved_astrologers').get();
      print('عدد الفلكيين المعتمدين: ${approvedAstrologersDocs.docs.length}');
      for (var doc in approvedAstrologersDocs.docs) {
        print('معرف الفلكي المعتمد: ${doc.id}, البيانات: ${doc.data()}');
      }

      // التحقق من وثائق قراءات الأبراج
      print('--- التحقق من قراءات الأبراج ---');
      try {
        final zodiacReadingsDocs =
            await _firestore.collection('zodiac_readings').get();
        print('عدد قراءات الأبراج: ${zodiacReadingsDocs.docs.length}');
      } catch (e) {
        print('خطأ في الوصول إلى قراءات الأبراج: $e');
      }

      // التحقق من الجلسات المجانية
      print('--- التحقق من الجلسات المجانية ---');
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final freeSessionsCount = await getUserFreeSessions(currentUser.uid);
        print('عدد الجلسات المجانية للمستخدم الحالي: $freeSessionsCount');
      } else {
        print('لا يوجد مستخدم حالي');
      }

      print('======= انتهاء التحقق من بيانات Firestore =======');
    } catch (e) {
      print('خطأ عام أثناء التحقق من بيانات Firestore: $e');
    }
  }

  /// الحصول على جلسات المستخدم العادي (غير الفلكي) حسب الحالة
  static Stream<QuerySnapshot> getUserSessionsByUserIdAndStatus(
    String userId,
    String status,
  ) {
    try {
      print(
          'استعلام عن جلسات المستخدم العادي حسب الحالة: userId=$userId, status=$status');

      // استعلام يستخدم حقل user_id بدلاً من participants
      return _firestore
          .collection('chat_sessions')
          .where('user_id', isEqualTo: userId)
          .where('status', isEqualTo: status)
          .snapshots();
    } catch (e) {
      print('خطأ في الحصول على جلسات المستخدم العادي حسب الحالة: $e');

      // في حالة حدوث خطأ
      rethrow;
    }
  }

  /// إنشاء جلسة جديدة
  static Future<String?> createSession({
    required String userId,
    required String astrologerId,
    required String sessionType,
    required Map<String, dynamic> rates,
  }) async {
    try {
      if (userId.isEmpty || astrologerId.isEmpty) {
        throw Exception('معرفات المستخدمين غير صالحة');
      }

      // التحقق من وجود جلسة نشطة
      final hasActive = await hasActiveSession(userId);
      if (hasActive) {
        throw Exception('لديك جلسة نشطة بالفعل');
      }

      // إنشاء معرف فريد للجلسة
      final sessionId = const Uuid().v4();

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

      // إنشاء الجلسة في Firestore
      await _firestore.collection('chat_sessions').doc(sessionId).set({
        'session_id': sessionId,
        'user_id': userId,
        'astrologer_id': astrologerId,
        'session_type': sessionType,
        'rate_per_minute': ratePerMinute,
        'status': 'active',
        'start_time': FieldValue.serverTimestamp(),
        'participants': [userId, astrologerId],
        'messages': [],
      });

      return sessionId;
    } catch (e) {
      print('خطأ في إنشاء الجلسة: $e');
      rethrow;
    }
  }

  /// بدء جلسة
  static Future<void> startSession(String sessionId) async {
    try {
      final sessionRef = _firestore.collection('chat_sessions').doc(sessionId);
      final sessionDoc = await sessionRef.get();

      if (!sessionDoc.exists) {
        throw Exception('الجلسة غير موجودة');
      }

      final sessionData = sessionDoc.data() as Map<String, dynamic>;
      if (sessionData['status'] != 'pending') {
        throw Exception('لا يمكن بدء الجلسة في حالتها الحالية');
      }

      // تحديث حالة الجلسة
      await sessionRef.update({
        'status': 'active',
        'started_at': FieldValue.serverTimestamp(),
      });

      // إرسال إشعارات البدء
      final userId = sessionData['user_id'] as String;
      final astrologerId = sessionData['astrologer_id'] as String;
      final sessionType = sessionData['session_type'] as String;

      // إرسال إشعار للمستخدم
      await NotificationService.sendNotification(
        userId: userId,
        title: 'بدأت الجلسة',
        body: 'تم بدء الجلسة بنجاح',
      );

      // إرسال إشعار للمنجم
      await NotificationService.sendNotification(
        userId: astrologerId,
        title: 'بدأت الجلسة',
        body: 'تم بدء الجلسة بنجاح',
      );

      // إرسال إشعارات عبر Socket.IO
      await _socketService.sendNotification(
        receiverId: userId,
        title: 'بدأت الجلسة',
        body: 'تم بدء الجلسة بنجاح',
        additionalData: {
          'session_id': sessionId,
          'session_type': sessionType,
          'agora_channel_name': sessionData['agora_channel_name'],
        },
      );

      await _socketService.sendNotification(
        receiverId: astrologerId,
        title: 'بدأت الجلسة',
        body: 'تم بدء الجلسة بنجاح',
        additionalData: {
          'session_id': sessionId,
          'session_type': sessionType,
          'agora_channel_name': sessionData['agora_channel_name'],
        },
      );
    } catch (e) {
      print('خطأ في بدء الجلسة: $e');
      rethrow;
    }
  }

  static Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
  }) async {
    try {
      // إرسال الإشعار عبر Firestore
      await NotificationService.sendNotification(
        userId: userId,
        title: title,
        body: body,
      );

      // إرسال الإشعار عبر Socket.IO
      await _socketService.sendNotification(
        receiverId: userId,
        title: title,
        body: body,
      );
    } catch (e) {
      print('خطأ في إرسال الإشعار: $e');
    }
  }
}
