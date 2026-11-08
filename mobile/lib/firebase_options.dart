import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyAW-SFzZ4XTJy0y7n1gZwmU2_rNqqsOiNY',
    appId: '1:933534347521:web:bc2973345f3004f082ab00',
    authDomain: 'pokou-3b047.firebaseapp.com',
    measurementId: 'G-9107YJTE0Q',
    messagingSenderId: '933534347521',
    projectId: 'pokou-3b047',
    storageBucket: 'pokou-3b047.firebasestorage.app',
  );

  /// iOS — application « Pokou iOS » du projet pokou-3b047 (com.pokou.pokou).
  /// Passées à `Firebase.initializeApp` : pas besoin que
  /// GoogleService-Info.plist soit déclaré dans le projet Xcode.
  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyCq1Qu3nIyjitE3gA4Dtg-nnz7kkg875XU',
    appId: '1:933534347521:ios:2222b4d6fa8f941582ab00',
    messagingSenderId: '933534347521',
    projectId: 'pokou-3b047',
    storageBucket: 'pokou-3b047.firebasestorage.app',
    iosBundleId: 'com.pokou.pokou',
  );
}
