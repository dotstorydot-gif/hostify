// File generated & configured for .Hostify
// Firebase Project: hostify-10c0f (409314884131)

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyPlaceholderWebKey',
    appId: '1:409314884131:web:4caff5d0200d90f5bc0f96',
    messagingSenderId: '409314884131',
    projectId: 'hostify-10c0f',
    authDomain: 'hostify-10c0f.firebaseapp.com',
    storageBucket: 'hostify-10c0f.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyPlaceholderAndroidKey',
    appId: '1:409314884131:android:a696eda49d3f7114bc0f96',
    messagingSenderId: '409314884131',
    projectId: 'hostify-10c0f',
    storageBucket: 'hostify-10c0f.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyPlaceholderIosKey',
    appId: '1:409314884131:ios:15cea3d63b2c7dc5bc0f96',
    messagingSenderId: '409314884131',
    projectId: 'hostify-10c0f',
    storageBucket: 'hostify-10c0f.firebasestorage.app',
    iosClientId: '409314884131-placeholder.apps.googleusercontent.com',
    iosBundleId: 'com.dot.hostify',
  );
}
