import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'agora_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'live_stream_log_service.dart';
import '../models/live_stream.dart';

/// خدمة إدارة البث المباشر
class LiveStreamService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // معلومات أساسية عن حالة البث
  static final ValueNotifier<bool> localUserJoined = ValueNotifier<bool>(false);
  static final ValueNotifier<List<int>> remoteUsers =
      ValueNotifier<List<int>>([]);
  static StreamSubscription? _localUserSubscription;

  // مراقبة محاولات الاتصال الفاشلة
  static int _connectionAttempts = 0;
  static const int _maxRetries = 3;

  /// إعادة ضبط حالة الخدمة
  static void resetServiceState() {
    _connectionAttempts = 0;
    localUserJoined.value = false;
    remoteUsers.value = [];
    AgoraService.resetServiceState();

    // إلغاء الاشتراك في الأحداث السابقة
    _localUserSubscription?.cancel();
    _localUserSubscription = null;
  }

  /// يُنشئ معرف فريد للجلسة
  static String _generateUniqueChannelName() {
    const int length = 16;
    const String chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final Random random = Random.secure();
    return String.fromCharCodes(
      List.generate(
          length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  /// إنشاء معرف فريد آمن للقناة
  static String generateSessionId() {
    return _generateUniqueChannelName();
  }

  /// الانضمام إلى قناة البث المباشر
  static Future<bool> joinLiveStreamChannel(
    String liveStreamId, {
    required bool isBroadcaster,
  }) async {
    try {
      print('محاولة الانضمام إلى قناة البث المباشر: $liveStreamId');

      // الحصول على معلومات البث المباشر
      final streamDoc =
          await _firestore.collection('live_streams').doc(liveStreamId).get();
      if (!streamDoc.exists) {
        throw Exception('البث المباشر غير موجود');
      }

      final data = streamDoc.data();
      if (data == null) {
        throw Exception('بيانات البث المباشر غير صالحة');
      }

      final channelName = data['channelName'] ?? data['channel_name'];
      if (channelName == null || channelName.isEmpty) {
        throw Exception('اسم القناة غير صالح');
      }

      // الحصول على معرف المستخدم الحالي
      String userId = _auth.currentUser?.uid ?? '';
      if (userId.isEmpty) {
        userId = 'anonymous_${DateTime.now().millisecondsSinceEpoch}';
        print('تم إنشاء معرف مستخدم مؤقت: $userId');
      }

      // الانضمام إلى القناة باستخدام خدمة أجورا
      final success = await AgoraService.joinLiveStreamChannel(
        channelName,
        userId,
        liveStreamId,
        isBroadcaster: isBroadcaster,
      );

      if (!success) {
        throw Exception('فشل في الانضمام إلى قناة البث المباشر');
      }

      // تحديث حالة الانضمام
      localUserJoined.value = true;

      print('تم الانضمام إلى قناة البث المباشر بنجاح');
      return true;
    } catch (e) {
      print('خطأ في الانضمام إلى قناة البث المباشر: $e');
      return false;
    }
  }

  /// إنشاء بث مباشر جديد
  static Future<String> createLiveStream({
    required String title,
    required String broadcasterName,
    String? thumbnailUrl,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('يجب تسجيل الدخول أولاً');

      final docRef = _firestore.collection('live_streams').doc();

      // إنشاء بيانات البث المباشر
      final Map<String, dynamic> liveStreamData = {
        'id': docRef.id,
        'title': title,
        'broadcasterId': user.uid,
        'broadcasterName': broadcasterName,
        'thumbnailUrl': thumbnailUrl ?? '',
        'viewerCount': 0,
        'isLive': true,
        'status': 'live',
        'startedAt': Timestamp.fromDate(DateTime.now()),
        'viewers': [],
        'moderators': [user.uid],
        'channelName': generateSessionId(),
      };

      final liveStream = LiveStream(
        id: docRef.id,
        title: title,
        broadcasterId: user.uid,
        broadcasterName: broadcasterName,
        thumbnailUrl: thumbnailUrl ?? '',
        viewerCount: 0,
        isLive: true,
        startedAt: DateTime.now(),
        viewers: [],
        moderators: [user.uid],
        data: liveStreamData,
      );

      await docRef.set(liveStreamData);
      return docRef.id;
    } catch (e) {
      throw Exception('فشل في إنشاء البث المباشر: $e');
    }
  }

  /// إنهاء بث مباشر
  static Future<void> endLiveStream(String streamId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('يجب تسجيل الدخول أولاً');

      final docRef = _firestore.collection('live_streams').doc(streamId);
      final doc = await docRef.get();

      if (!doc.exists) throw Exception('البث المباشر غير موجود');

      final data = doc.data() as Map<String, dynamic>;
      if (data['broadcasterId'] != user.uid &&
          data['astrologist_id'] != user.uid) {
        throw Exception('ليس لديك صلاحية لإنهاء هذا البث');
      }

      await docRef.update({
        'isLive': false,
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('فشل في إنهاء البث المباشر: $e');
    }
  }

  /// إضافة مشاهد
  static Future<void> addViewer(String streamId, String userId) async {
    try {
      final batch = _firestore.batch();
      final streamRef = _firestore.collection('live_streams').doc(streamId);
      final viewerRef = streamRef.collection('live_viewers').doc(userId);

      batch.update(streamRef, {
        'viewers': FieldValue.arrayUnion([userId]),
        'viewerCount': FieldValue.increment(1),
      });

      batch.set(viewerRef, {
        'userId': userId,
        'joinedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'lastActive': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      throw Exception('فشل في إضافة المشاهد: $e');
    }
  }

  /// إزالة مشاهد
  static Future<void> removeViewer(String streamId, String userId) async {
    try {
      final batch = _firestore.batch();
      final streamRef = _firestore.collection('live_streams').doc(streamId);
      final viewerRef = streamRef.collection('live_viewers').doc(userId);

      batch.update(streamRef, {
        'viewers': FieldValue.arrayRemove([userId]),
        'viewerCount': FieldValue.increment(-1),
      });

      batch.update(viewerRef, {
        'isActive': false,
        'leftAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      throw Exception('فشل في إزالة المشاهد: $e');
    }
  }

  /// الحصول على البث المباشر النشط
  static Stream<List<LiveStream>> getLiveStreams() {
    return _firestore
        .collection('live_streams')
        .where('status', isEqualTo: 'live')
        .snapshots()
        .map((snapshot) => LiveStream.fromQuerySnapshot(snapshot));
  }

  /// الحصول على تفاصيل بث مباشر
  static Stream<LiveStream?> getLiveStreamById(String streamId) {
    return _firestore
        .collection('live_streams')
        .doc(streamId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return LiveStream.fromDocumentSnapshot(doc);
    });
  }

  /// تحديث نشاط المشاهد
  static Future<void> updateViewerActivity(
      String streamId, String userId) async {
    try {
      final viewerRef = _firestore
          .collection('live_streams')
          .doc(streamId)
          .collection('live_viewers')
          .doc(userId);

      await viewerRef.update({
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('فشل في تحديث نشاط المشاهد: $e');
    }
  }

  /// مزامنة قائمة المستخدمين البعيدين مع خدمة أجورا
  static void _syncRemoteUsers() {
    // الاشتراك في تغييرات قائمة المستخدمين البعيدين من خدمة أجورا
    AgoraService.remoteUsersList.addListener(() {
      remoteUsers.value = AgoraService.remoteUsersList.value;
    });

    // التحديث الأولي
    remoteUsers.value = AgoraService.remoteUsersList.value;

    // بدء تحديث دوري إذا لزم الأمر
    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!localUserJoined.value) {
        timer.cancel();
        return;
      }

      // تحديث القائمة من خدمة أجورا
      remoteUsers.value = AgoraService.remoteUsersList.value;
    });
  }

  /// مغادرة القناة
  static Future<void> leaveChannel(String channelName) async {
    try {
      print('مغادرة قناة البث المباشر: $channelName');

      // استخدام خدمة أجورا لمغادرة القناة
      await AgoraService.leaveChannel(channelName);

      // إعادة ضبط الحالة
      localUserJoined.value = false;
      remoteUsers.value = [];

      print('تمت مغادرة القناة بنجاح');
    } catch (e) {
      print('خطأ عند مغادرة البث المباشر: $e');
    }
  }

  /// التحكم في تشغيل/إيقاف الكاميرا
  static Future<void> toggleCamera(String channelName,
      {required bool enabled}) async {
    try {
      await AgoraService.toggleCamera(channelName, enabled: enabled);
    } catch (e) {
      print('خطأ في تبديل حالة الكاميرا: $e');
    }
  }

  /// التحكم في تشغيل/إيقاف الميكروفون
  static Future<void> toggleMicrophone(String channelName,
      {required bool enabled}) async {
    try {
      await AgoraService.toggleMicrophone(channelName, enabled: enabled);
    } catch (e) {
      print('خطأ في تبديل حالة الميكروفون: $e');
    }
  }

  /// هل المستخدم منضم للقناة حالياً؟
  static bool isJoined(String channelName) {
    return AgoraService.localUserJoined.value;
  }

  /// الحصول على معلومات عن المستخدمين البعيدين
  static List<int> getRemoteUsers(String channelName) {
    return AgoraService.getRemoteUsers(channelName);
  }

  // للحصول على عدد محاولات الاتصال الحالية
  static int get connectionAttempts => _connectionAttempts;

  /// محاكاة خدمة البث المباشر مع تكوين قواعد Firebase
  static Future<void> simulateLiveStreamWithFirebaseRules(
      String astrologistId) async {
    try {
      print('بدء محاكاة خدمة البث المباشر مع تكوين قواعد Firebase');

      // 1. التحقق من صلاحيات المستخدم
      final userDoc =
          await _firestore.collection('users').doc(astrologistId).get();
      if (!userDoc.exists) {
        print('المستخدم غير موجود: $astrologistId');
        throw Exception('المستخدم غير موجود');
      }

      final userData = userDoc.data();
      if (userData == null || userData['user_type'] != 'astrologer') {
        print('المستخدم ليس منجماً: ${userData?['user_type']}');
        throw Exception('فقط المنجمون يمكنهم إنشاء بث مباشر');
      }

      // 2. إنشاء بث مباشر جديد
      final streamId = await createLiveStream(
        title: 'بث مباشر تجريبي مع قواعد Firebase',
        broadcasterName: userData['first_name'] + ' ' + userData['last_name'],
      );
      print('تم إنشاء البث المباشر: $streamId');

      // 3. التحقق من وجود البث المباشر
      final streamDoc =
          await _firestore.collection('live_streams').doc(streamId).get();
      if (!streamDoc.exists) {
        print('البث المباشر غير موجود: $streamId');
        throw Exception('البث المباشر غير موجود');
      }

      final streamData = streamDoc.data();
      if (streamData == null) {
        print('بيانات البث المباشر غير موجودة');
        throw Exception('بيانات البث المباشر غير موجودة');
      }

      // 4. التحقق من حالة البث المباشر
      if (streamData['status'] != 'live') {
        print('البث المباشر غير نشط: ${streamData['status']}');
        throw Exception('البث المباشر غير نشط حالياً');
      }

      // 7. محاكاة إنهاء البث المباشر
      try {
        // إنهاء البث المباشر
        await endLiveStream(streamId);
        print('تم إنهاء البث المباشر بنجاح');
      } catch (e) {
        print('خطأ في إنهاء البث المباشر: $e');
        throw Exception('فشل في إنهاء البث المباشر: $e');
      }

      print(
          'تم الانتهاء من محاكاة خدمة البث المباشر مع تكوين قواعد Firebase بنجاح');
    } catch (e) {
      print('خطأ في محاكاة خدمة البث المباشر مع تكوين قواعد Firebase: $e');
      rethrow;
    }
  }

  /// الحصول على بيانات البث المباشر حسب المعرف
  static Future<Map<String, dynamic>?> getLiveStream(
      String liveStreamId) async {
    try {
      final doc =
          await _firestore.collection('live_streams').doc(liveStreamId).get();
      if (!doc.exists) {
        print('البث المباشر غير موجود: $liveStreamId');
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;
      print('تم جلب بيانات البث المباشر بنجاح: $liveStreamId');

      // التحقق من القيم الفارغة وتعيين قيم افتراضية
      return {
        'id': liveStreamId,
        'title': data['title']?.toString() ?? 'بث مباشر',
        'description': data['description']?.toString() ?? '',
        'broadcasterId': data['broadcasterId']?.toString() ?? '',
        'astrologistId': data['astrologistId']?.toString() ?? '',
        'broadcasterName': data['broadcasterName']?.toString() ?? 'منجم',
        'status': data['status']?.toString() ?? 'ended',
        'viewerCount': (data['viewerCount'] as num?)?.toInt() ?? 0,
        'createdAt': data['createdAt'] as Timestamp? ?? Timestamp.now(),
        'endedAt': data['endedAt'] as Timestamp?,
        'lastUpdated': data['lastUpdated'] as Timestamp? ?? Timestamp.now(),
        'viewers': List<String>.from(data['viewers'] ?? []),
        'channelName': data['channelName']?.toString() ?? '',
      };
    } catch (e) {
      print('خطأ في جلب بيانات البث المباشر: $e');
      return null;
    }
  }

  /// محاكاة جلسة بث مباشر كاملة للكشف عن الأخطاء المنطقية
  static Future<void> simulateCompleteLiveStreamSession({
    required String astrologerId,
    required List<String> viewerIds,
  }) async {
    try {
      LiveStreamLogService.instance
          .log('=== بدء محاكاة دورة حياة كاملة لجلسة بث مباشر ===');
      String? liveStreamId;
      String? channelName;
      Map<String, dynamic>? userData;

      // 1. التحقق من معلومات المنجم
      LiveStreamLogService.instance
          .log('\n[1] التحقق من معلومات المنجم: $astrologerId');
      try {
        final userDoc =
            await _firestore.collection('users').doc(astrologerId).get();
        if (!userDoc.exists) {
          LiveStreamLogService.instance
              .log('⚠️ خطأ: المستخدم غير موجود: $astrologerId');
          return;
        }
        userData = userDoc.data();
        if (userData == null || userData['user_type'] != 'astrologer') {
          LiveStreamLogService.instance
              .log('⚠️ خطأ: المستخدم ليس منجماً: ${userData?['user_type']}');
          return;
        }
        LiveStreamLogService.instance.log(
            '✅ التحقق من المنجم ناجح: ${userData['first_name']} ${userData['last_name']}');
      } catch (e) {
        LiveStreamLogService.instance.log('⚠️ خطأ في التحقق من المنجم: $e');
        return;
      }

      // 2. إنشاء بث مباشر جديد
      LiveStreamLogService.instance.log('\n[2] إنشاء بث مباشر جديد');
      try {
        // التحقق إذا كان المنجم لديه بث مباشر نشط بالفعل
        final existingStreams = await _firestore
            .collection('live_streams')
            .where('broadcasterId', isEqualTo: astrologerId)
            .where('status', isEqualTo: 'live')
            .get();

        if (existingStreams.docs.isNotEmpty) {
          LiveStreamLogService.instance.log(
              'ℹ️ المنجم لديه بث مباشر نشط، سيتم استخدامه: ${existingStreams.docs.first.id}');
          liveStreamId = existingStreams.docs.first.id;
          final data = existingStreams.docs.first.data();
          channelName = data['channelName'] ?? data['channel_name'];
          LiveStreamLogService.instance.log('ℹ️ اسم القناة: $channelName');
        } else {
          liveStreamId = await createLiveStream(
              title: 'بث مباشر محاكاة',
              broadcasterName:
                  userData['first_name'] + ' ' + userData['last_name']);
          LiveStreamLogService.instance
              .log('✅ تم إنشاء بث مباشر جديد: $liveStreamId');

          // جلب معلومات البث المباشر المنشأ
          final streamDoc = await _firestore
              .collection('live_streams')
              .doc(liveStreamId)
              .get();
          final data = streamDoc.data();
          channelName = data?['channelName'] ?? data?['channel_name'];
          LiveStreamLogService.instance.log('ℹ️ اسم القناة: $channelName');
        }
      } catch (e) {
        LiveStreamLogService.instance.log('⚠️ خطأ في إنشاء البث المباشر: $e');
        return;
      }

      // 3. محاكاة انضمام المذيع للبث
      LiveStreamLogService.instance.log('\n[3] محاكاة انضمام المذيع للبث');
      try {
        final joined =
            await joinLiveStreamChannel(liveStreamId, isBroadcaster: true);
        LiveStreamLogService.instance.log(joined
            ? '✅ انضم المذيع للبث بنجاح'
            : '⚠️ فشل المذيع في الانضمام للبث');

        if (!joined) {
          LiveStreamLogService.instance
              .log('⚠️ خطأ منطقي: فشل المذيع في الانضمام لبثه الخاص!');
        }
      } catch (e) {
        LiveStreamLogService.instance.log('⚠️ خطأ في انضمام المذيع: $e');
      }

      // 4. محاكاة انضمام المشاهدين
      LiveStreamLogService.instance.log('\n[4] محاكاة انضمام المشاهدين');
      Map<String, bool> viewerStatus = {};

      for (final viewerId in viewerIds) {
        try {
          LiveStreamLogService.instance.log('محاولة إضافة مشاهد: $viewerId');

          // التحقق من وجود المشاهد كمستخدم
          final userDoc =
              await _firestore.collection('users').doc(viewerId).get();
          if (!userDoc.exists) {
            LiveStreamLogService.instance
                .log('⚠️ المشاهد غير موجود: $viewerId');
            continue;
          }

          // محاولة إضافة المشاهد
          await addViewer(liveStreamId, viewerId);
          LiveStreamLogService.instance
              .log('✅ تمت إضافة المشاهد بنجاح: $viewerId');

          // التحقق من الإضافة الفعلية
          final streamDoc = await _firestore
              .collection('live_streams')
              .doc(liveStreamId)
              .get();
          final viewers =
              (streamDoc.data()?['viewers'] as List<dynamic>?) ?? [];

          if (viewers.contains(viewerId)) {
            LiveStreamLogService.instance
                .log('✅ تم التحقق: المشاهد موجود في قائمة المشاهدين');
            viewerStatus[viewerId] = true;
          } else {
            LiveStreamLogService.instance.log(
                '⚠️ خطأ منطقي: المشاهد تمت إضافته لكنه غير موجود في قائمة المشاهدين!');
            viewerStatus[viewerId] = false;
          }

          // التحقق من وجود المشاهد في المجموعة الفرعية
          final viewerDocRef = _firestore
              .collection('live_streams')
              .doc(liveStreamId)
              .collection('live_viewers')
              .doc(viewerId);

          final viewerDoc = await viewerDocRef.get();
          if (viewerDoc.exists) {
            LiveStreamLogService.instance
                .log('✅ المشاهد موجود في المجموعة الفرعية للمشاهدين');
          } else {
            LiveStreamLogService.instance.log(
                '⚠️ خطأ منطقي: المشاهد غير موجود في المجموعة الفرعية للمشاهدين!');
          }

          // التحقق من عدد المشاهدين
          final viewerCount = streamDoc.data()?['viewerCount'] ?? 0;
          LiveStreamLogService.instance
              .log('ℹ️ عدد المشاهدين الحالي: $viewerCount');

          await Future.delayed(const Duration(seconds: 1));
        } catch (e) {
          LiveStreamLogService.instance
              .log('⚠️ خطأ في إضافة المشاهد $viewerId: $e');
          viewerStatus[viewerId] = false;
        }
      }

      LiveStreamLogService.instance.log('\nملخص حالة المشاهدين:');
      viewerStatus.forEach((viewerId, success) {
        LiveStreamLogService.instance.log(
            '${success ? '✅' : '❌'} $viewerId: ${success ? 'تمت الإضافة بنجاح' : 'فشل في الإضافة'}');
      });

      // 5. محاكاة مغادرة المشاهدين
      LiveStreamLogService.instance.log('\n[5] محاكاة مغادرة المشاهدين');
      for (final viewerId in viewerIds) {
        try {
          if (viewerStatus[viewerId] != true) {
            LiveStreamLogService.instance
                .log('⚠️ تخطي المشاهد $viewerId لأنه لم يتم إضافته بنجاح');
            continue;
          }

          LiveStreamLogService.instance.log('محاولة إزالة المشاهد: $viewerId');
          await removeViewer(liveStreamId, viewerId);
          LiveStreamLogService.instance
              .log('✅ تمت إزالة المشاهد بنجاح: $viewerId');

          // التحقق من الإزالة الفعلية
          final streamDoc = await _firestore
              .collection('live_streams')
              .doc(liveStreamId)
              .get();
          final viewers =
              (streamDoc.data()?['viewers'] as List<dynamic>?) ?? [];

          if (!viewers.contains(viewerId)) {
            LiveStreamLogService.instance
                .log('✅ تم التحقق: المشاهد غير موجود في قائمة المشاهدين');
          } else {
            LiveStreamLogService.instance.log(
                '⚠️ خطأ منطقي: المشاهد تمت إزالته لكنه لا يزال موجوداً في قائمة المشاهدين!');
          }

          // التحقق من عدم وجود المشاهد في المجموعة الفرعية
          final viewerDocRef = _firestore
              .collection('live_streams')
              .doc(liveStreamId)
              .collection('live_viewers')
              .doc(viewerId);

          final viewerDoc = await viewerDocRef.get();
          if (!viewerDoc.exists) {
            LiveStreamLogService.instance
                .log('✅ المشاهد غير موجود في المجموعة الفرعية للمشاهدين');
          } else {
            LiveStreamLogService.instance.log(
                '⚠️ خطأ منطقي: المشاهد لا يزال موجوداً في المجموعة الفرعية للمشاهدين!');
          }

          await Future.delayed(const Duration(seconds: 1));
        } catch (e) {
          LiveStreamLogService.instance
              .log('⚠️ خطأ في إزالة المشاهد $viewerId: $e');
        }
      }

      // 6. إنهاء البث المباشر
      LiveStreamLogService.instance.log('\n[6] إنهاء البث المباشر');
      try {
        await endLiveStream(liveStreamId);
        LiveStreamLogService.instance.log('✅ تم إنهاء البث المباشر بنجاح');

        // التحقق من حالة البث
        final streamDoc =
            await _firestore.collection('live_streams').doc(liveStreamId).get();
        final status = streamDoc.data()?['status'];

        if (status == 'ended') {
          LiveStreamLogService.instance
              .log('✅ تم التحقق: حالة البث المباشر هي "ended"');
        } else {
          LiveStreamLogService.instance.log(
              '⚠️ خطأ منطقي: حالة البث المباشر هي "$status" وليس "ended"!');
        }
      } catch (e) {
        LiveStreamLogService.instance.log('⚠️ خطأ في إنهاء البث المباشر: $e');
      }

      LiveStreamLogService.instance
          .log('\n=== انتهت محاكاة دورة حياة البث المباشر ===');
    } catch (e) {
      LiveStreamLogService.instance
          .log('⚠️ خطأ عام في محاكاة البث المباشر: $e');
    } finally {
      // إعادة ضبط الحالة بغض النظر عن نتيجة المحاكاة
      resetServiceState();
    }
  }

  /// إزالة مشاهد من البث المباشر
  static Future<bool> removeViewerFromStream(
      String liveStreamId, String userId) async {
    try {
      if (liveStreamId.isEmpty || userId.isEmpty) {
        debugPrint(
            'لا يمكن إزالة المشاهد: معرف البث المباشر أو معرف المستخدم فارغ');
        return false;
      }

      // معالجة معرفات المستخدمين غير الصالحة
      String safeUserId = userId;
      if (userId.startsWith('bt3h9as1')) {
        debugPrint('معرف المستخدم غير صالح للإزالة: $userId');
        // البحث عن معرف المستخدم البديل بنمط anonymous_*
        String? anonymousId =
            await _findAnonymousIdForUser(liveStreamId, userId);
        if (anonymousId != null) {
          safeUserId = anonymousId;
          debugPrint('تم العثور على معرف بديل: $safeUserId');
        }
      }

      DocumentReference liveStreamDocRef = FirebaseFirestore.instance
          .collection('live_streams')
          .doc(liveStreamId);

      DocumentSnapshot liveStreamDoc = await liveStreamDocRef.get();
      if (!liveStreamDoc.exists) {
        debugPrint('لا يمكن إزالة المشاهد: البث المباشر غير موجود');
        return false;
      }

      List<dynamic> viewers = liveStreamDoc.get('viewers') ?? [];

      // إزالة المشاهد فقط إذا كان موجودًا في القائمة
      if (viewers.contains(safeUserId)) {
        // إزالة المشاهد من مصفوفة المشاهدين وتقليل عدد المشاهدين
        await liveStreamDocRef.update({
          'viewers': FieldValue.arrayRemove([safeUserId]),
          'viewerCount': FieldValue.increment(-1),
        });

        // تحديث حالة المشاهد في المجموعة الفرعية
        DocumentReference viewerDocRef =
            liveStreamDocRef.collection('live_viewers').doc(safeUserId);

        DocumentSnapshot viewerDoc = await viewerDocRef.get();
        if (viewerDoc.exists) {
          await viewerDocRef.update({
            'isActive': false,
            'leftAt': FieldValue.serverTimestamp(),
          });
        }

        debugPrint('تمت إزالة المشاهد بنجاح: $safeUserId');
      } else {
        debugPrint('لم يتم العثور على المشاهد في قائمة المشاهدين: $safeUserId');
      }

      return true;
    } catch (e) {
      debugPrint('خطأ في إزالة المشاهد: $e');
      return false;
    }
  }

  /// البحث عن معرف المستخدم البديل (anonymous_*)
  static Future<String?> _findAnonymousIdForUser(
      String liveStreamId, String originalId) async {
    try {
      final liveStreamDoc = await FirebaseFirestore.instance
          .collection('live_streams')
          .doc(liveStreamId)
          .get();

      if (!liveStreamDoc.exists) return null;

      List<dynamic> viewers = liveStreamDoc.get('viewers') ?? [];

      // البحث عن معرف يبدأ بـ anonymous_
      for (var viewerId in viewers) {
        if (viewerId != null && viewerId.toString().startsWith('anonymous_')) {
          return viewerId.toString();
        }
      }

      return null;
    } catch (e) {
      debugPrint('خطأ في البحث عن معرف بديل: $e');
      return null;
    }
  }

  /// إضافة مشاهد إلى البث المباشر
  static Future<bool> addViewerToStream(
      String liveStreamId, String userId) async {
    try {
      if (liveStreamId.isEmpty || userId.isEmpty) {
        debugPrint(
            'لا يمكن إضافة مشاهد: معرف البث المباشر أو معرف المستخدم فارغ');
        return false;
      }

      // التحقق من صحة معرف المستخدم
      if (userId.contains(' ') ||
          userId.startsWith('bt3h9as1') && !userId.contains('-')) {
        debugPrint('معرف المستخدم غير صالح: $userId');
        // إصلاح معرف المستخدم إذا كان يبدأ بـ bt3h9as1
        if (userId.startsWith('bt3h9as1')) {
          // استخدام معرف بديل آمن
          userId = 'anonymous_${DateTime.now().millisecondsSinceEpoch}';
          debugPrint('تم استبدال معرف المستخدم بمعرف آمن: $userId');
        } else {
          return false;
        }
      }

      DocumentReference liveStreamDocRef = FirebaseFirestore.instance
          .collection('live_streams')
          .doc(liveStreamId);

      DocumentSnapshot liveStreamDoc = await liveStreamDocRef.get();
      if (!liveStreamDoc.exists) {
        debugPrint('لا يمكن إضافة مشاهد: البث المباشر غير موجود');
        return false;
      }

      List<dynamic> viewers = liveStreamDoc.get('viewers') ?? [];

      if (!viewers.contains(userId)) {
        // تحديث المستند الرئيسي بإضافة المشاهد وزيادة عدد المشاهدين
        await liveStreamDocRef.update({
          'viewers': FieldValue.arrayUnion([userId]),
          'viewerCount': FieldValue.increment(1),
        });

        // إضافة وثيقة المشاهد في المجموعة الفرعية
        await liveStreamDocRef.collection('live_viewers').doc(userId).set({
          'userId': userId,
          'joinedAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
          'isActive': true,
        });

        debugPrint('تمت إضافة المشاهد بنجاح: $userId');
      } else {
        // تحديث حالة المشاهد إذا كان موجودًا بالفعل
        await liveStreamDocRef.collection('live_viewers').doc(userId).update({
          'lastActive': FieldValue.serverTimestamp(),
          'isActive': true,
        });
        debugPrint('تم تحديث حالة المشاهد الموجود بالفعل: $userId');
      }

      return true;
    } catch (e) {
      debugPrint('خطأ في إضافة المشاهد: $e');
      return false;
    }
  }

  /// التحقق من صلاحية معرف البث المباشر
  static bool isValidLiveStreamId(String? liveStreamId) {
    if (liveStreamId == null || liveStreamId.isEmpty) {
      return false;
    }
    return true;
  }
}
