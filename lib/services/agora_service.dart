import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'token_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'agora_token_server.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'dart:math';
import 'live_stream_service.dart';

/// كلاس تكوين Agora
class AgoraConfig {
  // معرف التطبيق من لوحة تحكم Agora
  static final String appId =
      dotenv.env['AGORA_APP_ID'] ?? "45aba7aeffe344768f07b78a9a93bfff";

  // شهادة التطبيق (للحماية)
  static final String appCertificate =
      dotenv.env['AGORA_APP_CERTIFICATE'] ?? "45aba7aeffe344768f07b78a9a93bfff";

  /// رابط خادم التوكن
  static String _tokenServerUrl = '';

  /// استخدام مصادقة التوكن
  static bool useTokenAuth = true;

  /// ضبط عنوان خادم التوكن
  static set tokenServerUrl(String url) {
    _tokenServerUrl = url;
  }

  /// الحصول على عنوان خادم التوكن
  static String get tokenServerUrl => _tokenServerUrl;

  // تعيين عنوان خادم التوكن
  static void setTokenServerUrl(String url) {
    _tokenServerUrl = url;
    print('تم تعيين عنوان خادم التوكن إلى: $url');
  }

  // هل تم التكوين بشكل صحيح؟
  static bool get isConfigured => appId.isNotEmpty && appCertificate.isNotEmpty;
}

/// واجهة وسيطة لتسهيل التعامل مع Agora SDK
class AgoraService {
  static String? tokenServerUrl = 'http://localhost:3000/token';
  static final AgoraService _instance = AgoraService._internal();
  static RtcEngine? _engine;
  static final List<String> _activeChannels = [];
  static bool _isInitialized = false;
  static bool _isInTemporaryMode = false;

  static final Set<int> _activeUsers = {};
  static final ValueNotifier<bool> localUserJoined = ValueNotifier<bool>(false);
  static final ValueNotifier<List<int>> remoteUsersList =
      ValueNotifier<List<int>>([]);

  // منع تهيئة متعددة متزامنة
  static const bool _isInitializing = false;
  static bool _disposed = false;

  /// الحصول على محرك الـ RTC
  static RtcEngine? get engine => _engine;

  /// القناة الحالية
  static String? _currentChannel;

  factory AgoraService() {
    return _instance;
  }

  AgoraService._internal();

  // إعادة ضبط حالة الخدمة للاختبار
  static void resetServiceState() {
    // تنظيف الحالة ولكن لا نتخلص من المحرك
    _activeUsers.clear();
    _activeChannels.clear();
    localUserJoined.value = false;
    remoteUsersList.value = [];
  }

  /// بدء المحرك وتهيئته
  static Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      print('🚀 بدء تهيئة محرك Agora...');

      // التحقق من وجود معرف التطبيق
      if (dotenv.env['AGORA_APP_ID'] == null ||
          dotenv.env['AGORA_APP_ID']!.isEmpty) {
        throw Exception('لم يتم العثور على معرف تطبيق Agora في ملف .env');
      }

      // تهيئة المحرك
      _engine = createAgoraRtcEngine();
      await _engine?.initialize(RtcEngineContext(
        appId: dotenv.env['AGORA_APP_ID']!,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        areaCode: 0xFFFFFFFF, // Global area code
      ));

      if (kIsWeb) {
        await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);
      }

      _isInitialized = true;
      _isInTemporaryMode = false;
      print('✅ تم تهيئة محرك Agora بنجاح');
      return true;
    } catch (e) {
      print('❌ خطأ في تهيئة محرك Agora: $e');
      rethrow;
    }
  }

  /// إعداد محرك Agora وتفعيل الوسائط
  static Future<void> _setupAgoraEngine() async {
    if (_engine == null) {
      print('خطأ: محرك Agora غير مهيأ');
      return;
    }

    try {
      // تمكين الفيديو
      await _engine!.enableVideo();
      print('تم تمكين الفيديو');

      // تمكين الصوت
      await _engine!.enableAudio();
      print('تم تمكين الصوت');

      // ضبط أولوية البث المنخفضة التأخير
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      print('تم تعيين دور العميل كمذيع');

      // تعيين معلمات الفيديو
      await _engine!.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 640, height: 480),
          frameRate: 15,
          bitrate: 800,
        ),
      );
      print('تم ضبط تكوين الفيديو');
    } catch (e) {
      print('خطأ في إعداد محرك Agora: $e');
    }
  }

  /// تهيئة المحرك وتسجيل الأحداث
  static void _setEventHandlers() {
    try {
      _engine?.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            print('انضم المستخدم المحلي إلى القناة: ${connection.channelId}');
            localUserJoined.value = true;
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            print('انضم مستخدم بعيد: $remoteUid');
            _activeUsers.add(remoteUid);
            remoteUsersList.value = _activeUsers.toList();
          },
          onUserOffline: (connection, remoteUid, reason) {
            print('غادر مستخدم بعيد: $remoteUid');
            _activeUsers.remove(remoteUid);
            remoteUsersList.value = _activeUsers.toList();
          },
          onTokenPrivilegeWillExpire: (connection, token) async {
            print('توكن على وشك انتهاء الصلاحية، جاري تجديده...');
            // تجديد التوكن
            final String channelId = connection.channelId ?? "";
            if (channelId.isNotEmpty) {
              final newToken = await TokenService.getToken(channelId);
              if (newToken != null && newToken.isNotEmpty && _engine != null) {
                await _engine!.renewToken(newToken);
              }
            }
          },
          onError: (err, msg) {
            print('خطأ من محرك Agora: $err - $msg');

            // معالجة الأخطاء المختلفة
            switch (err) {
              case ErrorCodeType.errInvalidToken:
                print('خطأ: التوكن غير صالح. سيتم استخدام وضع المحاكاة.');
                _isInTemporaryMode = true;
                break;

              case ErrorCodeType.errTokenExpired:
                print('خطأ: انتهت صلاحية التوكن. سيتم استخدام وضع المحاكاة.');
                _isInTemporaryMode = true;
                break;

              case ErrorCodeType.errNotReady:
                print('خطأ: الخادم غير جاهز. سيتم استخدام وضع المحاكاة.');
                _isInTemporaryMode = true;
                break;

              case ErrorCodeType.errInvalidAppId:
                print('خطأ: معرف التطبيق غير صالح. سيتم استخدام وضع المحاكاة.');
                _isInTemporaryMode = true;
                break;

              case ErrorCodeType.errInvalidChannelName:
                print('خطأ: اسم القناة غير صالح. سيتم استخدام وضع المحاكاة.');
                _isInTemporaryMode = true;
                break;

              default:
                print('خطأ غير معروف: $err - $msg');
                // تفعيل الوضع المؤقت لمعظم الأخطاء للتسامح مع الأخطاء
                _isInTemporaryMode = true;
            }
          },
        ),
      );
    } catch (e) {
      print('خطأ في تسجيل معالجات الأحداث: $e');
      // تعيين الوضع المؤقت في حالة وجود مشكلة في تسجيل معالجات الأحداث
      _isInTemporaryMode = true;
    }
  }

  /// الحصول على قائمة المستخدمين البعيدين
  static List<int> getRemoteUsers(String channelName) {
    return _activeUsers.toList();
  }

  /// الانضمام إلى قناة البث المباشر مع تحديث قاعدة البيانات
  static Future<bool> joinLiveStreamChannel(
    String channelName,
    String userId,
    String liveStreamId, {
    required bool isBroadcaster,
  }) async {
    try {
      if (channelName.isEmpty || userId.isEmpty || liveStreamId.isEmpty) {
        debugPrint('❌ معلومات القناة أو المستخدم أو البث المباشر غير كاملة');
        return false;
      }

      // الانضمام إلى القناة باستخدام محرك Agora
      bool joined = await joinChannel(
        channelName: channelName,
        uid: 0, // استخدام معرف افتراضي
        isBroadcaster: isBroadcaster,
      );

      if (!joined) {
        debugPrint('❌ فشل في الانضمام إلى قناة Agora');
        return false;
      }

      // إذا كان المستخدم مشاهدًا (وليس مذيعًا)، أضفه إلى قائمة المشاهدين
      if (!isBroadcaster) {
        bool viewerAdded = await LiveStreamService.addViewerToStream(
          liveStreamId,
          userId,
        );

        if (!viewerAdded) {
          debugPrint('⚠️ تم الانضمام إلى القناة ولكن فشل في إضافة المشاهد');
          // استمر على أي حال لأن المستخدم انضم بنجاح إلى القناة
        } else {
          debugPrint('✅ تم إضافة المشاهد بنجاح إلى البث المباشر');
        }
      } else {
        debugPrint('✅ المذيع انضم إلى البث المباشر');
      }

      return true;
    } catch (e) {
      debugPrint('❌ خطأ في الانضمام إلى قناة البث المباشر: $e');
      return false;
    }
  }

  /// مغادرة القناة
  static Future<void> leaveChannel(String channelName) async {
    if (!_activeChannels.contains(channelName)) {
      print('لم يتم الانضمام إلى القناة: $channelName');
      return;
    }

    try {
      print('مغادرة القناة: $channelName');

      // إذا كنا في الوضع المؤقت، فقط إعادة ضبط الحالة
      if (_isInTemporaryMode) {
        _activeChannels.remove(channelName);
        localUserJoined.value = false;
        _activeUsers.clear();
        remoteUsersList.value = [];
        return;
      }

      // إيقاف البث المحلي إذا كان هذا آخر قناة نشطة
      if (_activeChannels.length == 1 && _engine != null) {
        try {
          await _engine!.enableLocalAudio(false);
          await _engine!.enableLocalVideo(false);
          print('تم إيقاف البث المحلي قبل مغادرة القناة');
        } catch (e) {
          print('خطأ عند إيقاف البث المحلي: $e');
        }
      }

      // إذا كان المحرك مهيأ، قم بمغادرة القناة
      if (_engine != null && _isInitialized) {
        try {
          await _engine!.leaveChannel();
          print('تمت مغادرة القناة بنجاح');
        } catch (e) {
          print('فشل في مغادرة القناة: $e');
        }
      }

      _activeChannels.remove(channelName);
      _activeUsers.clear();
      localUserJoined.value = false;
      remoteUsersList.value = [];

      // إذا لم تعد هناك قنوات نشطة، قم بإيقاف المعاينة
      if (_activeChannels.isEmpty && _engine != null) {
        try {
          await _engine!.stopPreview();
          print('تم إيقاف المعاينة بنجاح');
        } catch (e) {
          print('خطأ عند إيقاف المعاينة: $e');
        }
      }

      print('تمت مغادرة القناة بنجاح');
    } catch (e) {
      print('خطأ عند مغادرة القناة: $e');
    }
  }

  /// تفعيل أو تعطيل الكاميرا
  static Future<bool> toggleCamera(String channelName, {bool? enabled}) async {
    try {
      if (_engine == null || !_isInitialized) {
        print('محرك Agora غير مهيأ');
        return false;
      }

      if (enabled != null) {
        await _engine!.enableLocalVideo(enabled);
        print('تم ${enabled ? "تفعيل" : "تعطيل"} الكاميرا المحلية');
      } else {
        await _engine!.enableLocalVideo(true);
        print('تم تفعيل الكاميرا المحلية');
      }
      return true;
    } catch (e) {
      print('خطأ في التحكم في الكاميرا: $e');
      return false;
    }
  }

  /// تفعيل أو تعطيل الميكروفون
  static Future<bool> toggleMicrophone(String channelName,
      {bool? enabled}) async {
    try {
      if (_engine == null || !_isInitialized) {
        print('محرك Agora غير مهيأ');
        return false;
      }

      if (enabled != null) {
        await _engine!.enableLocalAudio(enabled);
        print('تم ${enabled ? "تفعيل" : "تعطيل"} الميكروفون المحلي');
      } else {
        await _engine!.enableLocalAudio(true);
        print('تم تفعيل الميكروفون المحلي');
      }
      return true;
    } catch (e) {
      print('خطأ في التحكم في الميكروفون: $e');
      return false;
    }
  }

  /// التخلص من المحرك وتحرير الموارد
  static Future<void> dispose() async {
    if (_disposed) return;

    try {
      for (final channel in _activeChannels.toList()) {
        await leaveChannel(channel);
      }

      if (_engine != null) {
        await _engine!.release();
        _engine = null;
      }

      _isInitialized = false;
      _disposed = true;
      _isInTemporaryMode = false;
      resetServiceState();
    } catch (e) {
      print('خطأ عند التخلص من محرك Agora: $e');
    }
  }

  /// الحصول على توكن من خادم Agora
  static Future<String?> getToken({
    required String channelName,
    required int uid,
    required int role,
  }) async {
    try {
      print('🔑 جاري طلب توكن للقناة: $channelName');

      // زيادة عدد المحاولات لمعالجة مشاكل الشبكة
      const int maxRetries = 3;
      for (int i = 0; i < maxRetries; i++) {
        try {
          // تجربة عناوين مختلفة للخادم
          final String serverUrl = i == 0
              ? 'http://localhost:3000/token'
              : i == 1
                  ? 'http://127.0.0.1:3000/token'
                  : 'http://10.0.2.2:3000/token'; // للمحاكي

          print(
              '🌐 محاولة الاتصال بخادم التوكن: $serverUrl (محاولة ${i + 1}/$maxRetries)');

          final response = await http.get(
            Uri.parse(
                '$serverUrl?channelName=$channelName&uid=$uid&role=$role'),
            headers: {'Content-Type': 'application/json'},
          ).timeout(const Duration(seconds: 3));

          print('📡 استجابة خادم التوكن - رمز الحالة: ${response.statusCode}');

          if (response.statusCode == 200) {
            final responseData = json.decode(response.body);
            print('📡 استجابة خادم التوكن - المحتوى:\n${response.body}');

            if (responseData['token'] != null) {
              print('✅ تم الحصول على توكن بنجاح');
              return responseData['token'];
            } else {
              print('⚠️ استجابة الخادم لا تحتوي على توكن');
            }
          } else {
            print('⚠️ فشل الاتصال بالخادم، رمز الحالة: ${response.statusCode}');
          }
        } catch (e) {
          print('⚠️ خطأ في الاتصال بالخادم على المحاولة ${i + 1}: $e');
          if (i < maxRetries - 1) {
            await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
          }
        }
      }

      // في حالة الفشل في الاتصال بخادم التوكن، استخدم توكن مؤقت في وضع التطوير
      print('⚠️ استخدام توكن مؤقت في وضع التطوير');
      return _generateTemporaryToken(channelName);
    } catch (e) {
      print('❌ خطأ في الحصول على التوكن: $e');
      // استخدام توكن مؤقت في وضع التطوير
      print('⚠️ استخدام توكن مؤقت في وضع التطوير');
      return _generateTemporaryToken(channelName);
    }
  }

  /// إنشاء توكن مؤقت للاستخدام في وضع التطوير
  static String _generateTemporaryToken(String channelName) {
    final appId = dotenv.env['AGORA_APP_ID'] ?? '';
    // توكن مؤقت يستخدم فقط في وضع التطوير
    return '006$appId' +
        'IAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' +
        'AAAAAEAAb4BxQEAAQB+w/FoXOM=';
  }

  /// هل النظام في وضع التطوير
  static bool get isInDevMode {
    bool inDebugMode = false;
    assert(inDebugMode = true);
    return inDebugMode;
  }

  /// الانضمام إلى القناة بوضع محاكاة مؤقت
  static Future<bool> _joinChannelInTemporaryMode(
      String? channelName, bool isBroadcaster) async {
    if (channelName == null || channelName.isEmpty) {
      print('خطأ: اسم القناة فارغ في وضع المحاكاة');
      return false;
    }

    print('استخدام الوضع المؤقت للانضمام إلى القناة: $channelName');
    try {
      // محاكاة وقت الانضمام
      await Future.delayed(const Duration(milliseconds: 500));

      // محاكاة الانضمام إلى القناة دون استخدام SDK الفعلي
      _activeChannels.add(channelName);
      localUserJoined.value = true;

      // إضافة بعض المستخدمين الوهميين للمشاهدين
      if (!isBroadcaster) {
        final fakeUid = Random().nextInt(100000) + 1000;
        _activeUsers.add(fakeUid);
        remoteUsersList.value = _activeUsers.toList();
      }

      print('تم الانضمام إلى القناة بنجاح بالوضع المؤقت');
      return true;
    } catch (e) {
      print('خطأ في الانضمام إلى القناة بالوضع المؤقت: $e');
      return false;
    }
  }

  /// التحقق من الاتصال بالإنترنت
  static Future<bool> checkInternetConnection() async {
    try {
      final response = await http.get(Uri.parse('https://www.google.com'));
      return response.statusCode == 200;
    } catch (e) {
      print('خطأ في التحقق من الاتصال بالإنترنت: $e');
      return false;
    }
  }

  /// حالة الوضع المؤقت
  static bool get isInTemporaryMode => _isInTemporaryMode;

  /// الانضمام إلى القناة محددة
  static Future<bool> joinChannel({
    required String channelName,
    required int uid,
    required bool isBroadcaster,
  }) async {
    try {
      if (_engine == null) {
        print('🔄 محرك Agora RTC غير مهيأ، جاري التهيئة...');
        await initialize();
      }

      if (channelName.isEmpty) {
        throw Exception('اسم القناة غير صالح');
      }

      final token = await getToken(
        channelName: channelName,
        uid: uid,
        role: isBroadcaster ? 1 : 2,
      );

      if (token == null) {
        print('⚠️ استخدام توكن فارغ في وضع التطوير');
      }

      await _engine!.setClientRole(
        role: isBroadcaster
            ? ClientRoleType.clientRoleBroadcaster
            : ClientRoleType.clientRoleAudience,
      );
      print('✅ تم تعيين دور المستخدم: ${isBroadcaster ? "مذيع" : "مشاهد"}');

      print('⚙️ تكوين القناة:');
      print('  - التوكن: ${token?.substring(0, 15)}...');

      print(
          '🔄 محاولة الانضمام إلى القناة $channelName كـ ${isBroadcaster ? "مذيع" : "مشاهد"}');
      await _engine!.joinChannel(
        token: token ?? '',
        channelId: channelName,
        uid: uid,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );

      _activeChannels.add(channelName);
      print('✅ تم الانضمام إلى القناة بنجاح: $channelName');
      return true;
    } catch (e) {
      print('❌ خطأ في الانضمام إلى القناة: $e');
      return false;
    }
  }
}
