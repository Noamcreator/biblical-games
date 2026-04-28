// ⚠️  IMPORTANT : Remplace ces valeurs par celles de ta console Firebase
// https://console.firebase.google.com → Paramètres du projet → Tes applications

// Pour Flutter Web (apps/player/web/index.html), ajoute aussi le snippet JS.
// Pour Flutter Mobile/Desktop, utilise google-services.json (Android)
// ou GoogleService-Info.plist (iOS/macOS).

// Ce fichier documente la configuration attendue.
// Les clés réelles sont dans firebase_options.dart (généré par FlutterFire CLI).

// ─── Comment générer firebase_options.dart ───────────────────
// 1. Installe FlutterFire CLI :
//    dart pub global activate flutterfire_cli
//
// 2. Dans le dossier de chaque app (player/ ou game_master/), lance :
//    flutterfire configure
//
// 3. Sélectionne ton projet Firebase → ça génère lib/firebase_options.dart
//
// 4. Dans main.dart :
//    await Firebase.initializeApp(
//      options: DefaultFirebaseOptions.currentPlatform,
//    );

/// Constantes pour les collections Firestore
class FirestoreCollections {
  static const sessions = 'sessions';
  static const answers = 'answers';
  static const questions = 'questions';
}

/// Règles suggérées pour firestore.rules (voir le fichier à la racine)
const suggestedFirestoreRules = '''
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Sessions : lecture libre, écriture pour les membres
    match /sessions/{sessionCode} {
      allow read: if true;
      allow create: if request.auth != null;
      allow update: if request.auth != null;

      match /answers/{answerId} {
        allow read, write: if request.auth != null;
      }
    }

    // Questions : lecture libre (contenu du jeu)
    match /questions/{questionId} {
      allow read: if true;
      allow write: if request.auth.token.admin == true;
    }
  }
}
''';