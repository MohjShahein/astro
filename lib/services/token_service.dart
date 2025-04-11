import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'agora_token_server.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';

/// خدمة إدارة توكن Agora
class TokenService {
  // معلومات التكوين - يتم استخراجها من ملف بيئة أو من المتغيرات المخزنة
  static final String _appId =
      dotenv.env['AGORA_APP_ID'] ?? "45aba7aeffe344768f07b78a9a93bfff";
  static final String _appCertificate =
      dotenv.env['AGORA_APP_CERTIFICATE'] ?? "45aba7aeffe344768f07b78a9a93bfff";

  // عنوان خادم التوكن المحلي
  static String get _localTokenServerUrl {
    if (kIsWeb) {
      // استخدم عنوان نسبي للويب
      return "/token";
    }
    return "http://localhost:3000/token";
  }

  // مدة صلاحية التوكن بالثواني (ساعة واحدة)
  static const int _tokenExpiryInSeconds = 3600;

  // عنوان خادم التوكن الخارجي (من ملف .env)
  static final String _tokenServerUrl = dotenv.env['TOKEN_SERVER_URL'] ?? '';

  // إستخدام الخادم المحلي بدلاً من الخادم الخارجي (للتطوير)
  static bool _useLocalServer = true;

  /// الحصول على توكن أجورا من الخادم
  static Future<String?> getToken(String channelName, {int uid = 0}) async {
    try {
      // التحقق من صحة اسم القناة
      if (channelName.isEmpty) {
        print('[DEBUG-TOKEN-T001] خطأ: اسم القناة لا يمكن أن يكون فارغًا');
        throw Exception('اسم القناة لا يمكن أن يكون فارغًا');
      }

      print('[DEBUG-TOKEN-T002] طلب توكن لقناة: $channelName, uid: $uid');
      // استخدام الخادم المحلي على المنفذ 3000
      final tokenUrl =
          '$_localTokenServerUrl?channelName=$channelName&uid=$uid&role=1';
      print('[DEBUG-TOKEN-T003] عنوان طلب التوكن: $tokenUrl');

      try {
        final response = await http.get(Uri.parse(tokenUrl)).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('[DEBUG-TOKEN-T004] انتهت مهلة الاتصال بالخادم المحلي');
            return http.Response('Timeout', 408);
          },
        );

        print('[DEBUG-TOKEN-T005] استجابة الخادم: ${response.statusCode}');

        if (response.statusCode == 200) {
          print(
              '[DEBUG-TOKEN-T006] محتوى الاستجابة: ${response.body.substring(0, min(50, response.body.length))}...');

          try {
            final data = jsonDecode(response.body);
            print(
                '[DEBUG-TOKEN-T007] مفاتيح البيانات المستلمة: ${data.keys.toList()}');

            final String? token = data['token']?.toString();
            print(
                '[DEBUG-TOKEN-T008] التوكن المستلم: ${token != null ? (token.length > 10 ? '${token.substring(0, 10)}...' : token) : 'null'}');

            if (token == null) {
              print('[DEBUG-TOKEN-T009] خطأ: التوكن المستلم هو null');
            } else if (token.isEmpty) {
              print('[DEBUG-TOKEN-T010] خطأ: التوكن المستلم فارغ');
            } else {
              print('[DEBUG-TOKEN-T011] تم استلام توكن صالح');
            }

            return token;
          } catch (e) {
            print('[DEBUG-TOKEN-T012] خطأ في تحليل استجابة JSON: $e');
            print('[DEBUG-TOKEN-T013] استجابة الخادم الخام: ${response.body}');
            return _generateTemporaryToken(channelName, uid);
          }
        } else {
          print(
              '[DEBUG-TOKEN-T014] خطأ في الحصول على التوكن: ${response.statusCode}');
          print('[DEBUG-TOKEN-T015] محتوى الاستجابة: ${response.body}');
          return _generateTemporaryToken(channelName, uid);
        }
      } catch (e) {
        print('[DEBUG-TOKEN-T016] خطأ في الاتصال بالخادم: $e');
        print('[DEBUG-TOKEN-T017] نوع الخطأ: ${e.runtimeType}');
        return _generateTemporaryToken(channelName, uid);
      }
    } catch (e) {
      print('[DEBUG-TOKEN-T018] خطأ عام في الحصول على التوكن: $e');
      print('[DEBUG-TOKEN-T019] نوع الخطأ: ${e.runtimeType}');
      return _generateTemporaryToken(channelName, uid);
    }
  }

  /// إنشاء توكن مؤقت للاستخدام في حالة فشل خادم التوكن
  static String _generateTemporaryToken(String? channelName, int uid) {
    try {
      // التأكد من صحة اسم القناة
      final safeChannelName =
          (channelName?.isNotEmpty == true) ? channelName! : "defaultChannel";

      // إنشاء توكن بسيط للاختبار فقط
      // ملاحظة: هذا ليس آمنًا للإنتاج، استخدم خادم التوكن في بيئة الإنتاج
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiryTime = timestamp + _tokenExpiryInSeconds;

      final randomBytes =
          List<int>.generate(16, (_) => Random.secure().nextInt(256));
      final randomPart = base64Url.encode(randomBytes).substring(0, 8);

      // إنشاء توكن بسيط - للاختبار فقط
      final baseString = '$_appId:$safeChannelName:$uid:$expiryTime';
      final hmac = Hmac(sha256, utf8.encode(_appCertificate));
      final digest = hmac.convert(utf8.encode(baseString));
      final signature = base64Url.encode(digest.bytes);

      print('تم إنشاء توكن مؤقت: ${signature.substring(0, 10)}...');
      return '$signature$randomPart$expiryTime';
    } catch (e) {
      print('خطأ في إنشاء توكن مؤقت: $e');
      // في حالة الفشل، إرجاع توكن بسيط جدًا
      return "00635a72484a3c44179a015e80302361ebfIABUEFKPHQf${DateTime.now().millisecondsSinceEpoch}";
    }
  }

  /// الحصول على توكن للمذيع
  static Future<String?> getBroadcasterToken(String channelName,
      {int uid = 0}) async {
    try {
      if (kIsWeb) {
        return _generateFallbackToken(channelName, uid);
      }

      // استخدام الخادم المحلي على المنفذ 3000
      final tokenUrl =
          '$_localTokenServerUrl?channelName=$channelName&uid=$uid&role=2';
      print('جاري الحصول على توكن المذيع من: $tokenUrl');

      final response = await http.get(Uri.parse(tokenUrl)).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('انتهت مهلة الاتصال بالخادم المحلي');
          return http.Response('Timeout', 408);
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String? token = data['token']?.toString();
        return token;
      } else {
        print('خطأ في الحصول على توكن المذيع: ${response.statusCode}');
        return _generateFallbackToken(channelName, uid);
      }
    } catch (e) {
      print('خطأ في الحصول على توكن المذيع: $e');
      return _generateFallbackToken(channelName, uid);
    }
  }

  /// الحصول على توكن من خادم التوكن الخارجي
  static Future<String?> _getTokenFromServer(String channelName,
      {int uid = 0}) async {
    try {
      final Map<String, dynamic> body = {
        'channelName': channelName,
        'uid': uid,
      };

      final response = await http
          .post(
            Uri.parse(_tokenServerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String? token = data['token']?.toString();
        return token;
      } else {
        print('فشل الحصول على التوكن من الخادم. الرمز: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('خطأ في الاتصال بخادم التوكن: $e');
      return null;
    }
  }

  /// الحصول على توكن من خادم التوكن المحلي
  static Future<String?> _getTokenFromLocalServer(String channelName,
      {int uid = 0}) async {
    try {
      // التأكد من أن الخادم المحلي قيد التشغيل
      if (!AgoraTokenServer.isRunning) {
        await AgoraTokenServer.start();
        if (!AgoraTokenServer.isRunning) {
          print('فشل في بدء خادم التوكن المحلي');
          return _generateFallbackToken(channelName, uid);
        }
      }

      // إعداد طلب HTTP للخادم المحلي
      final client = http.Client();
      try {
        final serverUrl = await AgoraTokenServer.serverUrl;
        final response = await client
            .post(
              Uri.parse(serverUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'channelName': channelName,
                'uid': uid,
              }),
            )
            .timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          final String? token = data['token']?.toString();
          print('تم الحصول على توكن من الخادم المحلي للقناة: $channelName');
          return token;
        } else {
          print(
              'فشل الحصول على التوكن من الخادم المحلي: ${response.statusCode}');
          return _generateFallbackToken(channelName, uid);
        }
      } finally {
        client.close();
      }
    } catch (e) {
      print('خطأ في الاتصال بخادم التوكن المحلي: $e');
      return _generateFallbackToken(channelName, uid);
    }
  }

  /// توليد توكن احتياطي عند فشل جميع الطرق الأخرى
  /// هذا التوكن ليس حقيقياً ولكنه يسمح للتطبيق بالعمل في وضع المحاكاة
  static String _generateFallbackToken(String channelName, int uid) {
    print('استخدام توكن احتياطي للقناة: $channelName');
    // إنشاء توكن عشوائي لأغراض المحاكاة فقط
    final String randomId = const Uuid().v4();
    final Map<String, dynamic> mockTokenData = {
      'channelName': channelName,
      'uid': uid,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'mock': true,
      'id': randomId
    };
    return base64Encode(utf8.encode(jsonEncode(mockTokenData)));
  }

  /// تفعيل أو تعطيل استخدام خادم التوكن المحلي
  static void setUseLocalTokenServer(bool useLocal) {
    _useLocalServer = useLocal;
    print(_useLocalServer
        ? 'تم تفعيل استخدام خادم التوكن المحلي'
        : 'تم تعطيل استخدام خادم التوكن المحلي');
  }

  /// إيقاف تشغيل الخادم المحلي
  static Future<void> stopLocalServer() async {
    await AgoraTokenServer.stop();
  }

  /// التحقق مما إذا كان التوكن هو توكن احتياطي
  static bool isMockToken(String token) {
    try {
      final String decoded = utf8.decode(base64Decode(token));
      final Map<String, dynamic> data = jsonDecode(decoded);
      return data['mock'] == true;
    } catch (e) {
      return false;
    }
  }

  /// توليد توقيع للتحقق من التوكن
  static String _generateSignature(String data, String secret) {
    final key = utf8.encode(secret);
    final bytes = utf8.encode(data);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return digest.toString();
  }
}
