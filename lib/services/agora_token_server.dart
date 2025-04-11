import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:typed_data';
import 'dart:math';

/// خادم محلي لتوليد توكنات Agora للتطوير
/// يعمل على المنفذ 8080 ويوفر واجهة HTTP لتوليد التوكنات
class AgoraTokenServer {
  static HttpServer? _server;
  static const int _port = 3000;
  static final String _appId =
      dotenv.env['AGORA_APP_ID'] ?? "45aba7aeffe344768f07b78a9a93bfff";
  static final String _appCertificate =
      dotenv.env['AGORA_APP_CERTIFICATE'] ?? "45aba7aeffe344768f07b78a9a93bfff";

  // مدة صلاحية التوكن بالثواني (ساعة واحدة)
  static const int _tokenExpiryInSeconds = 3600;

  // وقت بدء تشغيل الخادم
  static final DateTime _serverStartTime = DateTime.now();

  // سجل طلبات التوكن
  static final List<Map<String, dynamic>> _tokenRequests = [];

  // عنوان الخادم المحلي
  static Future<String> get serverUrl async {
    final ip = await _getLocalIP();
    return 'http://$ip:$_port/token';
  }

  // الحصول على عنوان IP المحلي
  static Future<String> _getLocalIP() async {
    try {
      // محاولة الحصول على عنوان IP الفعلي
      final interfaces = await NetworkInterface.list();
      for (var interface in interfaces) {
        // تجنب واجهات localhost
        if (interface.name.toLowerCase().contains('lo')) {
          continue;
        }

        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            // تفضيل واجهات الشبكة اللاسلكية والسلكية
            if (interface.name.toLowerCase().contains('en') ||
                interface.name.toLowerCase().contains('wlan') ||
                interface.name.toLowerCase().contains('eth')) {
              print('استخدام عنوان IP من الواجهة: ${interface.name}');
              print('عنوان IP: ${addr.address}');
              return addr.address;
            }
          }
        }
      }

      // إذا لم يتم العثور على واجهة مفضلة، استخدم أي عنوان IPv4
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            print('استخدام عنوان IP من الواجهة: ${interface.name}');
            print('عنوان IP: ${addr.address}');
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('خطأ في الحصول على عنوان IP: $e');
    }

    // استخدام عنوان localhost إذا فشلت كل المحاولات
    print('لم يتم العثور على عنوان IP صالح، استخدام localhost');
    return '127.0.0.1';
  }

  // هل الخادم قيد التشغيل
  static bool get isRunning => _server != null;

  /// بدء تشغيل الخادم المحلي
  static Future<void> start() async {
    if (_server != null) {
      print('خادم التوكن يعمل بالفعل على المنفذ $_port');
      return;
    }

    try {
      // محاولة أولى باستخدام localhost لتجنب مشاكل الشبكة
      try {
        print('محاولة ربط الخادم على localhost...');
        _server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          _port,
          shared: true,
        );
        print('تم ربط الخادم على localhost بنجاح على المنفذ $_port');
      } catch (e) {
        print(
            'فشل في الربط على localhost: $e، جاري محاولة الربط على أي عنوان IP...');
        // محاولة ثانية باستخدام أي عنوان IP
        _server = await HttpServer.bind(
          InternetAddress.anyIPv4,
          _port,
          shared: true,
        );
        print('تم ربط الخادم على أي عنوان IP بنجاح على المنفذ $_port');
      }

      final url = await serverUrl;
      print('بدأ خادم التوكن على المنفذ $_port');
      print('عنوان الخادم: $url');

      await for (HttpRequest request in _server!) {
        // طباعة تفاصيل الطلب الواردة للتشخيص
        print(
            'طلب وارد: ${request.method} ${request.uri.path} من ${request.connectionInfo?.remoteAddress.address}');
        print('معلمات الاستعلام: ${request.uri.queryParameters}');

        if (request.method == 'GET' && request.uri.path == '/token') {
          try {
            // تعديل: دعم معلمات متعددة للتوافق
            final channelName = request.uri.queryParameters['channelName'] ??
                request.uri.queryParameters['channel'];
            final uidStr = request.uri.queryParameters['uid'] ?? '0';
            final role = request.uri.queryParameters['role'] ?? '1';

            if (channelName == null || channelName.isEmpty) {
              print('⚠️ خطأ: اسم القناة مفقود في الطلب');
              request.response
                ..statusCode = HttpStatus.badRequest
                ..headers.contentType = ContentType.json
                ..write(jsonEncode({'error': 'اسم القناة مطلوب'}))
                ..close();
              continue;
            }

            print(
                '✅ طلب توكن جديد - القناة: $channelName, معرف المستخدم: $uidStr, الدور: $role');

            // معالجة معرف المستخدم بأمان
            int uid;
            try {
              if (uidStr.startsWith('bt3h9as1')) {
                print('⚠️ تنبيه: معرف مستخدم غير صالح للتحليل: $uidStr');
                // استخدام قيمة عشوائية لمعرفات المستخدمين غير الصالحة
                uid = DateTime.now().millisecondsSinceEpoch % 100000;
              } else {
                uid = int.parse(uidStr);
              }
            } catch (e) {
              print('⚠️ خطأ في تحليل معرف المستخدم: $e');
              // استخدام 0 كمعرف مستخدم افتراضي بدلاً من إبلاغ خطأ
              uid = DateTime.now().millisecondsSinceEpoch % 100000;
            }

            // تحويل معرف المستخدم إلى نص مرة أخرى للتوافق مع الدالة
            final uidString = uid.toString();
            final token = await _createToken(channelName, uidString);
            print(
                '✅ تم إنشاء التوكن بنجاح: ${token.substring(0, min(20, token.length))}...');

            final responseBody = {
              'token': token,
              'appId': _appId,
              'channelName': channelName,
              'uid': uidString,
              'createdAt': DateTime.now().toIso8601String(),
              'expiresIn': _tokenExpiryInSeconds,
            };

            print('✅ إرسال استجابة ناجحة');
            request.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.json
              ..write(jsonEncode(responseBody))
              ..close();

            // سجل طلب التوكن الناجح
            _logTokenRequest(channelName, uidString, token);
          } catch (e) {
            print('⚠️ خطأ في معالجة الطلب: $e');
            request.response
              ..statusCode = HttpStatus.internalServerError
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({
                'error': 'حدث خطأ أثناء إنشاء التوكن',
                'details': e.toString()
              }))
              ..close();
          }
        } else if (request.method == 'GET' && request.uri.path == '/ping') {
          // إضافة نقطة نهاية ping للتحقق من حالة الخادم
          print('✅ استلام طلب ping، الخادم يعمل بشكل جيد');
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({
              'status': 'ok',
              'serverTime': DateTime.now().toIso8601String(),
              'uptime': DateTime.now().difference(_serverStartTime).inSeconds,
            }))
            ..close();
        } else {
          print('⚠️ طلب غير صالح: ${request.method} ${request.uri.path}');
          request.response
            ..statusCode = HttpStatus.notFound
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'error': 'المسار غير موجود'}))
            ..close();
        }
      }
    } catch (e) {
      print('خطأ في بدء خادم التوكن: $e');
      // في حالة خطأ "المنفذ قيد الاستخدام"، محاولة استخدام منفذ آخر
      if (e.toString().contains('Address already in use')) {
        print(
            'المنفذ $_port قيد الاستخدام بالفعل، يمكن أن يكون موجودًا بالفعل.');
        // إعادة تعيين معرف الخادم لترك الاستخدام المباشر للتوكن
        _server = null;
      } else {
        rethrow;
      }
    }
  }

  /// إيقاف تشغيل الخادم المحلي
  static Future<void> stop() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
      print('تم إيقاف خادم التوكن');
    }
  }

  // طلب توكن بأمان
  static Future<String> _createToken(String channelName, String uid) async {
    try {
      print('إنشاء توكن جديد (007) للقناة: $channelName');
      print('معرف التطبيق: $_appId');
      print('شهادة التطبيق: ${_appCertificate.substring(0, 5)}...');

      // التحقق من صحة المعلمات
      if (channelName.isEmpty) {
        throw Exception('اسم القناة فارغ');
      }
      if (_appId.isEmpty) {
        throw Exception('معرف التطبيق فارغ');
      }
      if (_appCertificate.isEmpty) {
        throw Exception('شهادة التطبيق فارغة');
      }
      if (_appCertificate.length < 32) {
        throw Exception(
            'شهادة التطبيق غير صالحة - يجب أن تكون أطول من 32 حرفاً');
      }

      // إنشاء التوكن مع صلاحيات كاملة
      final currentTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expireTimestamp = currentTimestamp + _tokenExpiryInSeconds;

      // إنشاء التوكن مع صلاحيات كاملة
      final token = RtcTokenBuilder.buildTokenWithUid(
          _appId,
          _appCertificate,
          channelName,
          uid,
          UserRole.Role_Publisher,
          expireTimestamp,
          expireTimestamp);

      // التحقق من صحة التوكن
      if (token.isEmpty) {
        throw Exception('فشل في إنشاء التوكن - النتيجة فارغة');
      }
      if (!token.startsWith('007')) {
        throw Exception('التوكن غير صالح - يجب أن يبدأ بـ 007');
      }

      print('تم إنشاء التوكن بنجاح: ${token.substring(0, 10)}...');
      return token;
    } catch (e) {
      print('خطأ في إنشاء التوكن: $e');
      rethrow;
    }
  }

  static Future<String> getTokenUrl(String channelName,
      {String uid = '0'}) async {
    final serverUrl = await AgoraTokenServer.serverUrl;
    return '$serverUrl?channel=$channelName&uid=$uid';
  }

  /// بدء تشغيل الخادم تلقائياً
  static void startServer() {
    start().then((_) {
      print('تم بدء تشغيل خادم التوكن بنجاح');
      _getLocalIP().then((ip) {
        print('عنوان IP المحلي: $ip');
        serverUrl.then((url) {
          print('عنوان الخادم الكامل: $url');
        });
      });
    }).catchError((error) {
      print('فشل في بدء تشغيل خادم التوكن: $error');
    });
  }

  /// تسجيل طلب توكن
  static void _logTokenRequest(String channelName, String uid, String token) {
    _tokenRequests.add({
      'channelName': channelName,
      'uid': uid,
      'timestamp': DateTime.now().toIso8601String(),
      'tokenPrefix': token.length > 10 ? token.substring(0, 10) : token,
    });

    // الاحتفاظ بآخر 100 طلب فقط
    if (_tokenRequests.length > 100) {
      _tokenRequests.removeAt(0);
    }

    print('تم تسجيل طلب التوكن (إجمالي الطلبات: ${_tokenRequests.length})');
  }
}

// =========================================================
//          RTC Token Builder Logic (Adapted from Agora)
// =========================================================

enum UserRole {
  Role_Attendee(0),
  Role_Publisher(1),
  Role_Subscriber(2),
  Role_Admin(101);

  final int value;
  const UserRole(this.value);
}

class RtcTokenBuilder {
  static const int _kRtcLogin = 1;
  static const int _kRtcJoinChannel = 1;
  static const int _kPublishAudioStream = 2;
  static const int _kPublishVideoStream = 3;
  static const int _kPublishDataStream = 4;
  static const int _kRtmLogin = 1000;

  static String buildTokenWithUid(
      String appId,
      String appCertificate,
      String channelName,
      String uid,
      UserRole role,
      int privilegeTs,
      int tokenExpireTs) {
    try {
      print('بدء إنشاء التوكن...');
      print('معرف التطبيق: $appId');
      print('اسم القناة: $channelName');
      print('معرف المستخدم: $uid');
      print('الدور: $role');
      print('وقت الصلاحية: $privilegeTs');
      print('وقت انتهاء الصلاحية: $tokenExpireTs');

      AccessToken token = AccessToken(appId, appCertificate, channelName, uid);

      // تعيين الصلاحيات حسب الدور
      token.message[AccessToken.kJoinChannel] = privilegeTs;
      if (role == UserRole.Role_Publisher ||
          role == UserRole.Role_Subscriber ||
          role == UserRole.Role_Admin) {
        token.message[AccessToken.kPublishVideoStream] = privilegeTs;
        token.message[AccessToken.kPublishAudioStream] = privilegeTs;
        token.message[AccessToken.kPublishDataStream] = privilegeTs;
      }

      token.salt = Random().nextInt(900000) + 100000;
      token.ts = tokenExpireTs;

      final result = token.build();
      print('تم إنشاء التوكن بنجاح: ${result.substring(0, 10)}...');
      return result;
    } catch (e) {
      print('خطأ في إنشاء التوكن: $e');
      rethrow;
    }
  }
}

class AccessToken {
  static const int kJoinChannel = 1;
  static const int kPublishAudioStream = 2;
  static const int kPublishVideoStream = 3;
  static const int kPublishDataStream = 4;
  static const int kPublishAudiocdn = 5;
  static const int kPublishVideoCdn = 6;
  static const int kRequestPublishAudioStream = 7;
  static const int kRequestPublishVideoStream = 8;
  static const int kRequestPublishDataStream = 9;
  static const int kInvitePublishAudioStream = 10;
  static const int kInvitePublishVideoStream = 11;
  static const int kInvitePublishDataStream = 12;
  static const int kAdministrateChannel = 101;
  static const int kRtmLogin = 1000;

  String appId;
  String appCertificate;
  String channelName;
  String uid;
  Uint8List signature = Uint8List(0);
  Uint8List messageRaw = Uint8List(0);
  int salt;
  int ts;
  Map<int, int> message = {};

  AccessToken(this.appId, this.appCertificate, this.channelName, this.uid,
      {this.salt = 0, this.ts = 0}) {
    salt = salt == 0 ? Random().nextInt(900000) + 100000 : salt;
    ts = ts == 0
        ? (DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600)
        : ts; // Default 1 hour expiry
  }

  String build() {
    messageRaw = _pack(message);
    signature = _sign(appCertificate, appId, channelName, uid, messageRaw);

    ByteBuf content = ByteBuf();
    content.put(signature);
    content.put(messageRaw);

    return "007${base64Encode(content.pack())}";
  }

  Uint8List _sign(String appCertificate, String appId, String channelName,
      String uid, Uint8List message) {
    ByteBuf buf = ByteBuf();
    buf.putString(appId);
    buf.putString(channelName);
    buf.putString(uid);
    buf.put(message);

    final key = utf8.encode(appCertificate);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(buf.pack());
    return Uint8List.fromList(digest.bytes);
  }

  Uint8List _pack(Map<int, int> messages) {
    ByteBuf buf = ByteBuf();
    buf.putUint16(messages.length);
    messages.forEach((key, value) {
      buf.putUint16(key);
      buf.putUint32(value);
    });
    return buf.pack();
  }
}

class ByteBuf {
  ByteData _byteData;
  int _writeIndex = 0;

  ByteBuf() : _byteData = ByteData(1024); // Initial capacity

  void _ensureCapacity(int needed) {
    if (_byteData.lengthInBytes - _writeIndex < needed) {
      int newCapacity = (_byteData.lengthInBytes + needed) * 2;
      ByteData newByteData = ByteData(newCapacity);
      for (int i = 0; i < _writeIndex; i++) {
        newByteData.setUint8(i, _byteData.getUint8(i));
      }
      _byteData = newByteData;
    }
  }

  void putUint16(int value) {
    _ensureCapacity(2);
    _byteData.setUint16(_writeIndex, value, Endian.little);
    _writeIndex += 2;
  }

  void putUint32(int value) {
    _ensureCapacity(4);
    _byteData.setUint32(_writeIndex, value, Endian.little);
    _writeIndex += 4;
  }

  void putString(String value) {
    Uint8List bytes = utf8.encode(value);
    putUint16(bytes.length);
    put(bytes);
  }

  void put(Uint8List bytes) {
    _ensureCapacity(bytes.length);
    for (int i = 0; i < bytes.length; i++) {
      _byteData.setUint8(_writeIndex + i, bytes[i]);
    }
    _writeIndex += bytes.length;
  }

  Uint8List pack() {
    return _byteData.buffer.asUint8List(0, _writeIndex);
  }
}
// =========================================================
