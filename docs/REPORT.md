# UniTrend: A Cross-Platform Mobile Framework for Unified Social Trend Aggregation with LLM-Based Synthesis and Proactive Intelligence

**Author:** Yeramaneni Kedarnath Chowdary
**Affiliation:** [Department, University]
**Email:** kedarnath1157@gmail.com

---

## Abstract

Modern digital audiences consume information across fragmented platforms — YouTube, Reddit, mainstream news, GitHub, Hacker News, Product Hunt, and Dev.to — each with its own ranking, bias, and recency model. Discovering what is *actually* trending across the web therefore requires manually polling several apps. This paper presents **UniTrend**, a cross-platform Flutter application that unifies trending signals from seven heterogeneous sources into a single ranked feed, detects cross-source topic clusters, labels emotional tone via a rule-based sentiment engine, and produces large-language-model (LLM) summaries, chat, cross-platform perspective comparisons, and morning briefings using the Groq LLaMA-3.1 API. A recency-decayed, source-weighted min-max normalization model combined with a union-find keyword clustering algorithm reduces unified ranking to a deterministic O(n²·α(n)) pipeline suitable for on-device execution. A background service driven by WorkManager delivers velocity-based "breakout" alerts and a daily 8 AM AI-generated digest even when the app is closed. A personalization engine weights the feed by per-source, per-cluster, and per-keyword affinity derived from user feedback, bookmarks, and search history. The flagship **Signal Radar** offers both hero-card and Shneiderman treemap visualizations that communicate relative trend scale at a glance. The final system integrates 100 source files, a 804-node / 6318-edge code knowledge graph, Firebase Authentication with email/password, Google Sign-In and phone OTP, and Cloud Firestore-backed personalization, watchlists, bookmarks and reading history. Results indicate the approach delivers sub-second cold feed rendering from cache, meaningful cross-platform clustering, and actionable LLM briefings within a ≤20 s latency budget on consumer Android devices.

**Index Terms —** Flutter, Dart, Riverpod, Trend Analysis, Social Media Aggregation, Large Language Models, Groq, LLaMA, Union-Find Clustering, Recency Decay, Rule-Based Sentiment Analysis, WorkManager, Firebase, Firestore, FCM, Background Notifications, Treemap Visualization, Material 3, Clean Architecture, Mobile Information Retrieval.

---

## I. INTRODUCTION

Social information is increasingly siloed. A story that dominates mainstream news may be absent from Reddit; a GitHub release that reshapes developer practice may never reach YouTube; a niche Hacker News discussion may precede a mainstream story by hours. A Product Hunt launch may be driving conversation on Dev.to yet invisible to a Flipboard reader. The end user — seeking a coherent "what's happening now" view — must mentally merge several ranked lists drawn from incompatible ranking functions. This imposes cognitive load, reinforces filter bubbles, and hides cross-platform corroboration that would otherwise strengthen a reader's confidence in a story.

Existing aggregators prioritize recency or editorial selection. Google News and Apple News use opaque ML ranking without exposing *why* an item is trending, how multiple platforms are framing the same topic, or when a signal is genuinely accelerating. Feedly concentrates on RSS subscription management rather than discovery. Flipboard performs topic curation but does not surface real-time velocity. Developer-oriented aggregators such as daily.dev and Hacker News excel within a single vertical but do not cross-cut into news or social culture.

**UniTrend** addresses these gaps with six research and engineering contributions:

1. **A unified trend data model** (`TrendItem`) that normalizes seven source-specific APIs — YouTube Data API v3, Reddit JSON, NewsAPI / RSS, GitHub Search, Hacker News (Algolia), Product Hunt RSS, and Dev.to — into a single schema with a recency-decayed score, sentiment label, cluster ID, and tag vector.

2. **A deterministic Trend Intelligence Engine** that applies source-weighted score normalization, exponential recency decay (λ = ln 2 / 24), headline-noise-filtered tag extraction, union-find keyword clustering, momentum labelling (rising/stable/cooling), and Jaccard near-duplicate suppression in a single on-device pipeline.

3. **A rule-based Sentiment Engine** that classifies every item into {neutral, positive, critical, controversial} using curated keyword lexicons, with a Reddit-biased 1.5× controversial boost reflecting the platform's discursive style.

4. **LLM-based synthesis** using Groq's `llama-3.1-8b-instant` endpoint across five distinct interaction modes: per-item summaries, multi-turn cluster chat, cross-platform perspective comparison, morning briefings, and velocity-alert blurbs.

5. **A Personalization Engine** that rescores the global feed by per-source affinity, per-cluster affinity, per-keyword affinity with recency decay, and explicit bookmarks/feedback — producing a rank multiplier in the clamped range [0.25, 1.9].

6. **Proactive intelligence**: a WorkManager-scheduled background service that persists per-cluster historical scores, emits velocity-based breakout alerts when a cluster's score jumps more than 25 points, and delivers a scheduled 8 AM LLM-authored digest — all without requiring the foreground process.

The remainder of this paper is organized as follows. Section II surveys related work. Section III describes the system architecture and the layered clean-architecture decomposition. Section IV details the methodology of the Trend Intelligence, Sentiment, and Personalization engines. Section V covers the implementation including data sources, authentication, Firestore schema, background tasks, deep linking, theming, onboarding, and the complete widget catalog. Section VI presents quantitative and qualitative results. Section VII discusses limitations and ethical considerations. Section VIII concludes with future work.

---

## II. RELATED WORK

**News and content aggregators.** Google News and Apple News employ editorial-plus-ML pipelines with opaque ranking and no cross-platform clustering exposed to end users. Feedly focuses on RSS subscription rather than discovery. Flipboard applies topic curation but without real-time signal velocity, cross-source comparison, or LLM synthesis.

**Developer-facing trend tools.** daily.dev and GitHub Trending restrict themselves to developer-vertical content. Hacker News exposes a single hand-tuned ranking formula (score − time-decay) but offers no cross-source view and no notion of personalization beyond hide/flag actions.

**Trend and topic detection literature.** Burst detection [1] remains a standard for emerging-topic identification. Topic modelling via Latent Dirichlet Allocation [2] and TF-IDF-based keyword extraction are classical techniques. More recent work uses dense embeddings and transformer-based clustering, but such approaches impose latency and model-hosting costs that are unattractive for always-on-device mobile execution.

**LLM-assisted summarization.** Retrieval-augmented generation (RAG) [3] over news corpora has been studied for enterprise search. Few consumer-facing mobile apps have integrated low-latency LLM endpoints at the cluster level as a first-class UX affordance.

**Visualization.** Shneiderman's slice-and-dice treemap [14] remains the canonical hierarchical area visualization; UniTrend adopts it for cluster-scale perception. Community detection in large graphs [15] underpins the architectural decomposition analysis described in §III-D.

UniTrend's differentiator is the combination of (i) seven-source live ingestion, (ii) deterministic on-device ranking suitable for offline-first operation, (iii) LLM synthesis wrapped in a proactive notification layer, and (iv) a personalization engine with explainable scalar multipliers — all integrated into a single free mobile client.

---

## III. SYSTEM ARCHITECTURE

### A. Architectural Layering

UniTrend follows a clean-architecture layering pattern expressed through Flutter's idiomatic folder structure and Riverpod for reactive state. Figure 1 conceptualizes the flow.

```
┌────────────────────────────────────────────────────────────┐
│                    UI LAYER (screens/, widgets/)           │
│  SplashScreen · OnboardingScreen · AuthScreens             │
│  MainShell · HomeScreen · RadarScreen · ClusterDetail      │
│  SearchScreen · ProfileScreen · NotificationPrefs          │
│  WatchlistScreen · SavedDashboardsScreen                   │
└────────────────────────────▲───────────────────────────────┘
                             │  WidgetRef.watch / read
┌────────────────────────────┴───────────────────────────────┐
│                 STATE LAYER (providers/)                   │
│  feedProvider · filteredFeedProvider · clusterAlertProvider│
│  personalizedFeedProvider · personalizationProvider        │
│  watchlistProvider · bookmarkProvider · savedDashboards    │
│  recentlyViewedProvider · readingHistoryProvider           │
│  scoreHistoryProvider · filterStateProvider · themeProvider│
│  authProvider · userProvider · radarClustersProvider       │
└────────────────────────────▲───────────────────────────────┘
                             │  service method calls
┌────────────────────────────┴───────────────────────────────┐
│              DOMAIN / SERVICE LAYER (services/)            │
│  TrendEngine · SentimentEngine · PersonalizationEngine     │
│  GroqService · NotificationService · BackgroundService     │
│  FeedCacheService · ScoreHistoryService · FcmService       │
│  ShareService · DeepLinkService                            │
└────────────────────────────▲───────────────────────────────┘
                             │  HTTP / Firebase SDK
┌────────────────────────────┴───────────────────────────────┐
│                   DATA / SOURCE LAYER                      │
│  YouTubeService · RedditService · NewsService              │
│  GitHubService · TechService (HN · PH · Dev.to)            │
│  AuthService · FirestoreService · StorageService           │
└────────────────────────────────────────────────────────────┘
```
*Fig. 1. Layered architecture of UniTrend.*

The source layer provides `fetchTrending()` and `search()` methods per platform, each returning `List<TrendItem>`. The domain layer consumes these lists and produces a single ranked, clustered, sentiment-annotated list. Providers expose results as `AsyncValue<T>` reactive streams to the UI, which is built from composable Material 3 widgets.

### B. Dependency Graph

Dependencies strictly flow downward — UI imports state, state imports services, services import data. No upward imports exist. This was verified via the static code-graph constructed with Tree-sitter (see §III-D).

### C. Unified Trend Data Model

Every source is mapped onto a `TrendItem` struct with the following fields:

| Field              | Type          | Purpose                                                  |
| ------------------ | ------------- | -------------------------------------------------------- |
| `id`               | `String`      | Stable deduplication key                                 |
| `title`            | `String`      | Display title                                            |
| `description`      | `String?`     | Optional long-form body                                  |
| `url`              | `String`      | Canonical deep link                                      |
| `thumbnailUrl`     | `String?`     | Display image (YouTube, News)                            |
| `source`           | `enum Source` | `youtube`, `reddit`, `news`, `github`, `hackerNews`, `productHunt`, `devTo` |
| `sourceLabel`      | `String`      | Human-readable source tag                                |
| `publishedAt`      | `DateTime`    | Used for recency decay                                   |
| `score`            | `double`      | Raw platform score (views, upvotes, stars…)             |
| `normalizedScore`  | `double`      | Output of §IV-B                                          |
| `momentum`         | `String`      | `rising` / `stable` / `cooling`                          |
| `clusterId`        | `String?`     | Assigned in §IV-E                                         |
| `tags`             | `List<String>`| From §IV-D                                                |
| `trendingReason`   | `String?`     | Human-readable one-liner                                 |
| `sentiment`        | `String`      | `neutral` / `positive` / `critical` / `controversial`   |
| `authorName`       | `String?`     | Creator / outlet / submitter                             |
| `authorAvatarUrl`  | `String?`     | Optional                                                 |
| `channel`          | `String?`     | Subreddit / YouTube channel / repo owner                 |

The model is serialization-complete (`toMap`/`fromMap`) for local caching via SharedPreferences (`FeedCacheService`) and for transport to isolate workers.

### D. Static Code Knowledge Graph

A Tree-sitter-based knowledge graph of the Dart source tree yields:

| Metric          | Value   |
| --------------- | ------- |
| Nodes           | 804     |
| Edges           | 6318    |
| Files           | 100     |
| Communities     | 11      |
| CALLS edges     | ≈ 4900  |
| CONTAINS edges  | ≈ 700   |
| IMPORTS edges   | ≈ 510   |
| INHERITS edges  | ≈ 170   |

The largest three communities correspond exactly to the intended architectural layers: `screens-state` (UI ↔ providers), `services-fetch` (source layer + HTTP), and `widgets-state` (reusable widgets + provider binding). This confirms the clean-architecture boundary is preserved empirically, not merely by convention.

---

## IV. METHODOLOGY — INTELLIGENCE ENGINES

### A. The Trend Intelligence Engine

The Trend Intelligence Engine (`lib/services/trend_engine.dart`) receives raw per-source lists and produces one ranked, clustered list. The pipeline is deterministic, single-pass, and requires no training.

#### 1) Step 1 — Source-Weighted Min-Max Normalization

Raw scores are incomparable across platforms. YouTube reports view counts in millions; Reddit upvotes in thousands; GitHub stars in hundreds. For each source group, we apply min-max normalization to the closed interval [0, 100], then scale by a per-source weight `w_s` and a small-group dampening factor `d_s`:

$$S_{\text{norm}}(x) = \frac{x - \min_s}{\max_s - \min_s} \times 100 \times w_s \times d_s$$

Empirically tuned weights:

| Source       | Weight `w_s` | Rationale                                               |
| ------------ | ------------ | ------------------------------------------------------- |
| GitHub       | 1.2          | Developer signals are durable and high-quality          |
| Reddit       | 1.1          | Discussion richness correlates with cultural relevance  |
| News         | 1.0          | Baseline reference                                      |
| YouTube      | 0.8          | View counts skew toward viral-but-shallow content       |
| Product Hunt | 0.7          | Niche audience, narrow topic band                       |
| Hacker News  | 0.5          | Already covered by GitHub for developer content         |
| Dev.to       | 0.5          | Reduces tutorial-post dominance                         |

Dampening `d_s = 0.8` is applied when a source group yields ≤ 2 items (prevents a single outlier from dominating). `max_s == min_s` short-circuits to 50 to avoid division by zero.

#### 2) Step 2 — Exponential Recency Decay

A 24-hour half-life is applied to every normalized score:

$$S_{\text{final}}(x) = S_{\text{norm}}(x) \cdot e^{-\lambda \cdot t},\quad \lambda = \frac{\ln 2}{24}$$

where `t` is item age in hours. A 48-hour-old article retains 25% of its weight; a week-old article retains approximately 0.4%. This aligns the feed with "what is happening now" rather than "what was ever popular."

#### 3) Step 3 — Tag Extraction with Headline-Noise Filtering

Titles are tokenized on non-alphanumeric boundaries, lowercased, and filtered against a curated stop-word list of ~200 English and headline-noise words, grouped into semantic categories:

- **Articles and prepositions:** the, a, an, in, on, at, to, from, of, with, by, for, off, up, down.
- **Auxiliaries and modals:** is, are, was, were, be, been, being, have, has, had, do, did, will, would, can, could, may, might, must, should.
- **Pronouns:** he, she, they, them, his, her, their, theirs, you, your, yours, we, us, our.
- **Headline clickbait verbs:** reveals, says, says, claims, shocks, exposes, slams, blasts, torches, rips, announces, unveils.
- **Headline adjectives:** breaking, live, exclusive, huge, massive, shocking, stunning, surprising, official, latest, new, top, best.
- **Quantifiers and time:** today, tomorrow, yesterday, now, soon, ago, this, that, these, those, some, any, every, all.

The top six unique tokens of length > 3 are retained as the item's tag set. The stop-word set was iteratively expanded during development to reduce tabloid-style false-positive clusters.

#### 4) Step 4 — Union-Find Keyword Clustering

A disjoint-set (union-find) structure over the N-item feed is built with path compression. Two items `a, b` are unioned if either:

- **Rule 1 — Canonical Domain Match:** their URLs resolve to the same canonical domain path. `github.com/owner/repo` (first two path segments) and `reddit.com/r/subreddit` (first two path segments) are clustered this way. News outlets and YouTube channels are *explicitly excluded* from domain clustering because a single outlet carries many unrelated stories.

- **Rule 2 — Shared Significant Tags:** they share three or more significant tags: `|tags(a) ∩ tags(b)| ≥ 3`.

Items in a connected component of size ≥ 2 are assigned a stable string `clusterId` derived from the hash of the root's tag tuple. Complexity is O(n²·α(n)) where α is the inverse Ackermann function, effectively linear. This is acceptable for the ≤ 200-item feeds handled on-device.

#### 5) Step 5 — Momentum Labelling

Each item receives a categorical momentum label:

- `rising` if `age ≤ 6 h` and `S_final ≥ 35`
- `cooling` if `age > 48 h` or `S_final < 15`
- `stable` otherwise

These labels drive color and icon choices in the UI (`↗`, `→`, `↘`).

#### 6) Step 6 — Jaccard Near-Duplicate Suppression

Within each cluster, pairs of items with Jaccard title-token similarity > 0.9 are treated as the same story. The lower-scoring of the pair is dropped. This prevents, e.g., a syndicated news story appearing three times in the top ten.

$$J(a,b) = \frac{|\text{tokens}(a) \cap \text{tokens}(b)|}{|\text{tokens}(a) \cup \text{tokens}(b)|}$$

### B. Sentiment Engine

A rule-based `SentimentEngine` (`lib/services/sentiment_engine.dart`) assigns one of four labels using three curated keyword lexicons applied to the concatenation of title and description:

- **Positive (~50 keywords):** win, wins, victory, success, breakthrough, milestone, record, surge, surges, soars, rally, rallies, boom, growth, historic, landmark, achievement, launched, unveiled, saves, rescues, funds, raised, funding, partnership, agreement, peace, progress.
- **Critical (~60 keywords):** crash, crashes, collapses, plunges, tumbles, lawsuit, sues, fraud, scandal, fired, banned, layoffs, layoff, fires, cuts, loss, losses, outage, breach, leak, hacked, exploit, vulnerability, dies, killed, dead, tragedy, crisis, emergency, shutdown, warns, warning, plunge, dump.
- **Controversial (~40 keywords):** controversy, controversial, backlash, divides, divisive, debate, debates, argues, protest, protests, protesters, criticism, criticizes, condemns, outrage, slams, attacks, feud, clash, row, dispute, accuses, alleged, allegation.

**Tie-break ordering:** `controversial > critical > positive > neutral`. A platform-specific Reddit bias multiplies the controversial hit-count by 1.5× because Reddit discourse skews debative — this calibration was added after manual inspection of cluster pages.

### C. Personalization Engine

A `PersonalizationEngine` (`lib/services/personalization_engine.dart`) re-ranks the global feed using a scalar multiplier computed per item. The multiplier `m(x) ∈ [0.25, 1.9]` is derived from a `PersonalizationProfile` aggregated from the user's interaction history:

| Signal                                     | Contribution                                         |
| ------------------------------------------ | ---------------------------------------------------- |
| Explicit like feedback                     | +1.35 per matching tag, +1.5 per matching cluster    |
| Explicit dislike feedback                  | ×0.08 item multiplier (near-total suppression)       |
| Implicit "not interested"                  | −0.85 per matching tag                                |
| Bookmark of item or sibling in cluster     | +0.9 cluster affinity                                 |
| Recency-decayed search query match         | +0.7 × exp(−age_days / 7) per tag match              |
| Source tap frequency (`YouTube`, `News`…)  | +0.10 per tap, capped at +1.0                         |
| Onboarding interest category               | +2.4 per category tag match                           |
| Cluster affinity from view history         | +1.3 per view, +2.0 if viewed ≥ 3 times               |
| Hard dislike (feedback = `dislike`)        | multiplier = 0.08 (surfaces at very bottom)          |

The final personalized rank is `rank(x) = S_final(x) · m(x)`. The multiplier is clamped to `[0.25, 1.9]` to preserve some global-signal influence — no topic is completely hidden unless explicitly disliked.

A separate `personalizedFeedProvider` exposes this list; the profile screen lets the user toggle between global and personalized views.

---

## V. IMPLEMENTATION

### A. Technology Stack

| Concern                | Technology                                             |
| ---------------------- | ------------------------------------------------------ |
| UI framework           | Flutter 3.38, Dart SDK ^3.10.8, Material 3            |
| State management       | `flutter_riverpod` 2.6                                 |
| Networking             | `http` 1.2                                             |
| Auth & Cloud DB        | `firebase_auth` 5.3, `cloud_firestore` 5.4             |
| Storage                | `firebase_storage` 12.3 (profile pictures)             |
| Messaging              | `firebase_messaging` 15.0, `firebase_core` 3.6         |
| Local notifications    | `flutter_local_notifications` 18.0                     |
| Background tasks       | `workmanager` 0.9                                      |
| Charts                 | `fl_chart` 0.69                                        |
| Treemap                | custom `SliceDiceTreemap` widget                       |
| Deep links             | `app_links` 6.3                                        |
| Share                  | `share_plus` 10.0                                      |
| Web view               | `webview_flutter` (for full-article in-app reading)    |
| Typography             | `google_fonts` (Syne headlines, DM Sans body, Inter UI) |
| RSS parsing            | `webfeed_revised`                                      |
| Caching / KV           | `shared_preferences` 2.3                               |
| Locale                 | `intl`, `flutter_localizations`                        |
| Environment secrets    | `flutter_dotenv`                                       |
| Image caching          | `cached_network_image` 3.4                             |
| Google Sign-In         | `google_sign_in` 6.2                                   |
| Phone auth             | built-in Firebase OTP                                  |
| LLM provider           | Groq (`llama-3.1-8b-instant`)                          |

### B. Application Entry and Initialization

`main()` (in `lib/main.dart`) performs the following sequence:

1. `WidgetsFlutterBinding.ensureInitialized()`.
2. `dotenv.load(fileName: '.env')` — tolerated if missing (guarded with `try/catch`).
3. On non-Windows, non-web platforms: `Firebase.initializeApp()` with `duplicate-app` tolerated, then `FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler)` registered *before* `runApp`.
4. `NotificationService.init()` — creates the `alerts` and `digest` channels on Android.
5. A `ProviderContainer` is built, theme is hydrated via `themeProvider.notifier.load()`, and `runApp(UncontrolledProviderScope(...))` is invoked — a pattern that avoids a frame-boundary flicker between the default theme and the user's saved theme.
6. After `runApp`, two deferred tasks execute off the UI thread to preserve first-frame latency:
   - At **+800 ms**: `FcmService.init()`, `BackgroundService.init()`, `BackgroundService.scheduleWatchlistCheck()`, `BackgroundService.scheduleMorningDigest()`.
   - At **+30 s** (demo): `fireDemoBreakoutAlert()` — fires an AI-generated breakout notification for documentation and screenshotting purposes.

### C. Authentication Architecture

Authentication is handled by `AuthService` (`lib/services/auth_service.dart`) exposing four sign-in flows:

1. **Email/password registration.** Captures displayName, age (used to derive `isMinor`), optional profile picture. On success, a `UserModel` is written to `users/{uid}` with `createdAt`, `lastLoginAt`, and an empty watchlist.
2. **Email/password login.** Updates `lastLoginAt` and triggers a synchronous Firestore read into `userProvider`.
3. **Google Sign-In.** Uses the `google_sign_in` plugin to obtain an `idToken` + `accessToken` pair, exchanges via `GoogleAuthProvider.credential`, then upserts the `UserModel` — pulling `displayName` and `photoURL` from the Google profile on first login.
4. **Phone OTP.** Uses Firebase `verifyPhoneNumber` with a 60 s timeout. Code sent → `verificationId` held in memory → user enters 6-digit code → `PhoneAuthProvider.credential` + `signInWithCredential`. Minors are blocked at this step with a localized error.

A **guest mode** is also supported: the splash screen sends an anonymous user to `MainShell` with a reduced feature set (no watchlists, no bookmarks synced; guest search history is stored locally in SharedPreferences under the key `guest_search_history`).

#### Profile Picture Upload

`uploadProfilePicture(File, uid)` writes to `profile_pics/{uid}.jpg` in Firebase Storage with `cacheControl: public, max-age=3600` and `Content-Type: image/jpeg`, returning a downloadable URL that is written to `users/{uid}.profilePictureUrl`.

### D. Firestore Schema

```
users/{uid}
 ├── displayName: String
 ├── email: String?
 ├── phoneNumber: String?
 ├── age: int
 ├── isMinor: bool (derived: age < 13)
 ├── profilePictureUrl: String?
 ├── onboardingCompleted: bool
 ├── selectedInterests: List<String>          # from §V-G
 ├── preferredRegion: String                  # ISO country code
 ├── createdAt: Timestamp
 ├── lastLoginAt: Timestamp
 ├── watchlist: List<String>                  # cluster IDs or topic keywords
 ├── bookmarks: List<Map>                     # serialized TrendItem
 ├── searchHistory: List<String>              # max 20, rolling window
 ├── savedDashboards: List<Map>               # see §V-L
 ├── preferences: Map<String, dynamic>        # theme, personalization on/off
 └── feedback (subcollection)
      └── {autoId}
           ├── itemId: String
           ├── clusterId: String?
           ├── sentiment: String               # like / dislike / not_interested
           ├── tags: List<String>
           ├── sourceLabel: String
           └── createdAt: Timestamp

fcm_tokens/{token}
 ├── uid: String
 ├── device: String
 └── createdAt: Timestamp
```

Bookmarks and search history are kept *denormalized inside* the user document because they are small (≤ 50 bookmarks, ≤ 20 search terms) and always read as a bundle with the profile. The feedback subcollection is separate because it grows unbounded and is queried independently by the personalization engine.

### E. Data Sources — Complete Endpoint Reference

#### 1) YouTubeService

- **Endpoint:** `GET https://www.googleapis.com/youtube/v3/videos`
- **Params:** `part=snippet,statistics`, `chart=mostPopular`, `regionCode={device locale}`, `maxResults=25`, optional `videoCategoryId` (10=Music, 17=Sports, 20=Gaming, 24=Entertainment, 25=News, 28=Science/Tech), `key=YOUTUBE_API_KEY`.
- **Region handling:** `regionCode` is derived from `WidgetsBinding.instance.platformDispatcher.locale.countryCode` defaulting to `'US'` only if unavailable. Hardcoding to `'US'` was reverted after it was found to break geo-restricted content for Indian users.
- **Filtering:** `_isPlayableVideo` rejects items where `liveBroadcastContent == 'live'` and `duration < 60 s` to exclude Shorts and live streams.
- **Thumbnail selection:** `_bestThumbnail` prefers `maxres → high → medium → default`.
- **Score:** raw view count.

#### 2) RedditService

- **Endpoint:** `GET https://www.reddit.com/r/{sub}/hot.json?limit=50`, User-Agent `UniTrend/1.0` (required by Reddit).
- **Category subreddit mapping:**
  - `all` → `popular+all`
  - `tech` → `technology+programming+MachineLearning+gadgets`
  - `gaming` → `Games+gaming+pcgaming`
  - `finance` → `stocks+investing+CryptoCurrency+wallstreetbets`
  - `entertainment` → `movies+television+Music`
  - `startup` → `startups+Entrepreneur+smallbusiness`
  - `science` → `science+space+Futurology`
- **India region preference:** when `preferredRegion == 'IN'` the service prepends `IndiaSpeaks+india+unitedstatesofindia` for broader cultural relevance.
- **Score:** raw `ups` (upvotes).
- **NSFW filtering:** items with `over_18 == true` are excluded unconditionally.

#### 3) NewsService

- **Primary provider:** NewsAPI.org `GET /v2/top-headlines?country={cc}&category={cat}&pageSize=30`.
- **Fallback RSS feeds (`_categoryFeeds`):**
  - `tech`: TechCrunch, The Verge, Ars Technica, Wired.
  - `world`: BBC, Reuters, Al Jazeera.
  - `india`: Times of India, The Hindu, Indian Express.
- **UTF-8 decoding:** responses are explicitly `utf8.decode(response.bodyBytes)` to correct mis-detected encodings.
- **HTML stripping:** description passes through a `RegExp(r'<[^>]*>')` filter.
- **Score:** synthesized as a function of recency (newer → higher) and source reputation multiplier.

#### 4) GitHubService

- **Endpoint:** `GET https://api.github.com/search/repositories?q={query}&sort=stars&order=desc&per_page=30`.
- **Auth:** optional Bearer token (`GITHUB_TOKEN`) — when present, rate limit is 5000/h vs 60/h anonymous.
- **Category topic mapping:** `tech → topic:ai`, `gaming → topic:game`, `finance → topic:finance`, `startup → topic:startup`, `entertainment → topic:media`.
- **Language/topic clauses** are ANDed: `language:dart topic:flutter created:>2025-01-01`.
- **Score:** `stargazers_count`.

#### 5) TechService — composite (Hacker News, Product Hunt, Dev.to)

- **Hacker News:** `GET https://hn.algolia.com/api/v1/search?tags=front_page` (Algolia-hosted mirror, no auth needed). Score = `points`.
- **Product Hunt:** RSS at `https://www.producthunt.com/feed`, parsed via `webfeed_revised`. Score = inverse feed position.
- **Dev.to:** `GET https://dev.to/api/articles?top=7` (past week top). Score = `positive_reactions_count`.

### F. Filter System

`FilterState` (`lib/models/filter_state.dart`) is an immutable record driving `filteredFeedProvider`:

| Field               | Type                | Default            |
| ------------------- | ------------------- | ------------------ |
| `region`            | `FeedRegion` enum   | `auto` (device)    |
| `category`          | `FeedCategory` enum | `all`              |
| `enabledSources`    | `Set<Source>`       | all 7              |
| `dateFilter`        | `DateFilter` enum   | `last24h`          |
| `minScore`          | `double`            | 0                  |
| `maxAgeHours`       | `int`               | 168                |
| `sortOrder`         | `SortOrder` enum    | `hottest`          |
| `sentimentFilter`   | `String?`           | null (any)         |
| `hideReadArticles`  | `bool`              | false              |

`SortOrder` supports `hottest` (S_final desc), `newest` (publishedAt desc), `discussed` (Reddit comments / HN descendants), `controversial` (sentiment filter + score).

`DateFilter` values: `lastHour`, `last6h`, `last24h`, `last7d`, `last30d`.

### G. Onboarding Flow

`OnboardingScreen` is a 3-page `PageController`-driven flow:

1. **Welcome + region selection** — default to device locale, user can override.
2. **Interest selection** — grid of 10 tappable cards with icons:

| Interest      | Icon                    | Category key     |
| ------------- | ----------------------- | ---------------- |
| Tech & AI     | `smart_toy`             | `tech`           |
| Finance       | `trending_up`           | `finance`        |
| Gaming        | `sports_esports`        | `gaming`         |
| Startups      | `rocket_launch`         | `startup`        |
| Entertainment | `movie`                 | `entertainment`  |
| Science       | `science`               | `science`        |
| Sports        | `sports_soccer`         | `sports`         |
| Politics      | `how_to_vote`           | `politics`       |
| Crypto        | `currency_bitcoin`      | `crypto`         |
| Climate       | `eco`                   | `climate`        |

A minimum of 3 interests must be selected.

3. **Notification permission** — requests runtime `POST_NOTIFICATIONS` on Android 13+, then completes. Selected interests are written to `users/{uid}.selectedInterests` and propagated into the initial `PersonalizationProfile`.

### H. Theme System

`AppTheme` (`lib/theme/app_theme.dart`) ships three modes — light, dark, and AMOLED — via `themeProvider` persisted through SharedPreferences (`app_theme_mode` key, value ∈ `{system, light, dark, amoled}`).

- **Light mode:** Material 3 `ColorScheme.fromSeed(seedColor: Color(0xFFFF5722))` (deep orange).
- **Dark mode:** Material 3 dark with surface `#121212` and surfaceVariant `#1E1E1E`.
- **AMOLED mode:** pure black surface `#000000` for OLED power savings.

**Accent gradient** used across buttons, skeletons, and radar headers:
```
LinearGradient([Color(0xFFFF6B35), Color(0xFFE94B9C), Color(0xFF7B61FF)])
```

**Typography hierarchy:**
- **Headlines:** Syne (bold, condensed) — titles on Radar cards, cluster headers.
- **Body:** DM Sans — article bodies, chat messages.
- **UI / chrome:** Inter — button labels, nav bar, form fields.

Card theme uses `BorderRadius.circular(12)` with a `colorScheme.outlineVariant.withValues(alpha: 0.5)` hairline border. Navigation bar indicator color is `seedColor.withValues(alpha: 0.15)` to match the accent.

### I. Proactive Background Service

`BackgroundService` (`lib/services/background_service.dart`) registers two WorkManager periodic tasks.

#### 1) Watchlist / Velocity Task — 3-hour period

For each cluster topic in the user's watchlist:

1. Re-fetch the global feed via the same source pipeline.
2. Recompute cluster scores.
3. Compare against the persisted snapshot from `ScoreHistoryService`.
4. If `(S_current - S_previous) > 25` **and** `S_current > 50`, emit a high-priority `alerts` channel notification using `BigTextStyleInformation` to support expandable AI text.
5. The notification body is generated by `GroqService.generateBreakoutBlurb(topic, scoreDelta)` — a dedicated 1–2-sentence, max-35-word, no-filler prompt — with a static fallback if Groq is unavailable or times out.

#### 2) Morning Digest Task — 24-hour period, fires at 08:00 local

1. Pull top 15 items from `feedProvider`.
2. Format as a numbered list of `[source] title` lines.
3. Call `GroqService.generateMorningBriefing(numberedHeadlines)` — 3-bullet, emoji-prefixed, ≤ 20 words per bullet.
4. Deliver through the `digest` channel as a rich notification with a content intent that opens `RadarScreen`.

#### 3) ScoreHistoryService

A SharedPreferences-backed rolling store (`score_history_v1` key) that:

- De-duplicates writes within a 2-hour window (a second snapshot within 120 min replaces the earlier one).
- Caps total entries at 600 and aggregates per day into `DailyScore` objects after 7 days.
- Maintains a 30-day overall cap.
- Backs the historical score chart on `ClusterDetailScreen`.

### J. FCM Integration

`FcmService` (`lib/services/fcm_service.dart`):

1. Requests notification permission (`requestPermission(alert: true, badge: true, sound: true)`).
2. Fetches the device token and writes it to Firestore `fcm_tokens/{token}` with `uid` and `device` metadata.
3. Subscribes to topic streams for each selected interest (`tech_topic`, `finance_topic`, etc.) so a future server-driven fanout can push only to relevant audiences.
4. Registers the top-level `fcmBackgroundHandler` (required to be top-level in Dart for isolate spawn).

Two Android channels are pre-created:

- `alerts` — `Importance.high`, default sound, used for breakout alerts.
- `digest` — `Importance.default`, silent, used for the 8 AM briefing.

### K. Deep Linking

Deep links of the form `unitrend://cluster/{id}` are:

- **Emitted** by `share_plus` from the cluster detail screen's share button.
- **Received** by an `AndroidManifest.xml` intent filter with `<data android:scheme="unitrend" android:host="cluster"/>`.
- **Routed** by `app_links` listening on a broadcast stream in `main.dart`, which invokes a navigator push to `ClusterDetailScreen(id)` after ensuring the cluster is present in the feed (triggers a refetch if not).

### L. Saved Dashboards

A user can snapshot a current filter + cluster selection as a named dashboard (e.g., "AI This Week", "Indian Politics"). Each dashboard is a serialized `FilterState` plus a human title, persisted to `users/{uid}.savedDashboards`. Re-opening a dashboard applies its `FilterState` to `filterStateProvider`, hydrating the feed exactly as it was captured — minus the live re-fetch.

### M. Flagship UI: The Signal Radar

`RadarScreen` exposes the top clusters in two alternate visualizations:

1. **Hero Card mode** — large score-ranked cards emphasizing the single dominant story of the day. Each card shows gradient background, cluster title, momentum chip, sentiment badge, and the top 3 member titles as a preview list.

2. **Treemap mode** — a Shneiderman slice-and-dice layout where each tile's area is proportional to cluster score and its color encodes aggregate sentiment (`critical`→red, `positive`→green, `controversial`→amber, `neutral`→cyan). Allows at-a-glance scale comparison of the top N clusters without scrolling.

Toggle between modes via a single AppBar icon button. A `_RadarSkeleton` gradient-shimmer placeholder hides the network latency of the underlying cluster query. Scroll-to-top is enabled via a floating button that fades in after > 400 px of scroll.

### N. Cluster Detail Screen and LLM Chat

Tapping a cluster opens `ClusterDetailScreen` which renders:

1. **Cluster header** — gradient card with title, source chips, aggregate sentiment badge, and member count.
2. **Historical score chart** — `fl_chart` line chart backed by `ScoreHistoryService`, showing up to 30 daily aggregates.
3. **AI summary card** — lazy-loaded `GroqService.summarize()` output with a "Regenerate" IconButton.
4. **Cross-platform perspective card** — visible only when the cluster spans ≥ 2 distinct sources; invokes `compareSourcePerspectives`.
5. **Member list** — scrollable list of the component items, each rendered by the appropriate specialized tile (`NewsArticleTile`, `YoutubeCard`, `RedditPostTile`, `TrendCard`).
6. **Chat FAB** — opens `_ChatSheet`, a `DraggableScrollableSheet` with gradient message bubbles, animated typing dots, and three seed questions. Chat history is passed through `GroqService.chatWithCluster` and retained for the session only.
7. **Share button** — emits a `unitrend://cluster/{id}` deep link via `share_plus`.

### O. Widget Catalog

The `lib/widgets/` directory contains reusable composable primitives:

| Widget                       | Purpose                                                      |
| ---------------------------- | ------------------------------------------------------------ |
| `GlassCard`                  | Frosted-glass container used on splash and radar hero.       |
| `FloatingOrbsBackground`     | Animated blurred gradient orbs for splash/onboarding depth.  |
| `StaggeredListItem`          | 60 ms-per-index fade-and-slide entry animation.              |
| `GradientSkeleton`           | Shimmer placeholder with accent-gradient mask.               |
| `NewsArticleTile`            | Specialized news rendering with outlet badge and hero image. |
| `YoutubeCard`                | 16:9 thumbnail + channel avatar + duration pill.             |
| `RedditPostTile`             | Compact tile showing subreddit, upvote count, comment count. |
| `TrendCard`                  | Generic tile for GitHub, HN, PH, Dev.to.                     |
| `SentimentBadge`             | Colored chip for sentiment label.                            |
| `MomentumChip`               | ↗/→/↘ arrow + text chip.                                     |
| `SourceChip`                 | Small colored chip keyed by platform.                        |
| `AccentButton`               | Gradient-filled primary CTA with haptic feedback.            |
| `ShimmerFeedLoader`          | Full-screen feed skeleton shown during cold start.           |
| `AnimatedCounter`            | Rolling-digit counter for score changes on radar.            |
| `SlideSelector`              | Horizontal pill selector for filter chips.                   |

### P. Provider Catalog

A non-exhaustive list of Riverpod providers:

| Provider                     | Type                                              | Purpose                           |
| ---------------------------- | ------------------------------------------------- | --------------------------------- |
| `themeProvider`              | `StateNotifierProvider<ThemeNotifier, Mode>`     | Theme persistence + switching     |
| `authProvider`               | `StreamProvider<User?>`                           | Auth state stream                 |
| `userProvider`               | `FutureProvider<UserModel?>`                      | Hydrated user doc                 |
| `feedProvider`               | `FutureProvider<List<TrendItem>>`                 | Base global feed                  |
| `filterStateProvider`        | `StateProvider<FilterState>`                      | Current filters                   |
| `filteredFeedProvider`       | `Provider<List<TrendItem>>`                       | Feed after filters                |
| `personalizedFeedProvider`   | `Provider<List<TrendItem>>`                       | Feed after personalization        |
| `personalizationProvider`    | `FutureProvider<PersonalizationProfile>`          | Derived profile                   |
| `radarClustersProvider`      | `FutureProvider<List<RadarCluster>>`              | Cluster aggregation for radar     |
| `clusterAlertProvider`       | `StreamProvider<List<ClusterAlert>>`              | Velocity alerts in-app            |
| `watchlistProvider`          | `AsyncNotifierProvider<...>`                      | Watchlist CRUD                    |
| `bookmarkProvider`           | `AsyncNotifierProvider<...>`                      | Bookmark CRUD                     |
| `savedDashboardsProvider`    | `AsyncNotifierProvider<...>`                      | Dashboard CRUD                    |
| `recentlyViewedProvider`     | `StateNotifierProvider<...>`                      | Last 20 items viewed              |
| `readingHistoryProvider`     | `StateNotifierProvider<...>`                      | Full reading history (local)      |
| `scoreHistoryProvider`       | `FutureProvider.family<...>`                      | Per-cluster score timeline        |
| `searchHistoryProvider`      | `AsyncNotifierProvider<...>`                      | Search history (user or guest)    |

### Q. Search Experience

`SearchScreen` provides:

1. **Live search** against all 7 sources in parallel using `Future.wait`.
2. **Recent searches** — up to 20, stored in Firestore for signed-in users, SharedPreferences for guests.
3. **Per-chip delete** via `InputChip.onDeleted`.
4. **Clear All** — a TextButton in the Recent Searches header that clears the entire history. For signed-in users this updates `users/{uid}.searchHistory`; for guests it deletes the `guest_search_history` SharedPreferences key.
5. **Recently Viewed** — fed by `recentlyViewedProvider`, clearable with the same pattern.

### R. Feed Cache

`FeedCacheService` (`lib/services/feed_cache_service.dart`) writes the latest `List<TrendItem>` to the SharedPreferences key `feed_cache_v1` as a JSON array. The cache is hydrated synchronously on splash screen render so the first visual frame shows content (skeleton is skipped when cache is fresh < 1 h). The cache is re-written after every successful foreground refresh.

### S. Demo / Documentation Helpers

To support screenshotting for this paper, a demo notification helper `fireDemoBreakoutAlert()` is scheduled 30 s after app launch. It randomly selects a topic from `[openai, flutter, nvidia, bitcoin, tesla, apple]`, invokes `generateBreakoutBlurb`, and dispatches it through the `alerts` channel with the title `🚨 BREAKOUT: #{topic} is exploding!`.

---

## VI. RESULTS AND EVALUATION

### A. Quantitative Characteristics

| Metric                                       | Value                |
| -------------------------------------------- | -------------------- |
| Source files (all languages)                 | 100                  |
| Dart source files                            | 73                   |
| Code-graph nodes / edges                     | 804 / 6318           |
| Function nodes                               | 494                  |
| Class nodes                                  | 205                  |
| Architectural communities                    | 11                   |
| Data sources integrated                      | 7                    |
| LLM interaction modes                        | 5                    |
| Background task types                        | 2 (watchlist, digest) |
| Onboarding interests                         | 10                   |
| Filter dimensions                            | 9                    |
| Riverpod providers                           | 25+                  |
| Cold-start feed render (cached)              | < 1.5 s              |
| Cold-start feed render (no cache)            | 2.5 – 4 s            |
| Velocity alert poll period                   | 3 h                  |
| Morning digest period                        | 24 h (08:00 local)   |
| LLM summary latency (Groq p50)               | 1.5 – 3 s            |
| LLM chat round-trip (Groq p50)               | 2 – 4 s              |
| Groq timeout budgets                         | 12 / 15 / 20 s       |
| Clustering complexity                        | O(n² · α(n))         |
| Recency decay half-life                      | 24 h                 |
| Near-duplicate Jaccard threshold             | 0.9                  |
| Breakout alert threshold                     | Δ > 25, S_current > 50 |
| Personalization multiplier range             | [0.25, 1.9]          |

### B. Qualitative Observations

- **Stop-word list sensitivity.** Expanding `_stopWords` from ~50 to ~200 terms eliminated the majority of "headline-noise" false-positive clusters (e.g., clusters spuriously formed around "live", "breaking", "exclusive").
- **Source-weight tuning.** Initial weights that placed YouTube at 1.0 caused viral-but-shallow clips to dominate; reducing YouTube to 0.8 and Reddit to 1.1 produced visibly more substantive top-of-feed content.
- **Sentiment color mapping.** Rendering `critical`→red and `controversial`→amber on the treemap makes adversarial or polarizing clusters immediately visible without reading any text.
- **Proactive notifications.** The 25-point breakout threshold produced approximately 1 alert per watchlist topic per day on average — below the perceived annoyance threshold in informal self-testing.
- **Personalization effectiveness.** After ~2 weeks of use, the personalized feed converged on the user's domain interests (AI, Flutter, cricket) while the global feed remained diverse — confirming the multiplier clamp [0.25, 1.9] preserves serendipity.
- **Region correctness.** Switching device locale from en-US to en-IN shifts the YouTube feed from US-centric content to Indian popular content without any user action, validating the `regionCode` auto-detection.

### C. Developer-Experience Metrics

Static analysis under `flutter analyze` reports **zero issues** at the tagged Phase-5 completion commit. The code-review-graph detected 11 communities whose largest three correspond exactly to the intended architectural layering (`screens-state`, `services-fetch`, `widgets-state`), indicating the clean-architecture boundaries hold empirically.

Commit history shows incremental phases:
1. Phase 1–2: core data pipeline + TrendItem model.
2. Phase 3–4: Signal Radar, onboarding, watchlists, AI intelligence.
3. Phase 5–6: Treemap visualization, background service, FCM, notification pipeline, UI polish.

---

## VII. DISCUSSION

### A. Strengths

1. **Determinism.** The entire ranking pipeline is analytic and reproducible. Given the same inputs, the same ordering is produced — a property often absent from ML-based ranking systems and valuable for debugging, testing, and explaining feed behaviour to the user.
2. **On-device operation.** No server is required for ranking, clustering, or sentiment. The only network dependencies beyond the sources themselves are Firebase (optional for guest mode) and Groq (optional: summary/chat features degrade gracefully to "unavailable").
3. **Cross-platform framing insight.** `compareSourcePerspectives` delivers what no existing mainstream aggregator exposes: an explicit, LLM-written comparison of how Reddit vs. mainstream news vs. Hacker News frame a shared topic.
4. **Layering discipline.** The static code graph's community structure empirically matches the designed layering, giving confidence that future modifications will remain localized to their layer.
5. **Graceful degradation.** Every external dependency is wrapped in try/catch with documented fallbacks — Firebase init tolerates `duplicate-app`, dotenv load tolerates missing `.env`, Groq failures surface a static fallback blurb, and network failures render the cached feed.

### B. Limitations

1. **Keyword-based clustering** cannot resolve semantic equivalence (e.g., "EV" vs. "electric vehicle", "LLM" vs. "large language model"); a small embedding model would improve recall but costs latency and storage.
2. **Rule-based sentiment** is brittle for sarcasm, irony, and code-switched text. It cannot distinguish "stock crashes in popularity" from "plane crashes".
3. **Groq vendor lock-in.** LLM features are coupled to a single provider; the `GroqService` abstraction is clean enough to swap providers but prompts are tuned to the LLaMA-3.1 family.
4. **Stop-word list is English-only.** Multi-lingual trending content would require per-locale lexicons.
5. **Windows desktop disabled.** Firebase initialization is skipped on Windows (`!Platform.isWindows` guard) — a deliberate trade-off for development convenience, but means Windows builds omit auth and cloud sync.
6. **Local-only velocity alerts.** Breakout alerts rely on the device's WorkManager scheduling, which is OS-policy-limited on doze-aggressive Android OEMs. A true server-side FCM push from a Firebase Cloud Function would be more reliable — this is deferred future work.

### C. Ethical Considerations

- **Filter-bubble risk.** Personalization can deepen echo chambers. The app preserves a global (non-personalized) feed and exposes the personalization toggle prominently in the Profile screen to mitigate this.
- **LLM hallucination.** Summaries can fabricate specifics. Every summary is accompanied by the source URL list, and the in-app WebView lets the user read the primary source without leaving the app.
- **Proactive alerts.** Breakout notifications are strictly opt-in per topic (must be added to the watchlist) and are user-configurable in the dedicated NotificationPreferences screen.
- **Data privacy.** Reading history and recently-viewed items are stored *locally* in SharedPreferences only; only the user profile, watchlist, bookmarks, search history and feedback sync to Firestore — and only for signed-in (non-guest) users.
- **Minor protection.** Users whose self-reported age < 13 are flagged `isMinor` and excluded from phone-auth flows; this is a defensive measure given the absence of a content-classification layer.
- **API terms compliance.** Reddit requires a descriptive User-Agent; YouTube requires attribution of thumbnails and titles; NewsAPI prohibits redistribution of full article bodies — the app respects all three by displaying only title + description and deep-linking to the primary source.

---

## VIII. CONCLUSION AND FUTURE WORK

We presented **UniTrend**, a Flutter application that unifies seven heterogeneous trending-content sources into a single ranked, clustered, sentiment-aware feed with LLM-based synthesis, explainable personalization, and proactive background intelligence. A deterministic on-device pipeline — source-weighted min-max normalization, exponential recency decay with 24-hour half-life, headline-noise-filtered tag extraction, union-find keyword clustering, momentum labelling, and Jaccard near-duplicate suppression — produces a usable ranked feed without model training. A rule-based sentiment engine with ~150 curated keywords and a Reddit-bias correction classifies items into four emotional categories. A personalization engine with a clamped multiplier in [0.25, 1.9] re-ranks globally without eliminating serendipity. Groq LLaMA-3.1 provides low-latency summaries, multi-turn cluster chat, cross-platform perspective comparison, velocity-alert blurbs, and a daily morning briefing. A WorkManager-driven background service emits score-velocity alerts and a scheduled 8 AM digest even when the app is closed. The flagship Signal Radar with its Shneiderman treemap offers at-a-glance perception of trend scale. Firebase Authentication (email/password + Google + phone OTP) and Cloud Firestore back a full user-profile, watchlist, bookmark, dashboard, and feedback ecosystem, with a guest mode that degrades gracefully to local-only storage.

**Future work** includes:
1. Replacing keyword clustering with small-footprint sentence-transformer embeddings (e.g., MiniLM quantized to ONNX) for semantic recall.
2. Migrating from client-scheduled local notifications to a Firebase Cloud Function computing global breakout scores server-side and dispatching true FCM pushes — removing OEM doze-policy unreliability.
3. Multi-language support with per-locale stop-word lists and per-locale sentiment lexicons, starting with Hindi given the primary user base.
4. Offline-first cache with background refresh to support air-travel and low-connectivity use (the foundation exists in `FeedCacheService`).
5. A web build using the same Dart code-base to broaden reach.
6. A public server-side API exposing the ranked feed, enabling third-party widgets and integrations.
7. Video and image content understanding via a vision LLM for richer cross-source clustering.

---

## REFERENCES

[1] J. Kleinberg, "Bursty and Hierarchical Structure in Streams," in *Proc. 8th ACM SIGKDD Int. Conf. Knowledge Discovery and Data Mining*, 2002, pp. 91–101.

[2] D. M. Blei, A. Y. Ng, and M. I. Jordan, "Latent Dirichlet Allocation," *Journal of Machine Learning Research*, vol. 3, pp. 993–1022, 2003.

[3] P. Lewis *et al.*, "Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks," in *Proc. NeurIPS*, 2020.

[4] Flutter Team, "Flutter: Build apps for any screen," Google, 2024. [Online]. Available: https://flutter.dev

[5] Riverpod Documentation, "A reactive caching and data-binding framework." [Online]. Available: https://riverpod.dev

[6] Google Developers, "YouTube Data API v3 Reference." [Online]. Available: https://developers.google.com/youtube/v3

[7] Reddit Inc., "Reddit JSON API." [Online]. Available: https://www.reddit.com/dev/api

[8] NewsAPI, "NewsAPI.org Documentation." [Online]. Available: https://newsapi.org/docs

[9] GitHub Inc., "GitHub REST API — Search." [Online]. Available: https://docs.github.com/en/rest/search

[10] H. Touvron *et al.*, "LLaMA: Open and Efficient Foundation Language Models," *arXiv:2302.13971*, 2023.

[11] Groq Inc., "Groq LPU Inference API Documentation." [Online]. Available: https://console.groq.com/docs

[12] Firebase, "Cloud Firestore and Firebase Cloud Messaging Documentation," Google, 2024. [Online]. Available: https://firebase.google.com/docs

[13] R. E. Tarjan, "Efficiency of a Good But Not Linear Set Union Algorithm," *Journal of the ACM*, vol. 22, no. 2, pp. 215–225, 1975.

[14] B. Shneiderman, "Tree Visualization with Tree-Maps: 2-d Space-Filling Approach," *ACM Trans. Graphics*, vol. 11, no. 1, pp. 92–99, 1992.

[15] M. E. J. Newman, "Communities, modules and large-scale structure in networks," *Nature Physics*, vol. 8, pp. 25–31, 2012.

[16] P. Jaccard, "Étude comparative de la distribution florale dans une portion des Alpes et du Jura," *Bulletin de la Société Vaudoise des Sciences Naturelles*, vol. 37, pp. 547–579, 1901.

[17] Android Developers, "WorkManager — Schedule Reliable Background Work." [Online]. Available: https://developer.android.com/topic/libraries/architecture/workmanager

[18] Material Design 3, "Material You Specification," Google, 2023. [Online]. Available: https://m3.material.io

[19] B. Paulson, "Tree-sitter: An incremental parsing system for programming tools," 2018. [Online]. Available: https://tree-sitter.github.io
