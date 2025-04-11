import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class AgoraWebService {
  static RtcEngine? _engine;
  static bool _isInitialized = false;
  static bool _hasVideoPermission = false;
  static bool _hasAudioPermission = false;

  static RtcEngine? get engine => _engine;
  static bool get hasVideoPermission => _hasVideoPermission;
  static bool get hasAudioPermission => _hasAudioPermission;
  static bool get isInitialized => _isInitialized;

  /// طلب أذونات الكاميرا والميكروفون في بيئة الويب
  static Future<bool> requestPermissions() async {
    if (!kIsWeb) return true;

    try {
      if (!_isInitialized) {
        await initialize();
      }

      print('🔒 طلب أذونات الكاميرا والميكروفون في بيئة الويب');

      // تمكين الفيديو والصوت سيؤدي إلى طلب الأذونات تلقائياً
      await _engine?.enableVideo();
      await _engine?.enableAudio();

      // إضافة تأخير قصير للتأكد من أن مربع حوار الأذونات ظهر وتمت معالجته
      await Future.delayed(const Duration(milliseconds: 500));

      _hasVideoPermission = true;
      _hasAudioPermission = true;

      print('✅ تم منح أذونات الكاميرا والميكروفون');
      return true;
    } catch (e) {
      print('❌ خطأ في طلب الأذونات: $e');
      return false;
    }
  }

  /// تهيئة محرك Agora RTC للويب
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🚀 بدء تهيئة محرك Agora للويب...');

      final appId = dotenv.env['AGORA_APP_ID'];
      if (appId == null || appId.isEmpty) {
        throw Exception('لم يتم العثور على معرف تطبيق Agora في ملف .env');
      }

      // إنشاء محرك RTC - تخطي الاختبارات للويب
      if (kIsWeb) {
        _engine = createAgoraRtcEngine();
        await _engine?.initialize(RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ));
      }

      // إعداد معالجات الأحداث
      _setupEventHandlers();

      _isInitialized = true;
      print('✅ تم تهيئة محرك Agora للويب بنجاح');
    } catch (e) {
      print('❌ خطأ في تهيئة محرك Agora للويب: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  /// إعداد معالجات أحداث محرك Agora
  static void _setupEventHandlers() {
    if (_engine == null) return;

    _engine?.registerEventHandler(
      RtcEngineEventHandler(
        onError: (err, msg) {
          print('❌ خطأ Agora: $err - $msg');
        },
        onJoinChannelSuccess: (connection, elapsed) {
          print('✅ تم الانضمام للقناة بنجاح: ${connection.channelId}');
        },
        onUserJoined: (connection, uid, elapsed) {
          print('👤 انضم مستخدم: $uid');
        },
        onUserOffline: (connection, uid, reason) {
          print('👤 غادر مستخدم: $uid - السبب: $reason');
        },
        onLeaveChannel: (connection, stats) {
          print('👋 تمت مغادرة القناة: ${connection.channelId}');
        },
      ),
    );
  }

  /// الانضمام إلى قناة البث المباشر
  static Future<bool> joinChannel({
    required String channelName,
    required String token,
    required bool isBroadcaster,
    int uid = 0,
  }) async {
    if (!_isInitialized) {
      try {
        await initialize();
      } catch (e) {
        print('❌ فشل في تهيئة محرك Agora: $e');
        return false;
      }
    }

    try {
      // تعيين دور المستخدم
      final role = isBroadcaster
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience;

      await _engine?.setClientRole(role: role);

      // تكوين خيارات البث
      final options = ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: role,
        publishCameraTrack: isBroadcaster,
        publishMicrophoneTrack: isBroadcaster,
        autoSubscribeVideo: true,
        autoSubscribeAudio: true,
      );

      // الانضمام إلى القناة
      await _engine?.joinChannel(
        token: token,
        channelId: channelName,
        uid: uid,
        options: options,
      );

      return true;
    } catch (e) {
      print('❌ خطأ في الانضمام إلى القناة: $e');
      return false;
    }
  }

  /// مغادرة القناة الحالية
  static Future<void> leaveChannel() async {
    if (_engine != null && _isInitialized) {
      await _engine?.leaveChannel();
    }
  }

  /// تحرير الموارد وإيقاف محرك Agora
  static Future<void> dispose() async {
    if (_engine != null) {
      await _engine?.release();
      _engine = null;
      _isInitialized = false;
      _hasVideoPermission = false;
      _hasAudioPermission = false;
    }
  }
}
