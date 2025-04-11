import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../models/user_model.dart';
import '../services/live_stream_service.dart';
import '../services/agora_service.dart';
import 'dart:async';
import '../pages/simple_live_stream_page.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';

class LiveStreamBroadcasterPage extends StatefulWidget {
  final UserModel currentUser;
  final String? liveStreamId;
  final String? channelName;
  final Map<String, dynamic> liveStreamData;

  const LiveStreamBroadcasterPage({
    super.key,
    required this.currentUser,
    required this.liveStreamId,
    required this.channelName,
    required this.liveStreamData,
  });

  @override
  State<LiveStreamBroadcasterPage> createState() =>
      _LiveStreamBroadcasterPageState();
}

class _LiveStreamBroadcasterPageState extends State<LiveStreamBroadcasterPage> {
  bool _localUserJoined = false;
  bool _cameraEnabled = true;
  bool _microphoneEnabled = true;
  int _totalViewers = 0;
  Timer? _viewersTimer;
  bool _isInitializing = true;
  final int _retryCount = 0;
  final int _maxRetries = 3;
  bool _isLocalVideoEnabled = false;
  bool _isStarting = false;
  String? _effectiveChannelName;
  String? _effectiveLiveStreamId;
  String? _liveStreamId;
  String? _title;
  String? _description;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isLiveStreaming = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _isInitializing = true;

    // تحديد القيم الفعالة حتى لا نتعامل مع القيم null
    _effectiveChannelName = widget.channelName?.isNotEmpty == true
        ? widget.channelName
        : widget.liveStreamData['channelName']?.toString() ??
            widget.liveStreamData['channel_name']?.toString() ??
            generateSessionId();

    _effectiveLiveStreamId = widget.liveStreamId?.isNotEmpty == true
        ? widget.liveStreamId
        : widget.liveStreamData['id']?.toString() ??
            widget.liveStreamData['liveStreamId']?.toString() ??
            widget.liveStreamData['_id']?.toString();

    print('قيم الجلسة الفعالة:');
    print('معرف البث المباشر: $_effectiveLiveStreamId');
    print('اسم القناة: $_effectiveChannelName');

    // تهيئة البث المباشر
    _initializeLiveStream();

    _totalViewers = widget.liveStreamData['total_viewers'] ??
        widget.liveStreamData['viewerCount'] ??
        widget.liveStreamData['viewers'] ??
        0;
    _startViewersTimer();

    LiveStreamService.localUserJoined.addListener(_onLocalUserStatusChanged);
  }

  // توليد معرف جلسة فريد في حالة لم يتم توفير اسم قناة
  String generateSessionId() {
    final Random random = Random.secure();
    const String chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final String sessionId = String.fromCharCodes(
      List.generate(16, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
    print('تم إنشاء معرف جلسة جديد: $sessionId');
    return sessionId;
  }

  Future<void> _initializeLiveStream() async {
    try {
      // التحقق من أذونات الكاميرا أولاً
      final hasPermissions = await _checkCameraPermission();
      if (!hasPermissions) {
        setState(() {
          _isInitializing = false;
        });
        return;
      }

      // التحقق من وجود الكاميرا
      final hasCamera = await _checkCameraAvailability();
      if (!hasCamera) {
        setState(() {
          _isInitializing = false;
        });
        _showCameraNotAvailableDialog();
        return;
      }

      // تهيئة محرك Agora
      await AgoraService.initialize();

      // الانضمام إلى قناة البث المباشر
      final joined = await AgoraService.joinLiveStreamChannel(
        _effectiveChannelName!,
        widget.currentUser.id,
        _effectiveLiveStreamId ?? 'temp_live_stream_id',
        isBroadcaster: true,
      );

      if (!joined) {
        setState(() {
          _isInitializing = false;
        });
        _showJoinChannelErrorDialog();
        return;
      }

      setState(() {
        _isInitializing = false;
        _localUserJoined = true;
        _isLocalVideoEnabled = true;
      });
    } catch (e) {
      print('خطأ في تهيئة البث المباشر: $e');
      setState(() {
        _isInitializing = false;
      });
      _showInitializationErrorDialog();
    }
  }

  void _startViewersTimer() {
    _viewersTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;

      try {
        // طباعة معرف البث للتشخيص
        print('محاولة تحديث عدد المشاهدين للبث: $_effectiveLiveStreamId');

        if (_effectiveLiveStreamId == null || _effectiveLiveStreamId!.isEmpty) {
          print('خطأ: معرف البث المباشر غير صالح');
          return;
        }

        final snapshot = await FirebaseFirestore.instance
            .collection('live_streams')
            .doc(_effectiveLiveStreamId)
            .get();

        if (snapshot.exists && mounted) {
          final data = snapshot.data();
          if (data != null) {
            // البحث عن عدد المشاهدين في عدة حقول محتملة
            int viewers = 0;
            if (data.containsKey('viewerCount')) {
              final viewerCount = data['viewerCount'];
              if (viewerCount is int) {
                viewers = viewerCount;
              } else if (viewerCount != null) {
                viewers = int.tryParse(viewerCount.toString()) ?? 0;
              }
            } else if (data.containsKey('viewers')) {
              final viewerCount = data['viewers'];
              if (viewerCount is int) {
                viewers = viewerCount;
              } else if (viewerCount != null) {
                viewers = int.tryParse(viewerCount.toString()) ?? 0;
              }
            } else if (data.containsKey('total_viewers')) {
              final viewerCount = data['total_viewers'];
              if (viewerCount is int) {
                viewers = viewerCount;
              } else if (viewerCount != null) {
                viewers = int.tryParse(viewerCount.toString()) ?? 0;
              }
            }

            setState(() {
              _totalViewers = viewers;
            });
          }
        }
      } catch (e) {
        print('خطأ في تحديث عدد المشاهدين: $e');
        print('تفاصيل الخطأ: ${e.toString()}');
      }
    });
  }

  void _onLocalUserStatusChanged() {
    if (mounted) {
      setState(() {
        _localUserJoined = LiveStreamService.localUserJoined.value;
        if (_localUserJoined) {
          _isInitializing = false;
        }
      });
    }
  }

  // التحقق من إذن الكاميرا وطلبه إذا لم يكن ممنوحًا
  Future<bool> _checkCameraPermission() async {
    try {
      // طباعة حالة الأذونات الحالية
      print('جاري التحقق من أذونات الكاميرا والميكروفون...');

      // التحقق من حالة الأذونات
      final cameraStatus = await Permission.camera.status;
      final microphoneStatus = await Permission.microphone.status;

      print('حالة إذن الكاميرا: $cameraStatus');
      print('حالة إذن الميكروفون: $microphoneStatus');

      // إذا كانت الأذونات ممنوحة بالفعل
      if (cameraStatus.isGranted && microphoneStatus.isGranted) {
        print('الأذونات ممنوحة بالفعل');
        return true;
      }

      // إذا كانت الأذونات لم تُطلب بعد أو مرفوضة
      if (cameraStatus.isDenied || microphoneStatus.isDenied) {
        print('طلب الأذونات من المستخدم...');

        // طلب الأذونات
        final result = await [
          Permission.camera,
          Permission.microphone,
        ].request();

        // التحقق من نتيجة طلب الأذونات
        print('نتيجة طلب الأذونات:');
        print('الكاميرا: ${result[Permission.camera]}');
        print('الميكروفون: ${result[Permission.microphone]}');

        if (result[Permission.camera]!.isGranted &&
            result[Permission.microphone]!.isGranted) {
          print('تم منح جميع الأذونات');
          return true;
        }

        // إذا كانت الأذونات مرفوضة بشكل دائم
        if (result[Permission.camera]!.isPermanentlyDenied ||
            result[Permission.microphone]!.isPermanentlyDenied) {
          print('أذونات مرفوضة بشكل دائم');
          _showPermissionPermanentlyDeniedDialog();
          return false;
        }

        print('الأذونات مرفوضة');
        return false;
      }

      // إذا كانت الأذونات مرفوضة بشكل دائم
      if (cameraStatus.isPermanentlyDenied ||
          microphoneStatus.isPermanentlyDenied) {
        print('أذونات مرفوضة بشكل دائم، يجب فتح إعدادات التطبيق');
        _showPermissionPermanentlyDeniedDialog();
        return false;
      }

      // في حالة أي حالة أخرى غير متوقعة، نعتبر الأذونات غير ممنوحة
      print('حالة أذونات غير معالجة، إرجاع false');
      return cameraStatus.isGranted && microphoneStatus.isGranted;
    } catch (e) {
      print('خطأ في التحقق من الأذونات: $e');
      return false;
    }
  }

  // التحقق من وجود الكاميرا على الجهاز
  Future<bool> _checkCameraAvailability() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        // التحقق من وجود الكاميرا على أجهزة Android
        final androidInfo = await deviceInfo.androidInfo;
        // بعض أجهزة Android قد لا تعلن عن الميزات، لذا نفترض أن الكاميرا موجودة إذا كان الإصدار حديثًا
        if (androidInfo.version.sdkInt > 20) {
          return true; // نفترض أن أجهزة Android الحديثة لديها كاميرا
        }
        return androidInfo.systemFeatures.contains('android.hardware.camera') ||
            androidInfo.systemFeatures
                .contains('android.hardware.camera.front');
      } else if (Platform.isIOS) {
        // معظم أجهزة iOS لديها كاميرا، ولكن يمكن أن نتحقق من نوع الجهاز
        final iosInfo = await deviceInfo.iosInfo;
        // iPod touch القديم ربما لا يحتوي على كاميرا
        // نفترض أن جميع أجهزة iPhone و iPad الحديثة لديها كاميرا
        return !iosInfo.name.toLowerCase().contains('ipod touch') ||
            iosInfo.systemVersion.compareTo('5.0') >= 0;
      }

      return true; // نفترض أن الكاميرا متوفرة على منصات أخرى
    } catch (e) {
      print('خطأ أثناء التحقق من وجود الكاميرا: $e');
      return true; // نفترض أن الكاميرا موجودة في حالة الخطأ
    }
  }

  // عرض مربع حوار للشرح قبل طلب الإذن
  void _showPermissionExplanationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('السماح بالوصول إلى الكاميرا'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.camera_alt,
              size: 48,
              color: Colors.blue,
            ),
            SizedBox(height: 16),
            Text(
              'للبث المباشر، يحتاج التطبيق إلى الوصول إلى الكاميرا.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'عند ظهور النافذة التالية، اختر "السماح".',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // العودة إلى الشاشة السابقة
            },
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // طلب الإذن مرة أخرى بعد الشرح
              final result = await Permission.camera.request();
              if (result.isGranted && mounted) {
                _setupLocalVideo();
              } else if (mounted) {
                // إذا استمر الرفض
                _showPermissionPermanentlyDeniedDialog();
                setState(() {
                  _isInitializing = false;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('استمرار'),
          ),
        ],
      ),
    );
  }

  // عرض مربع حوار عندما تكون أذونات الكاميرا مرفوضة بشكل دائم
  void _showPermissionPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('الأذونات المطلوبة'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.no_photography,
              size: 48,
              color: Colors.redAccent,
            ),
            SizedBox(height: 16),
            Text(
              'لاستخدام ميزة البث المباشر، يجب منح التطبيق إذن الوصول إلى الكاميرا والميكروفون.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'يرجى فتح إعدادات التطبيق وتمكين الأذونات التالية:',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '- الكاميرا\n- الميكروفون',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // العودة إلى الشاشة السابقة
            },
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings(); // فتح إعدادات التطبيق مباشرة
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
  }

  // عرض مربع حوار عندما تكون الكاميرا غير متوفرة على الجهاز
  void _showCameraNotAvailableDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('الكاميرا غير متوفرة'),
        content: const Text(
            'لم يتم العثور على كاميرا على جهازك. يرجى التأكد من وجود كاميرا عاملة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسنًا'),
          ),
        ],
      ),
    );
  }

  void _showJoinChannelErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('خطأ في الانضمام إلى القناة'),
        content: const Text(
            'فشل في الانضمام إلى قناة البث المباشر. يرجى المحاولة مرة أخرى.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسنًا'),
          ),
        ],
      ),
    );
  }

  void _showInitializationErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('خطأ في التهيئة'),
        content: const Text(
            'حدث خطأ أثناء تهيئة البث المباشر. يرجى المحاولة مرة أخرى.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسنًا'),
          ),
        ],
      ),
    );
  }

  Future<void> _setupLocalVideo() async {
    try {
      print('محاولة عرض الفيديو المحلي');

      if (!mounted) {
        print('الصفحة غير موجودة');
        return;
      }

      // التأكد من تهيئة محرك Agora
      if (AgoraService.engine == null) {
        print('محرك Agora غير موجود، محاولة إعادة التهيئة');
        final initialized = await AgoraService.initialize();
        if (!initialized) {
          print('فشل في تهيئة محرك Agora');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('تعذر تهيئة خدمة البث المباشر، يرجى إعادة المحاولة'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
        // تأخير بعد التهيئة
        await Future.delayed(const Duration(milliseconds: 1500));
      }

      print('محرك Agora موجود، محاولة إنشاء AgoraVideoView');

      // إضافة تأخير قبل إعداد الفيديو
      await Future.delayed(const Duration(milliseconds: 1000));

      // إنشاء كائن VideoCanvas
      const VideoCanvas canvas = VideoCanvas(
        uid: 0,
        renderMode: RenderModeType.renderModeFit,
      );

      try {
        // إعداد الفيديو المحلي
        await AgoraService.engine!.setupLocalVideo(canvas);
        print('تم إعداد الفيديو المحلي');

        // تأخير إضافي بعد إعداد الفيديو المحلي
        await Future.delayed(const Duration(milliseconds: 1000));

        // بدء البث المحلي مع معالجة الأخطاء المحتملة
        try {
          await AgoraService.engine!.startPreview();
          print('تم بدء البث المحلي');
        } catch (previewError) {
          print('خطأ في بدء البث المحلي: $previewError');
          // محاولة مرة أخرى بعد تأخير
          await Future.delayed(const Duration(milliseconds: 2000));
          try {
            await AgoraService.engine!.startPreview();
            print('تم بدء البث المحلي في المحاولة الثانية');
          } catch (retryError) {
            print('فشل في بدء البث المحلي بعد المحاولة الثانية: $retryError');
          }
        }

        if (mounted) {
          setState(() {
            _isLocalVideoEnabled = true;
          });
        }
      } catch (e) {
        print('خطأ أثناء إعداد الفيديو المحلي: $e');
        // محاولة تمكين الفيديو والصوت مباشرة
        try {
          await AgoraService.engine!.enableVideo();
          await AgoraService.engine!.enableLocalVideo(true);
          await Future.delayed(const Duration(milliseconds: 1000));
          await AgoraService.engine!.startPreview();
          print('تم تمكين الفيديو وبدء البث باستخدام الطريقة البديلة');

          if (mounted) {
            setState(() {
              _isLocalVideoEnabled = true;
            });
          }
        } catch (altError) {
          print('فشل في استخدام الطريقة البديلة لتمكين الفيديو: $altError');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'تعذر تشغيل الكاميرا، يرجى التحقق من الأذونات وإعادة المحاولة'),
                duration: Duration(seconds: 5),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('خطأ في إعداد الفيديو المحلي: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء إعداد الفيديو المحلي: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _viewersTimer?.cancel();
    LiveStreamService.localUserJoined.removeListener(_onLocalUserStatusChanged);

    try {
      LiveStreamService.leaveChannel(_effectiveChannelName!);
    } catch (e) {
      print('خطأ عند مغادرة قناة البث: $e');
    }

    super.dispose();
  }

  Future<void> _toggleCamera() async {
    setState(() {
      _cameraEnabled = !_cameraEnabled;
    });

    await LiveStreamService.toggleCamera(
      _effectiveChannelName!,
      enabled: _cameraEnabled,
    );
  }

  Future<void> _toggleMicrophone() async {
    setState(() {
      _microphoneEnabled = !_microphoneEnabled;
    });

    await LiveStreamService.toggleMicrophone(
      _effectiveChannelName!,
      enabled: _microphoneEnabled,
    );
  }

  Future<void> _endLiveStream() async {
    // احفظ معرف البث المباشر
    final String streamId = _effectiveLiveStreamId!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنهاء البث المباشر'),
        content: const Text('هل أنت متأكد من رغبتك في إنهاء البث المباشر؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              // أولاً: إغلاق مربع الحوار
              Navigator.pop(context);

              // ثانياً: العودة للصفحة السابقة
              Navigator.pop(context);

              // ثالثاً: إنهاء البث المباشر في الخلفية
              LiveStreamService.endLiveStream(streamId).then((_) {
                print('تم إنهاء البث المباشر بنجاح: $streamId');
              }).catchError((error) {
                print('خطأ في إنهاء البث المباشر: $error');
              });
            },
            child: const Text('إنهاء البث'),
          ),
        ],
      ),
    );
  }

  void _startLiveStream() async {
    setState(() {
      _isStarting = true;
    });

    try {
      if (mounted) {
        // إنشاء نسخة آمنة من بيانات البث المباشر
        Map<String, dynamic> safeStreamData = {...widget.liveStreamData};

        // التأكد من أن بيانات البث المباشر تحتوي على القيم الصحيحة
        if (safeStreamData['channelName'] == null ||
            safeStreamData['channelName'].toString().isEmpty) {
          print('استخدام اسم القناة الفعال: $_effectiveChannelName');
          safeStreamData['channelName'] = _effectiveChannelName;
        }

        if ((safeStreamData['id'] == null ||
                safeStreamData['id'].toString().isEmpty) &&
            _effectiveLiveStreamId != null &&
            _effectiveLiveStreamId!.isNotEmpty) {
          print('استخدام معرف البث المباشر الفعال: $_effectiveLiveStreamId');
          safeStreamData['id'] = _effectiveLiveStreamId;
        }

        // استخدام الصفحة الجديدة مع agora_uikit
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SimpleLiveStreamPage(
              liveStreamData: safeStreamData,
              liveStreamId: _effectiveLiveStreamId ?? '',
              isBroadcaster: true,
              userId: widget.currentUser.id,
            ),
          ),
        ).then((_) {
          // عند العودة من البث، تعيين الحالة
          if (mounted) {
            setState(() {
              _isStarting = false;
            });
          }
        });
      }
    } catch (e) {
      print('خطأ في بدء البث المباشر: $e');
      if (mounted) {
        setState(() {
          _isStarting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("حدث خطأ: $e")),
        );
      }
    }
  }

  Future<void> _startBroadcast() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('يجب تسجيل الدخول لبدء البث المباشر');
      }

      _liveStreamId ??= await LiveStreamService.createLiveStream(
        title: _title ?? 'بث مباشر جديد',
        broadcasterName: widget.currentUser.firstName ?? 'منجم',
      );

      final joined = await LiveStreamService.joinLiveStreamChannel(
        _liveStreamId!,
        isBroadcaster: true,
      );

      if (!joined) {
        throw Exception('فشل في الانضمام إلى قناة البث المباشر');
      }

      _startViewersTimer();

      setState(() {
        _isLiveStreaming = true;
        _isLoading = false;
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SimpleLiveStreamPage(
              liveStreamData: {
                ...widget.liveStreamData,
                'id': _liveStreamId,
                'channelName': _effectiveChannelName,
              },
              liveStreamId: _liveStreamId!,
              isBroadcaster: true,
              userId: widget.currentUser.id,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _endLiveStream();
        return true;
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // عرض الفيديو المحلي
            if (_localUserJoined && _isLocalVideoEnabled)
              AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: AgoraService.engine!,
                  canvas: const VideoCanvas(uid: 0),
                ),
              )
            else
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.videocam_off,
                      size: 64,
                      color: Colors.white,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'جاري تهيئة الكاميرا...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),

            // أزرار التحكم
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // زر تبديل الكاميرا
                  IconButton(
                    icon: Icon(
                      _cameraEnabled ? Icons.videocam : Icons.videocam_off,
                      color: Colors.white,
                    ),
                    onPressed: () => _toggleCamera(),
                  ),
                  // زر تبديل الميكروفون
                  IconButton(
                    icon: Icon(
                      _microphoneEnabled ? Icons.mic : Icons.mic_off,
                      color: Colors.white,
                    ),
                    onPressed: () => _toggleMicrophone(),
                  ),
                  // زر إنهاء البث
                  IconButton(
                    icon: const Icon(
                      Icons.call_end,
                      color: Colors.red,
                    ),
                    onPressed: () => _endLiveStream(),
                  ),
                ],
              ),
            ),

            // عدد المشاهدين
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.remove_red_eye,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_totalViewers',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
