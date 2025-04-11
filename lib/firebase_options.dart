import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAHprGUvVMn_KPWsTuI_YRULihOiUecS5w',
    appId: '1:776961382756:android:74f9698db63760e1958271',
    messagingSenderId: '776961382756',
    projectId: 'astrology-d317e',
    storageBucket: 'astrology-d317e.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAHprGUvVMn_KPWsTuI_YRULihOiUecS5w',
    appId: '1:776961382756:ios:74f9698db63760e1958271',
    messagingSenderId: '776961382756',
    projectId: 'astrology-d317e',
    storageBucket: 'astrology-d317e.appspot.com',
    iosClientId: '776961382756-app-version14sa.apps.googleusercontent.com',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCIsFZWb-FF_9y3mOZSBwI1TB5er3rXNUU',
    appId: '1:776961382756:web:f8bd64f9dfc26cd7958271',
    messagingSenderId: '776961382756',
    projectId: 'astrology-d317e',
    authDomain: 'astrology-d317e.firebaseapp.com',
    storageBucket: 'astrology-d317e.appspot.com',
    measurementId: 'G-LWN0DNF85G',
  );
}
