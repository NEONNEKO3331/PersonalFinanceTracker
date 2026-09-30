# MoneyBee (精簡版 V1)

離線優先的個人記帳 App：Flutter + SQLite (Drift) + 端側 PaddleOCR。

**不做**：後端、Redis、K8s、雲端同步（全部延後）。

---

## 功能

- 手動新增收入 / 支出
- 收據拍照 / 相簿 → 端側 OCR → 自動填入店名、金額、日期、分類
- 本月收支儀表板 + 交易列表
- 資料只存在本機 SQLite

---

## 專案結構

```text
moneybee/
├── lib/
│   ├── main.dart
│   ├── app/           # theme, router
│   ├── domain/        # entities, OCR, category rules
│   ├── data/          # Drift DB, repository
│   └── presentation/  # screens, providers, widgets
├── android/           # 打包設定片段
├── assets/
├── pubspec.yaml
└── README.md
```

---

## 第一次建立可執行專案

此資料夾是 **原始碼骨架**。請在本機用 Flutter 補齊平台檔：

```bash
# 1. 進入目錄
cd moneybee

# 2. 用 Flutter 產生 android/ios 平台檔（不會覆蓋已有的 lib/）
flutter create . --project-name moneybee --org com.moneybee

# 3. 安裝依賴
flutter pub get

# 4. 產生 Drift 程式碼
dart run build_runner build --delete-conflicting-outputs

# 5. 套用 Android 設定（見下方）

# 6. 真機執行（OCR 需要 arm64 Android）
flutter run --release
```

### Android 必要設定

編輯 `android/app/build.gradle.kts` 的 `defaultConfig`：

```kotlin
minSdk = 24
ndk {
    abiFilters += listOf("arm64-v8a")
}
```

參考檔：`android/app/build.gradle.snippet.kts`

打包：

```bash
flutter build apk --split-per-abi --release
```

---

## OCR 說明

- 預設使用 `paddle_ocr_flutter`（PP-OCRv5，約 +21MB 模型，完全離線）
- **僅支援 Android arm64 真機**；x86 模擬器通常無法跑
- 若要在沒有 native OCR 的環境開發 UI，把  
  `lib/domain/services/ocr_service.dart` 裡的 provider 改成：

```dart
final ocrServiceProvider = Provider<OcrService>((ref) {
  return MockOcrService();
});
```

---

## 之後可加（Post-V1）

- 雲端同步 / 登入
- 圖表分析
- 預算目標
- 多語系完整翻譯

---

## 與舊 GitHub 專案的關係

舊 repo（`PersonalFinanceTracker`）含 FastAPI、K8s、Redis 等，對 FYP V1 過重。  
本目錄是 **從頭精簡** 的可維護版本，可直接作為新 GitHub repo 的起點。
