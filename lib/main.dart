import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/main_page.dart';
import 'services/socket_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv;
import 'services/agora_service.dart';
import 'services/agora_token_server.dart';
import 'pages/live_stream_simulation_page.dart';
import 'dart:io'; // استيراد حزمة dart:io للوصول إلى NetworkInterface
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

// كائن SocketService عام للوصول إليه من جميع أنحاء التطبيق
final socketService = SocketService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await dotenv.dotenv.load(fileName: '.env');

  // إزالة شاشة البداية البيضاء عن طريق تعيين لون الخلفية
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: AppTheme.primaryColor,
    statusBarIconBrightness: Brightness.light,
  ));

  try {
    // تهيئة App Check
    if (kIsWeb) {
      // تخطي AppCheck على الويب لتفادي مشاكل ReCAPTCHA
      print('تخطي تفعيل AppCheck على الويب لتجنب مشاكل ReCAPTCHA');
      // يمكن تعطيله مؤقتًا على الويب
      /*
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider('6LcD-I4pAAAAAKHGvbC7iMGKIg3vQwC3HVoH4x5w'),
      );
      */
    } else {
      // للمنصات الأخرى
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.appAttest,
      );
    }
    print('App Check initialized successfully');

    // تهيئة إعدادات اللغة
    await FirebaseAuth.instance.setLanguageCode('ar');
    print('Auth language set to Arabic');

    // تعريف مستمع لحالة المصادقة
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        // إعداد Socket.IO عند تسجيل دخول المستخدم
        print('تهيئة اتصال Socket.IO للمستخدم: ${user.uid}');
        socketService.initialize(userId: user.uid);
      }
    });

    // بدء تشغيل خادم التوكن المحلي
    if (kIsWeb) {
      print('جاري تخطي بدء خادم التوكن على متصفح الويب');
    } else {
      print('محاولة بدء خادم التوكن المحلي');
      try {
        await _configureTokenServer();
      } catch (e) {
        print('خطأ في بدء خادم التوكن المحلي: $e');
        print('سيتم الاعتماد على خادم التوكن الخارجي');
      }
    }
  } catch (e, stackTrace) {
    print('Error initializing Firebase: $e');
    print('Stack trace: $stackTrace');
  }

  runApp(const MyApp());
}

// دالة لاكتشاف عنوان IP المحلي وتكوين عنوان خادم التوكن
Future<void> _configureTokenServer() async {
  try {
    // محاولة الاتصال بخادم التوكن على localhost أولاً
    final localhostUrl = 'http://localhost:3000/token';
    try {
      final response = await http.get(
          Uri.parse('$localhostUrl?channelName=test_channel&uid=0&role=1'));
      if (response.statusCode == 200) {
        print('✅ تم الاتصال بخادم التوكن على localhost بنجاح');
        AgoraService.tokenServerUrl = localhostUrl;
        return;
      }
    } catch (e) {
      print('⚠️ فشل الاتصال بخادم التوكن على localhost: $e');
    }

    // إذا فشل الاتصال بـ localhost، جرب العثور على عنوان IP محلي
    print('🔍 جاري البحث عن عنوان IP محلي...');
    final interfaces = await NetworkInterface.list();
    String? localIp;

    for (var interface in interfaces) {
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 &&
            !addr.address.startsWith('127.') &&
            !addr.address.startsWith('169.254.')) {
          localIp = addr.address;
          print(
              '✅ تم العثور على عنوان IP محلي: $localIp على واجهة ${interface.name}');
          break;
        }
      }
      if (localIp != null) break;
    }

    if (localIp != null) {
      final ipUrl = 'http://$localIp:3000/token';
      try {
        final response = await http
            .get(Uri.parse('$ipUrl?channelName=test_channel&uid=0&role=1'));
        if (response.statusCode == 200) {
          print('✅ تم الاتصال بخادم التوكن على $localIp بنجاح');
          AgoraService.tokenServerUrl = ipUrl;
          return;
        }
      } catch (e) {
        print('⚠️ فشل الاتصال بخادم التوكن على $localIp: $e');
      }
    }

    // إذا فشلت جميع المحاولات، استخدم localhost كخيار أخير
    print('⚠️ استخدام localhost كخيار أخير');
    AgoraService.tokenServerUrl = localhostUrl;
  } catch (e) {
    print('❌ خطأ في تكوين خادم التوكن: $e');
    AgoraService.tokenServerUrl = 'http://localhost:3000/token';
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // تعديل السمة الحالية لاستخدام خط Tajawal
    final ThemeData baseTheme = ThemeData(
      primaryColor: AppTheme.primaryColor,
      scaffoldBackgroundColor: AppTheme.backgroundColor,
      colorScheme: const ColorScheme.dark(
        primary: AppTheme.primaryColor,
        secondary: AppTheme.secondaryColor,
      ),
    );

    final textTheme = GoogleFonts.tajawalTextTheme(baseTheme.textTheme);

    final updatedTheme = baseTheme.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: Colors.transparent,
    );

    return MaterialApp(
      title: 'تطبيق التنجيم',
      theme: updatedTheme,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SA'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', 'SA'), // Arabic
        Locale('en', 'US'), // English
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
                boldText: false, textScaler: const TextScaler.linear(1.0)),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.gradientTop,
                    AppTheme.gradientMiddle1,
                    AppTheme.gradientMiddle2,
                    AppTheme.gradientBottom,
                  ],
                  stops: [0.0, 0.3, 0.6, 1.0],
                ),
              ),
              child: child!,
            ),
          ),
        );
      },
      home: const AuthGate(),
      routes: {
        '/register': (context) => const RegisterPage(),
        '/login': (context) => const LoginPage(),
      },
    );
  }
}

// شاشة لتحديد وجهة المستخدم بناءً على حالة تسجيل الدخول
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // عرض مؤشر تحميل أثناء التحقق من حالة المستخدم
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.gradientTop,
                    AppTheme.gradientMiddle1,
                    AppTheme.gradientMiddle2,
                    AppTheme.gradientBottom,
                  ],
                  stops: [0.0, 0.3, 0.6, 1.0],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // إضافة شعار التطبيق بحجم أصغر
                    Image.asset(
                      'assets/logo.png',
                      width: 160,
                      height: 180,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 30),
                    const CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'جاري التحميل...',
                      style: GoogleFonts.tajawal(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // تحقق ما إذا كان المستخدم مسجل الدخول
        if (snapshot.hasData && snapshot.data != null) {
          // تهيئة خدمة Socket.IO عند تسجيل الدخول
          socketService.initialize(userId: snapshot.data!.uid);
          return MainPage(userId: snapshot.data!.uid);
        }

        // إذا لم يكن المستخدم مسجل الدخول، عرض صفحة تسجيل الدخول
        return const LoginPage();
      },
    );
  }
}
