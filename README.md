# MoneyBee

Offline-first personal finance tracker (FYP V1).

**Stack:** Flutter · Drift/SQLite · on-device PaddleOCR · rule-based categories

**Out of scope for V1:** backend, Redis, Kubernetes, cloud sync, accounts.

---

## Features

- Manual add / edit / delete of income and expense
- Receipt capture (camera or gallery) → on-device OCR → auto-fill merchant, amount, date, category
- Home dashboard:
  - **This week / This month** toggle
  - Income · expense · balance summary
  - **Top spending** by category (up to 5, with share %)
  - Recent transaction list (latest 8) with **See all** → History
- **History**: full list grouped by day, type filter (All / Expense / Income), search (merchant / note / category), edit & delete
- Settings: app version, clear all data (demo reset)
- SnackBars on save / update / delete
- All data stays on device (SQLite)

---

## Architecture

```text
┌─────────────────────────────────────────────────────────┐
│  Presentation                                            │
│  Home · History · Add/Edit · Scan · Settings             │
│  Riverpod providers · widgets                            │
└───────────────────────────┬─────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────┐
│  Domain                                                  │
│  Transaction entity · Categories                         │
│  OcrService (Paddle / Mock) · CategoryService (rules)    │
└───────────────────────────┬─────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────┐
│  Data                                                    │
│  TransactionRepository → AppDatabase (Drift / SQLite)    │
└─────────────────────────────────────────────────────────┘
```

**Flow (scan receipt):**

```text
Image → PaddleOCR (on-device) → text lines
      → parse merchant / amount / date
      → CategoryService.classify(text)
      → prefill Add Transaction → user confirms → SQLite
```

**Project layout:**

```text
moneybee/
├── lib/
│   ├── main.dart
│   ├── app/                 # theme, router
│   ├── domain/
│   │   ├── entities/        # Transaction, Categories
│   │   └── services/        # OCR, category rules
│   ├── data/
│   │   ├── database/        # Drift schema
│   │   └── repositories/
│   └── presentation/
│       ├── providers/
│       ├── screens/         # home, history, add, scan, settings
│       └── widgets/
├── android/                 # platform + NDK snippet
├── assets/images/
├── pubspec.yaml
└── README.md
```

---

## Tech highlights

| Area | Choice | Why |
|------|--------|-----|
| UI | Flutter + Material 3 | Cross-platform, fast iteration |
| State | Riverpod | Explicit providers, easy test hooks |
| Storage | Drift + SQLite | Type-safe SQL, offline-first, no server |
| OCR | PaddleOCR (PP-OCRv5) via `paddle_ocr_flutter` | Fully on-device, no API key / quota |
| Category | Keyword rules (`CategoryService`) | Lightweight, works offline, no ML model size |
| Privacy | Local only | Receipts and amounts never leave the phone |

**Design goals for V1:** small surface area, demo-ready in one device, no cloud dependency.

---

## Build & run

### Prerequisites

- Flutter SDK `>=3.3`
- Android device **arm64** for real OCR (emulator x86 usually cannot load the native model)

### First-time setup

```bash
cd moneybee

# Generate android/ios folders without overwriting lib/
flutter create . --project-name moneybee --org com.moneybee

flutter pub get

# Generate Drift code
dart run build_runner build --delete-conflicting-outputs
```

### Android config (required for OCR)

In `android/app/build.gradle.kts` → `defaultConfig`:

```kotlin
minSdk = 24
ndk {
    abiFilters += listOf("arm64-v8a")
}
```

See also: `android/app/build.gradle.snippet.kts`

### Run

```bash
# Debug (UI work)
flutter run

# Release on physical arm64 device (OCR)
flutter run --release
```

### APK

```bash
flutter build apk --split-per-abi --release
```

### UI-only / no native OCR

In `lib/domain/services/ocr_service.dart`, switch the provider to the mock:

```dart
final ocrServiceProvider = Provider<OcrService>((ref) {
  return MockOcrService();
});
```

---

## Demo checklist (capture)

Use **Settings → Clear all data** before recording so the flow starts clean.

### Suggested 30–60s video script

1. **Home** — empty state, show week/month toggle (2s)
2. **Scan** — open scanner FAB → pick/capture a receipt → wait for OCR (10–15s)
3. **Confirm** — review prefilled amount/merchant/category → Save → “Saved” SnackBar (5s)
4. **Home** — summary numbers + Top spending + recent row (5s)
5. **Edit** — tap a transaction → change amount → Update (5s)
6. **Delete** — trash icon → confirm → “Deleted” (5s)
7. **Optional** — Settings → show version → Clear all data (5s)

### Screenshots (4–5)

| # | Screen | What to show |
|---|--------|----------------|
| 1 | Home (with data) | Week/month toggle, summary, Top spending bars |
| 2 | Add / Edit | Form + category chips |
| 3 | Scan result / prefill | OCR-filled fields before save |
| 4 | Recent list | Several transactions |
| 5 | Settings | Version + Clear all data |

Store captures under something like `docs/demo/` (optional; not required to build).

---

## Post-V1 ideas

- Cloud sync / auth
- Charts and budgets
- Full i18n
- iOS OCR path

---

## Relation to older repo

The previous GitHub project (`PersonalFinanceTracker`) included FastAPI, Redis, and Kubernetes — too heavy for FYP V1. This tree is a **clean, offline-first rewrite** intended as the maintainable submission baseline.
