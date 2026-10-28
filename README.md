# MoneyBee

Offline-first personal finance tracker (FYP).

**Stack:** Flutter · Riverpod · Drift/SQLite · on-device PaddleOCR · rule-based categories · Firebase AI (Gemini) for monthly insight

**Core promise:** Log a transaction in a few taps, keep every receipt and amount on the device.

---

## Features

| Area | What it does |
|------|----------------|
| **Transactions** | Add / edit / delete income & expense. Manual form or OCR prefill. |
| **Receipt OCR** | Camera or gallery → on-device PaddleOCR → merchant, amount, date, category suggestion. Tuned for MY bank-slip formats (e.g. `RM 4,962.00`). |
| **Home** | Week / Month / Custom range. Income · expense · balance. Top spending categories. Recent (latest 8) + **See all**. |
| **History** | Full list grouped by day. Filter by type (All / Expense / Income). Search merchant / note / category. Edit & delete. |
| **Analytics** | Pie chart + category breakdown. Same period selector. **AI monthly insight** (Generate / Regenerate) via Firebase AI (Gemini). |
| **Export** | Week / Month / Custom range → `.xlsx` (Summary + Transactions sheets) via share sheet. |
| **Settings** | App version, clear all data (demo reset). |
| **UX** | SnackBars on save / update / delete. Bee-themed UI (honey / cream / charcoal). English only. |

All transaction data stays in local SQLite. OCR runs fully on-device. AI insight is the only network call (optional).

---

## Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│  Presentation                                                │
│  Shell (Home · History · Analytics · Export)                 │
│  Add/Edit · Scan · Settings                                  │
│  Riverpod providers · PeriodSelector · Bee widgets           │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│  Domain                                                      │
│  Transaction · Categories                                    │
│  OcrService (Paddle / Mock) · CategoryService (rules)        │
│  ExportService · AiInsightService (Firebase AI / Gemini)     │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│  Data                                                        │
│  TransactionRepository → AppDatabase (Drift / SQLite)        │
└─────────────────────────────────────────────────────────────┘
```

**Scan flow**

```text
Image → PaddleOCR (on-device) → text lines
      → parse merchant / amount / date (MY thousand separators)
      → CategoryService.classify
      → prefill Add Transaction → user confirms → SQLite
```

**Project layout**

```text
lib/
├── main.dart                 # Firebase + App Check init, ProviderScope
├── app/                      # theme (BeeColors), router (StatefulShellRoute)
├── domain/
│   ├── entities/
│   └── services/             # ocr, category, export, ai_insight
├── data/
│   ├── database/             # Drift schema
│   └── repositories/
└── presentation/
    ├── providers/
    ├── screens/              # home, history, analytics, export, shell, add, scan, settings
    └── widgets/              # bee_brand, period_selector, transaction_tile
```

---

## Tech choices

| Area | Choice | Why |
|------|--------|-----|
| UI | Flutter + Material 3 + bee theme | Fast iteration, consistent look |
| State | Riverpod | Explicit providers, easy to reason about |
| Storage | Drift + SQLite | Type-safe, offline-first, no server |
| OCR | PaddleOCR (via `paddle_ocr_flutter`) | Fully on-device, no API key / quota |
| Category | Keyword rules | Lightweight, works offline |
| Charts | fl_chart | Pie + breakdown on Analytics |
| Export | excel + share_plus | XLSX with Summary + Transactions |
| AI insight | Firebase AI (Gemini) | Optional monthly narrative; only network feature |
| Privacy | Local-first | Receipts & amounts never leave the phone by default |

---

## Build & run

### Prerequisites

- Flutter SDK `>=3.3`
- Android **arm64** device for real OCR (most x86 emulators cannot load the native model)
- Firebase project (only needed for AI insight)

### First-time setup

```bash
git clone https://github.com/NEONNEKO3331/PersonalFinanceTracker.git
cd PersonalFinanceTracker

flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Firebase (AI insight only)

`google-services.json` and `lib/firebase_options.dart` are **not** committed (security).

1. Create a Firebase project and enable the Gemini / Firebase AI product you use.
2. Add an Android app with the same package name as this project.
3. Download `google-services.json` → place at `android/app/google-services.json`.
4. Generate options (FlutterFire CLI recommended):

   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

   Or restore your private `lib/firebase_options.dart` locally.

5. App Check is initialized with the debug provider on Android in `main.dart`. Use a real provider for release builds.

Without these files the rest of the app (transactions, OCR, analytics charts, export) still runs; only the AI insight card will fail until Firebase is configured.

### Android OCR notes

In `android/app/build.gradle.kts` → `defaultConfig`:

```kotlin
minSdk = 24
ndk {
    abiFilters += listOf("arm64-v8a")
}
```

If you hit Kotlin incremental / daemon lock issues on Windows, the repo includes `android/gradle.properties` settings that disable incremental compilation and parallel/daemon where needed.

### Run

```bash
# Debug (UI / most features)
flutter run

# Release on physical arm64 device (recommended for OCR)
flutter run --release
```

### APK

```bash
flutter build apk --split-per-abi --release
```

### UI-only / no native OCR

In the OCR provider, switch to the mock:

```dart
final ocrServiceProvider = Provider<OcrService>((ref) {
  return MockOcrService();
});
```

---

## Period selection

Home, Analytics, and Export share the same period model:

- **This week**
- **This month**
- **Custom** (date range picker)

Implemented via `HomePeriod` + `customDateRangeProvider` and the shared `PeriodSelector` widget.

---

## Demo checklist

Use **Settings → Clear all data** before recording so the flow starts clean.

### Suggested 30–60s video

1. Home — empty / with data, period toggle (week → month → custom)
2. Scan — FAB → capture/pick receipt → OCR → prefilled form → Save
3. Home — updated summary + Top spending + recent row
4. History — day groups, filter, search
5. Analytics — pie chart + Generate AI insight
6. Export — pick range → share XLSX
7. Optional — Settings → version + clear data

### Screenshots (4–5)

| # | Screen | Show |
|---|--------|------|
| 1 | Home | Period selector, summary, top categories, recent |
| 2 | Scan / Add | OCR-prefilled form |
| 3 | History | Grouped list + filter/search |
| 4 | Analytics | Pie + AI insight card |
| 5 | Export | Range + share result |

---

## Out of scope (current V1)

- Backend API / Redis / Kubernetes (removed from earlier over-engineered version)
- Multi-device sync / accounts
- Full i18n (English only for now)
- iOS OCR path
- Budgets, recurring transactions, PDF export

---

## License / academic use

FYP project. Feel free to fork for learning; keep Firebase credentials out of any public fork.
