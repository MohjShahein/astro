import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/agora_service.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import '../services/live_stream_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/live_stream_log_service.dart';
import '../models/live_stream.dart';
import '../models/live_chat_message.dart';
import '../models/live_viewer.dart';
import '../providers/live_viewers_provider.dart';
import '../providers/live_chat_provider.dart';
import '../models/chat_message.dart';
import 'dart:io';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/agora_web_service.dart';

class SimpleLiveStreamPage extends StatefulWidget {
  final Map<String, dynamic> liveStreamData;
  final bool isBroadcaster;
  final String liveStreamId;
  final String userId;

  const SimpleLiveStreamPage({
    Key? key,
    required this.liveStreamData,
    required this.isBroadcaster,
    required this.liveStreamId,
    required this.userId,
  }) : super(key: key);

  @override
  State<SimpleLiveStreamPage> createState() => _SimpleLiveStreamPageState();
}

class _SimpleLiveStreamPageState extends State<SimpleLiveStreamPage> {
  RtcEngine? _engine;
  bool _isInitialized = false;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isCameraOn = true;
  bool _isMicOn = true;
  int _remoteUid = 0;
  bool _isJoined = false;
  late String _channelName;
  late int _localUid;
  bool _isLocalVideoEnabled = true;
  bool _isMicEnabled = true;
  bool _isBroadcasting = false;
  final int _viewerCount = 0;

  @override
  void initState() {
    super.initState();
    print('🏁 تم إنشاء صفحة البث المباشر');
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      print('📱 نظام التشغيل: ${kIsWeb ? 'Web' : Platform.operatingSystem}');
      bool isIOS = !kIsWeb && Platform.isIOS;
      print(isIOS
          ? '🍎 جهاز iOS'
          : kIsWeb
              ? '🌐 متصفح الويب'
              : '🤖 جهاز Android');

      // التحقق من وجود معرف البث المباشر
      if (widget.liveStreamId.isEmpty) {
        throw Exception('معرف البث المباشر غير صالح');
      }

      // المعلومات الخاصة بالمستخدم
      print(
          '🚀 بدء تهيئة البث المباشر لـ ${widget.isBroadcaster ? "المذيع" : "المشاهد"}');
      print('📝 معرف البث المباشر: ${widget.liveStreamId}');
      print('👤 معرف المستخدم: ${widget.userId}');

      // طلب الأذونات - محاولة جديدة أكثر صرامة
      if (widget.isBroadcaster && !kIsWeb) {
        print('🔒 جاري طلب أذونات الكاميرا والميكروفون...');

        // أسلوب خاص لـ iOS
        if (isIOS) {
          await _requestIOSPermissions();
        } else {
          await _requestAndroidPermissions();
        }
      }

      // الحصول على بيانات البث المباشر
      print('🔍 جاري البحث عن بيانات البث المباشر');
      final liveStreamDoc = await FirebaseFirestore.instance
          .collection('live_streams')
          .doc(widget.liveStreamId)
          .get();

      // التحقق من البيانات
      if (!liveStreamDoc.exists || liveStreamDoc.data() == null) {
        throw Exception('البث المباشر غير موجود أو غير صالح');
      }

      final liveStreamData = liveStreamDoc.data()!;
      print(
          '✅ تم العثور على بيانات البث المباشر: ${liveStreamData['title'] ?? 'بدون عنوان'}');

      // الحصول على اسم القناة
      _channelName = liveStreamData['channelName'] ?? '';
      if (_channelName.isEmpty) {
        throw Exception('اسم القناة غير صالح');
      }
      print('📡 اسم القناة: $_channelName');

      // تهيئة محرك Agora
      if (kIsWeb) {
        print('🌐 بدء تهيئة Agora للويب...');
        _engine = createAgoraRtcEngine();
        await _engine?.initialize(RtcEngineContext(
          appId: dotenv.env['AGORA_APP_ID'] ?? '',
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ));
      } else {
        print('📱 بدء تهيئة Agora للجوال...');
        _engine = createAgoraRtcEngine();
        await _engine?.initialize(RtcEngineContext(
          appId: dotenv.env['AGORA_APP_ID'] ?? '',
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ));
      }

      print('✅ تم تهيئة محرك Agora بنجاح');

      // للمذيع
      if (widget.isBroadcaster) {
        print('🎭 إعدادات المذيع - تكوين بث الفيديو');

        // تمكين الفيديو مبكراً
        await _engine?.enableVideo();
        print('✓ تمكين الفيديو');

        // تمكين الصوت
        await _engine?.enableAudio();
        print('✓ تمكين الصوت');

        // إعدادات ترميز الفيديو
        await _engine?.setVideoEncoderConfiguration(
          const VideoEncoderConfiguration(
            dimensions: VideoDimensions(width: 640, height: 360),
            frameRate: 15,
            bitrate: 800,
            orientationMode: OrientationMode.orientationModeAdaptive,
            mirrorMode: VideoMirrorModeType.videoMirrorModeAuto,
          ),
        );
        print('✓ تكوين إعدادات ترميز الفيديو');

        // إعدادات خاصة لـ iOS
        if (isIOS) {
          print('🍎 إعدادات خاصة بـ iOS');
          await _engine?.setCameraCapturerConfiguration(
            const CameraCapturerConfiguration(
              cameraDirection: CameraDirection.cameraFront,
            ),
          );
          print('✓ تكوين إعدادات الكاميرا لـ iOS');
          await _engine?.startPreview();
          print('✓ بدء معاينة الكاميرا على iOS');
        }
      }

      // إعداد معالجات الأحداث
      print('🔄 إعداد معالجات أحداث Agora');
      _setupEventHandlers();

      // تعيين دور المستخدم
      final clientRole = widget.isBroadcaster
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience;

      print(
          '👤 تعيين دور المستخدم: ${widget.isBroadcaster ? 'مذيع' : 'مشاهد'}');
      await _engine?.setClientRole(role: clientRole);
      print('✓ تم تعيين دور المستخدم بنجاح');

      // بدء المعاينة للأنظمة غير iOS (تم تنفيذه بالفعل لـ iOS)
      if (widget.isBroadcaster && !isIOS) {
        print('🎥 بدء معاينة الكاميرا');
        await _engine?.startPreview();
        print('✓ تم بدء معاينة الكاميرا');
      }

      // الحصول على التوكن وانضمام القناة
      print('🔑 جاري الحصول على التوكن للقناة: $_channelName');
      final token = await AgoraService.getToken(
        channelName: _channelName,
        uid: 0,
        role: widget.isBroadcaster ? 1 : 2,
      );

      print('🚀 جاري الانضمام إلى القناة: $_channelName');

      // خيارات محددة للمذيع/المشاهد
      final options = ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: clientRole,
        publishCameraTrack: widget.isBroadcaster,
        publishMicrophoneTrack: widget.isBroadcaster,
        autoSubscribeVideo: true,
        autoSubscribeAudio: true,
      );

      // الانضمام إلى القناة
      await _engine?.joinChannel(
        token: token ?? '',
        channelId: _channelName,
        uid: 0,
        options: options,
      );
      print('✓ تمت محاولة الانضمام إلى القناة بنجاح');

      // تحديث حالة التطبيق
      setState(() {
        _isInitialized = true;
        _isLoading = false;
        _isLocalVideoEnabled = true;
        _isCameraOn = true;
      });

      print('✅ اكتملت عملية التهيئة بنجاح');
    } catch (e) {
      print('❌ خطأ في عملية التهيئة: $e');
      setState(() {
        _errorMessage = 'حدث خطأ أثناء التهيئة: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _requestIOSPermissions() async {
    print('🍎 طلب أذونات iOS بطريقة خاصة');

    // عرض حالة الأذونات الحالية
    PermissionStatus cameraStatus = await Permission.camera.status;
    PermissionStatus micStatus = await Permission.microphone.status;
    print(
        '📊 حالة الأذونات الحالية - كاميرا: $cameraStatus، ميكروفون: $micStatus');

    // طلب إذن الكاميرا أولاً وانتظار النتيجة
    if (!cameraStatus.isGranted) {
      print('🔄 طلب إذن الكاميرا...');
      cameraStatus = await Permission.camera.request();
      print('📷 نتيجة طلب إذن الكاميرا: $cameraStatus');

      // إعطاء وقت إضافي للنظام
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // طلب إذن الميكروفون بعد ذلك
    if (!micStatus.isGranted) {
      print('🔄 طلب إذن الميكروفون...');
      micStatus = await Permission.microphone.request();
      print('🎤 نتيجة طلب إذن الميكروفون: $micStatus');

      // إعطاء وقت إضافي للنظام
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // التحقق من الأذونات النهائية
    if (!cameraStatus.isGranted) {
      print('⛔ لم يتم منح إذن الكاميرا');
      throw Exception(
          'يجب السماح بالوصول إلى الكاميرا لبدء البث. حالة الإذن: $cameraStatus');
    }

    if (!micStatus.isGranted) {
      print('⛔ لم يتم منح إذن الميكروفون');
      throw Exception(
          'يجب السماح بالوصول إلى الميكروفون لبدء البث. حالة الإذن: $micStatus');
    }

    print('✅ تم منح جميع الأذونات المطلوبة');
  }

  Future<void> _requestAndroidPermissions() async {
    print('🤖 طلب أذونات Android');

    final cameraStatus = await Permission.camera.request();
    final microphoneStatus = await Permission.microphone.request();

    print('📷 حالة إذن الكاميرا: $cameraStatus');
    print('🎤 حالة إذن الميكروفون: $microphoneStatus');

    if (cameraStatus != PermissionStatus.granted ||
        microphoneStatus != PermissionStatus.granted) {
      throw Exception('يرجى السماح بالوصول إلى الكاميرا والميكروفون لبدء البث');
    }
  }

  void _setupEventHandlers() {
    _engine?.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          print(
              '✅ تم الانضمام إلى القناة بنجاح: ${connection.channelId}، الوقت المنقضي: $elapsed مللي ثانية');
          setState(() {
            _isJoined = true;
            _isLoading = false;
          });
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          print(
              '👥 انضم مستخدم جديد: $remoteUid، القناة: ${connection.channelId}');
          setState(() {
            _remoteUid = remoteUid;
          });
        },
        onUserOffline: (connection, remoteUid, reason) {
          print('👋 غادر المستخدم: $remoteUid، السبب: $reason');
          setState(() {
            _remoteUid = 0;
          });
        },
        onLocalVideoStateChanged: (source, state, error) {
          print(
              '🎥 تغير حالة الفيديو المحلي: المصدر=$source، الحالة=$state، الخطأ=${error != 0 ? "❌ $error" : "✓ لا يوجد"}');

          // تحليل حالة الفيديو المحلي
          String stateStr = '';
          switch (state) {
            case LocalVideoStreamState.localVideoStreamStateCapturing:
              stateStr = 'جاري التقاط الصورة';
              break;
            case LocalVideoStreamState.localVideoStreamStateEncoding:
              stateStr = 'جاري ترميز الفيديو';
              break;
            case LocalVideoStreamState.localVideoStreamStateFailed:
              stateStr = 'فشل الفيديو المحلي';
              break;
            case LocalVideoStreamState.localVideoStreamStateStopped:
              stateStr = 'توقف الفيديو المحلي';
              break;
            default:
              stateStr = 'حالة أخرى: $state';
          }
          print('📊 تحليل حالة الفيديو المحلي: $stateStr');

          setState(() {
            _isLocalVideoEnabled = state ==
                    LocalVideoStreamState.localVideoStreamStateCapturing ||
                state == LocalVideoStreamState.localVideoStreamStateEncoding;
            _isCameraOn = _isLocalVideoEnabled;
          });
        },
        onRemoteVideoStateChanged:
            (connection, remoteUid, state, reason, elapsed) {
          print(
              '📺 تغير حالة الفيديو البعيد: المستخدم=$remoteUid، الحالة=$state، السبب=$reason');

          // تحليل حالة الفيديو البعيد
          String stateStr = '';
          switch (state) {
            case RemoteVideoState.remoteVideoStateStarting:
              stateStr = 'جاري بدء الفيديو البعيد';
              break;
            case RemoteVideoState.remoteVideoStateDecoding:
              stateStr = 'جاري فك ترميز الفيديو البعيد';
              break;
            case RemoteVideoState.remoteVideoStateFailed:
              stateStr = 'فشل الفيديو البعيد';
              break;
            case RemoteVideoState.remoteVideoStateStopped:
              stateStr = 'توقف الفيديو البعيد';
              break;
            default:
              stateStr = 'حالة أخرى: $state';
          }
          print('📊 تحليل حالة الفيديو البعيد: $stateStr');

          setState(() {
            // تحديث واجهة المستخدم إذا تغيرت حالة الفيديو البعيد
          });
        },
        onError: (errorCode, message) {
          print('❌ خطأ في محرك Agora: $message (رمز الخطأ: $errorCode)');
          setState(() {
            _errorMessage = 'خطأ في محرك Agora: $message';
            _isLoading = false;
          });
        },
        onConnectionStateChanged: (connection, state, reason) {
          print('🔌 تغير حالة الاتصال: الحالة=$state، السبب=$reason');

          // تحليل حالة الاتصال
          String stateStr = '';
          switch (state) {
            case ConnectionStateType.connectionStateConnecting:
              stateStr = 'جاري الاتصال';
              break;
            case ConnectionStateType.connectionStateConnected:
              stateStr = 'متصل';
              break;
            case ConnectionStateType.connectionStateDisconnected:
              stateStr = 'غير متصل';
              break;
            case ConnectionStateType.connectionStateFailed:
              stateStr = 'فشل الاتصال';
              break;
            default:
              stateStr = 'حالة أخرى: $state';
          }
          print('📊 تحليل حالة الاتصال: $stateStr');
        },
      ),
    );
  }

  @override
  void dispose() {
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isBroadcaster ? 'بث مباشر' : 'مشاهدة البث المباشر'),
        backgroundColor: Colors.blue,
        actions: [
          if (_isInitialized && widget.isBroadcaster)
            IconButton(
              icon: const Icon(Icons.camera_alt),
              onPressed: _toggleCamera,
            ),
          if (_isInitialized && widget.isBroadcaster)
            IconButton(
              icon: Icon(_isMicOn ? Icons.mic : Icons.mic_off),
              onPressed: _toggleMic,
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _isInitialized && widget.isBroadcaster
          ? FloatingActionButton(
              onPressed: _isCameraOn ? _endLiveStream : _initialize,
              child: Icon(_isCameraOn ? Icons.stop : Icons.play_arrow),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      children: [
        _buildLiveStreamView(),
        const SizedBox(height: 20),
        if (_isInitialized && widget.isBroadcaster) _buildControlPanel(),
      ],
    );
  }

  Widget _buildLiveStreamView() {
    if (!_isInitialized) {
      return const Expanded(
        child: Center(
          child: Text('البث المباشر غير جاهز'),
        ),
      );
    }

    return Expanded(
      child: Stack(
        children: [
          // خلفية البث المباشر
          Container(
            color: Colors.black87,
            width: double.infinity,
            height: double.infinity,
          ),

          // عرض الفيديو للمذيع
          if (widget.isBroadcaster)
            Positioned.fill(
              child: AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: _engine!,
                  canvas: const VideoCanvas(
                    uid: 0,
                    sourceType: VideoSourceType.videoSourceCamera,
                    renderMode: RenderModeType.renderModeFit,
                  ),
                ),
              ),
            ),

          // عرض الفيديو للمشاهدين
          if (!widget.isBroadcaster && _remoteUid != 0)
            Positioned.fill(
              child: AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: _engine!,
                  canvas: VideoCanvas(
                    uid: _remoteUid,
                    renderMode: RenderModeType.renderModeFit,
                  ),
                  connection: RtcConnection(channelId: _channelName),
                ),
              ),
            ),

          // معلومات التصحيح
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'القناة: $_channelName',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Text(
                    'النوع: ${widget.isBroadcaster ? 'مذيع' : 'مشاهد'}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Text(
                    'متصل: ${_isJoined ? '✓' : '✗'}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Text(
                    'الكاميرا: ${_isLocalVideoEnabled ? '✓' : '✗'}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  if (!widget.isBroadcaster)
                    Text(
                      'معرف المذيع: $_remoteUid',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
            label: _isCameraOn ? 'إيقاف الكاميرا' : 'تشغيل الكاميرا',
            onPressed: _toggleCamera,
          ),
          _buildControlButton(
            icon: _isMicOn ? Icons.mic : Icons.mic_off,
            label: _isMicOn ? 'إيقاف الميكروفون' : 'تشغيل الميكروفون',
            onPressed: _toggleMic,
          ),
          _buildControlButton(
            icon: Icons.switch_camera,
            label: 'تبديل الكاميرا',
            onPressed: _switchCamera,
          ),
          _buildControlButton(
            icon: Icons.call_end,
            label: 'إنهاء البث',
            backgroundColor: Colors.red,
            onPressed: _endLiveStream,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? backgroundColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          backgroundColor: backgroundColor ?? Colors.blue,
          radius: 20,
          child: IconButton(
            icon: Icon(icon, size: 20, color: Colors.white),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _toggleCamera() async {
    if (!_isInitialized) return;

    setState(() {
      _isLocalVideoEnabled = !_isLocalVideoEnabled;
    });

    try {
      // إيقاف تشغيل الكاميرا أو تشغيلها
      if (kIsWeb) {
        await _engine?.muteLocalVideoStream(!_isLocalVideoEnabled);
      } else {
        await _engine?.enableLocalVideo(_isLocalVideoEnabled);
      }

      // تأكيد إضافي لضمان أن الكاميرا تعمل على iOS
      if (_isLocalVideoEnabled && !kIsWeb && Platform.isIOS) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _engine?.muteLocalVideoStream(false);
      }

      print(_isLocalVideoEnabled
          ? '✅ تم تشغيل الكاميرا'
          : '🚫 تم إيقاف الكاميرا');
    } catch (e) {
      print('❌ خطأ في تبديل حالة الكاميرا: $e');
    }
  }

  Future<void> _toggleMic() async {
    if (!_isInitialized) return;

    setState(() {
      _isMicEnabled = !_isMicEnabled;
    });

    try {
      // إيقاف تشغيل الميكروفون أو تشغيله
      if (kIsWeb) {
        await _engine?.muteLocalAudioStream(!_isMicEnabled);
      } else {
        await _engine?.enableLocalAudio(_isMicEnabled);
      }
      print(_isMicEnabled ? '✅ تم تشغيل الميكروفون' : '🚫 تم إيقاف الميكروفون');
    } catch (e) {
      print('❌ خطأ في تبديل حالة الميكروفون: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (!_isInitialized) return;
    await _engine?.switchCamera();
  }

  void _endLiveStream() async {
    try {
      _endCall();

      setState(() {
        _isBroadcasting = false;
      });

      print('⏹️ تم إنهاء البث المباشر');
    } catch (e) {
      print('❌ خطأ في إنهاء البث المباشر: $e');
    }
  }

  Future<void> _endCall() async {
    if (!_isInitialized) return;
    await _engine?.leaveChannel();
    if (mounted) {
      Navigator.pop(context);
    }
  }
}
