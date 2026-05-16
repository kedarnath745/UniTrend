# UniTrend™ — AI-Native Trend Intelligence Terminal

UniTrend is a cross-platform Flutter app that unifies trending signals from seven heterogeneous sources — **YouTube, Reddit, News, GitHub, Hacker News, Product Hunt, and Dev.to** — into a single ranked "Intelligence Terminal." It scores, clusters, and summarizes what is trending *right now* and surfaces it through a Material 3 UI with proactive notifications.

---

## Features

- **Unified ranking engine** — source-weighted min-max normalization with exponential 24h-half-life recency decay
- **Cross-platform clustering** — groups items about the same topic across all seven sources
- **Signal Radar** — hero cards + Shneiderman treemap for visualizing scale and sentiment
- **LLM synthesis** — Groq (LLaMA-3.1-8B) generates cluster summaries, cross-platform perspectives, and an interactive chat agent
- **Watchlists & velocity alerts** — get notified when a tracked keyword spikes
- **Morning digest** — 8:00 AM AI-summarized briefing scheduled via WorkManager
- **Reading history, deep links, region-aware feed** (auto-detects device locale)

## Tech Stack

| Layer | Tech |
|---|---|
| Framework | Flutter 3.10+ (Material 3) |
| State | Riverpod (clean architecture, modular providers) |
| Backend | Firebase (Auth, Firestore, Storage, Cloud Messaging) |
| Background | WorkManager (Android) |
| AI | Groq Cloud LPU |
| Cloud Functions | Node.js 20 (FCM scheduled triggers) |
| Data Sources | YouTube Data API v3, Reddit JSON, NewsAPI, GitHub Search, HN, Product Hunt, Dev.to |

---

## Prerequisites

- **Flutter SDK** 3.10.8 or later — [install guide](https://docs.flutter.dev/get-started/install)
- **Android Studio** (for Android builds) or **Xcode** (for iOS)
- **Node.js 20+** (only if deploying Cloud Functions)
- **Firebase CLI** (only if deploying Cloud Functions): `npm install -g firebase-tools`

You will also need free API keys from:
- [Groq Cloud](https://console.groq.com/) — for LLM inference
- [NewsAPI.org](https://newsapi.org/) — for news headlines
- [Google Cloud Console](https://console.cloud.google.com/) → enable **YouTube Data API v3**

---

## Setup

### 1. Clone & install

```bash
git clone <your-repo-url> unitrend
cd unitrend
flutter pub get
```

### 2. Create the API keys file

Create `.env` in the project root (already gitignored):

```env
GROQ_API_KEY=gsk_your_groq_key_here
NEWS_API_KEY=your_newsapi_key_here
YOUTUBE_API_KEY=your_youtube_data_v3_key_here
```

### 3. Configure Firebase

The repo ships with a placeholder `android/app/google-services.json` and `lib/firebase_options.dart` pointing at the original development project. To use your own Firebase project:

```bash
# install the FlutterFire CLI once
dart pub global activate flutterfire_cli

# generate fresh config files for your project
flutterfire configure
```

This regenerates `firebase_options.dart` and `google-services.json` (Android) / `GoogleService-Info.plist` (iOS).

In the Firebase console, enable:
- **Authentication** → Email/Password and Google sign-in
- **Cloud Firestore** (start in production mode; rules can be tightened later)
- **Cloud Messaging** (for push notifications)

### 4. (Optional) Deploy Cloud Functions

Cloud Functions send the silent FCM wake-ups every 3 hours and the morning-digest trigger at 8 AM IST. The app works without them — local WorkManager covers Android — but you need them for cross-device push.

```bash
cd functions
npm install
firebase deploy --only functions
```

---

## Run

```bash
# Android device or emulator
flutter run

# iOS (macOS only)
cd ios && pod install && cd ..
flutter run

# Web (limited — background service is Android-only)
flutter run -d chrome

# Release APK
flutter build apk --release
```

The first launch will request notification permission (Android 13+) and prompt for Google sign-in.

---

## Project Structure

```
lib/
├── main.dart                  # Entry point, Riverpod scope, BG service init
├── firebase_options.dart      # FlutterFire-generated config
├── models/                    # TrendItem, Cluster, Watchlist, etc.
├── providers/                 # Riverpod providers (feed, auth, watchlist, theme)
├── services/                  # API clients, TrendEngine, BackgroundService, LLM
├── screens/                   # Feed, Radar, Chat, Watchlist, Profile, Settings
├── widgets/                   # Reusable UI (cards, treemap, skeletons)
└── theme/                     # Material 3 colour scheme + typography

functions/                     # Firebase Cloud Functions (Node 20)
android/, ios/, web/, ...      # Platform shells
assets/icons/                  # App icons
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `flutter pub get` fails | Confirm Flutter ≥ 3.10.8: `flutter --version` |
| Empty feed on launch | Check `.env` exists at project root and contains all three keys |
| Google sign-in fails | Re-run `flutterfire configure` so SHA-1 matches your machine's debug keystore |
| No background notifications | Android only; disable battery optimization for the app in system settings |
| Build fails on iOS | Run `cd ios && pod install` after every `flutter pub get` |

---

## Documentation

The full research write-up — *"UniTrend: A Cross-Platform Mobile Framework for Unified Social Trend Aggregation"* — lives in [`docs/REPORT.md`](./docs/REPORT.md).

## License

See [LICENSE](./LICENSE).
