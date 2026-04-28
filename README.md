# Jeux Bibliques en Réseau

Application Flutter de jeux bibliques multijoueurs en temps réel.
Clients sur GitHub Pages · Backend Firebase (100% gratuit).

## Structure

```
biblical_games/
├── packages/
│   ├── core/           ← modèles, services Firebase, logique partagée
│   └── ui_components/  ← widgets communs
└── apps/
    ├── player/         ← Flutter Web (GitHub Pages) — les joueurs
    └── game_master/    ← Flutter Mobile/Desktop — l'animateur
```

## Jeux disponibles

| Jeu | Description |
|-----|-------------|
| 👤 Fiche Personnage | Deviner le personnage à partir d'indices |
| 🗺️ Carte Biblique | Placer un lieu sur la carte du Moyen-Orient |
| ✅ Vrai ou Faux | Affirmer ou infirmer une déclaration |
| 📅 Frise Chronologique | Remettre des événements dans l'ordre |
| 📖 Divine ton Verset | Trouver la référence d'un verset |
| ✍️ Rédaction de la Bible | Associer auteur / lieu / date à un livre |

## Mise en place

### 1. Prérequis

```bash
flutter --version   # >= 3.10
dart --version      # >= 3.0
```

### 2. Firebase

1. Aller sur [console.firebase.google.com](https://console.firebase.google.com)
2. Créer un projet (plan **Spark** = gratuit)
3. Activer **Firestore Database** (mode production)
4. Activer **Authentication** → méthode **Anonyme**
5. Activer **Storage** (optionnel, pour les photos)
6. Installer FlutterFire CLI et configurer :

```bash
dart pub global activate flutterfire_cli

# Dans apps/player/
cd apps/player && flutterfire configure

# Dans apps/game_master/
cd apps/game_master && flutterfire configure
```

Cela génère `lib/firebase_options.dart` dans chaque app.

### 3. Déployer les règles Firestore

```bash
npm install -g firebase-tools
firebase login
firebase deploy --only firestore:rules
```

### 4. Lancer en local

```bash
# Joueur (Web)
cd apps/player
flutter pub get
flutter run -d chrome

# Game Master (Mobile ou desktop)
cd apps/game_master
flutter pub get
flutter run -d <device>
```

### 5. Déployer sur GitHub Pages

1. Créer un repo GitHub public `biblical-games`
2. Dans **Settings → Pages** : activer GitHub Actions
3. Ajouter les secrets dans **Settings → Secrets → Actions** :
    - `FIREBASE_API_KEY`
    - `FIREBASE_APP_ID`
    - `FIREBASE_SENDER_ID`
    - `FIREBASE_PROJECT_ID`
    - `FIREBASE_AUTH_DOMAIN`
    - `FIREBASE_STORAGE_BUCKET`
4. Dans `.github/workflows/deploy_player.yml`, remplacer `/biblical-games/` par le nom de ton repo
5. Dans `apps/game_master/lib/screens/control_screen.dart`, mettre à jour `baseUrl`
6. `git push origin main` → déploiement automatique !

L'app sera disponible sur : `https://noamcreator.github.io/biblical-games/`

## Flux de jeu

```
Game Master                     Joueurs
     │                              │
     ├─ Créer salle (code: RUTH-42) │
     │                              ├─ Ouvrir l'URL / scanner QR
     │                              ├─ Entrer le code + prénom
     │                              ├─ Attente dans le lobby
     ├─ Lancer la partie ──────────►│ Redirection automatique
     ├─ Afficher question ─────────►│ Question affichée
     │                              ├─ Répondre → score mis à jour
     ├─ Correction ───────────────►│ Explication affichée
     ├─ Question suivante ─────────►│ Prochaine question
     ├─ Fin ───────────────────────►│ Classement final
```

## Ajouter du contenu

Le contenu (fiches perso, versets, etc.) est stocké dans la collection `questions` de Firestore.
Tu peux l'éditer via la **Console Firebase** ou créer un script d'import.

Exemple d'import depuis les modèles :
```dart
// Dans un script ou une page admin
final db = FirebaseFirestore.instance;
for (final fiche in FichePerso.exemples) {
  await db.collection('questions')
    .doc('fiche_${fiche.id}')
    .set(fiche.toMap());
}
```

## Plan gratuit Firebase (Spark)

| Ressource | Limite gratuite |
|-----------|----------------|
| Firestore lectures | 50 000 / jour |
| Firestore écritures | 20 000 / jour |
| Storage | 5 GB |
| Auth | Illimité |
| Hosting | 10 GB transfert / mois |

Largement suffisant pour des jeux en groupe !