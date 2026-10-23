# Architecture

Folders, types, and how data moves between them. The diagram and the layer rules are
in the [README](../README.md#architecture) and [`CLAUDE.md`](../CLAUDE.md).

## Folders

```
SlothRoll/
  App/         SlothRollApp (entry), AppDependencies (composition root, builds the action
               performers), RootView (onboarding until done, then TabView: Scan,
               Expenses, Clean up (only with candidates), Settings; hosts the debug eval
               sheet), RootTab
  Features/    one folder per screen (View + @Observable @MainActor ViewModel)
    Onboarding/ OnboardingView (paged: 3 intro pages, incl. "scan one album", + download), OnboardingPage,
               ModelDownloadView, OnboardingViewModel (check / download / retry),
               ModelDownloadState, OnboardingConfig
    Scan/      ScanView (source row + scan button + progress + card stack), ScanViewModel
               (also lists albums), AlbumPickerView (all recent photos or one album),
               CardStackView (@Query of `extracted` items, drag/buttons, tint, rotation,
               haptics), CardView, CardStackViewModel (perform / skip / edit / card
               images, toast), EditSheet, CardText (plain-words proposal + SF Symbol per
               type), TypeBadge, ScanConfig
    Expenses/  ExpenseListView (@Query of expenses, totals on top), ExpensesViewModel,
               CurrencyTotal
    Cleanup/   CleanupView (@Query of items with a cleanup reason, grid + delete bar),
               CleanupCell, CleanupReasonBadge, CleanupViewModel (selection, thumbnails,
               delete via PhotoLibraryProviding, keep the unselected), CleanupConfig
    Settings/  SettingsView (scan limit, rescan, model info, debug section),
               SettingsViewModel, ScanStatsSection (DEBUG only)
    Debug/     (DEBUG only) EvalView, EvalRowView, EvalViewModel, EvalRow, EvalMark,
               EvalSummary, EvalReport, EvalReportStore, EvalConfig,
               PreviewVLM + PreviewPhotoLibrary (fakes for SwiftUI previews)
  Pipeline/    ScanCoordinator (@Observable @MainActor: triage pass, then extraction pass,
               then cleanup pass; whole library or one album), ModelSession (one model load
               per scan, unload at the end), CleanupJudge (blur + duplicate rules, "still useful?"
               question), ImageAnalyzing + ImageAnalyzer (Laplacian blur score, Vision
               feature print) + ImageSignals, DuplicateFinder (union-find over feature-print
               distance, keeps newest), UsefulnessQuestion (prompt + yes/no reader),
               ScanStore (SwiftData reads/writes for the scan), ScanPhase, ScanStats,
               Extractor (VLM + parse + retry), ExtractionPrompt, ResultParser,
               ExtractionReport, ImageTriaging + Triage (Vision OCR, 20+ chars) + TextScan,
               PhotoLibraryProviding (+ScanWindow: library or album IDs) + PhotoLibrary
               (PhotoKit: albums, album contents, deleteAssets) + PhotoAlbum + PhotoAccess +
               LibraryImage
               + ImageSource, PipelineError, PipelineConfig
  Inference/   VLMService (actor: isDownloaded / download / load / describe / unload),
               ModelCatalog, InferenceConfig, InferenceError,
               HubDownloader + TransformersTokenizer(Loader) (mlx-swift-lm adapters)
  Actions/     ActionPerformer (protocol), EventAction (actor, EventKit write-only) +
               EventDraft, PlaceAction (MKLocalSearch, maps:// fallback), ReceiptAction
               (SwiftData Expense), ActionError, ActionsConfig
  Models/      ActionResult (+Dates: "YYYY-MM-DD"/"HH:mm" <-> Date), ActionType, Currency
               (+Format), Confidence, ActionOutcome, VLMServing (protocol)
  Storage/     ScreenshotItem (@Model: assetID unique, status, skip reason, result JSON,
               capturedAt, processedAt, sharpness/contrast/feature print, cleanup reason,
               checked/kept dates), Expense (@Model), ScanStatus, SkipReason, CleanupReason,
               Persistence (container; falls back to in-memory if the store won't open)
  Shared/      Log (os.Logger categories), MemoryProbe, Duration+Seconds, Toast +
               ToastOverlay (`.toast(_:duration:)`), SettingsKey (@AppStorage keys)
  Resources/   Assets (AppIcon, AccentColor sloth green light/dark, SlothMark logo),
               Info.plist, SlothRoll.entitlements
SlothRollTests/
  ParserTests/     ResultParserTests
  PipelineTests/   ExtractorTests (scripted fake VLM), ExtractionPromptTests,
                   ImageSourceTests, ScanCoordinatorTests (+ cleanup suite) + ScanFakes,
                   DuplicateFinderTests, ImageAnalyzerTests, UsefulnessQuestionTests
  StorageTests/    ScreenshotItemTests
  ActionsTests/    EventDraftTests, ReceiptActionTests, PlaceActionTests
  FeaturesTests/   EvalSummaryTests, CardStackViewModelTests (fake performer),
                   CardTextTests, ExpensesViewModelTests, OnboardingViewModelTests,
                   ScanViewModelTests, CleanupViewModelTests
```

## Data flow

First launch:

`RootView` (`@AppStorage hasCompletedOnboarding` false) → `OnboardingView` →
`OnboardingViewModel.checkExistingDownload()` → `VLMServing.isDownloaded()` (local cache
only) → **Download** → `VLMServing.download(progress:)` → `VLMService` →
`MLXLMCommon.resolve` + `HubDownloader` (weights to Application Support, excluded from
backup; nothing loaded into memory) → **Start** sets the flag → tabs.

Data flow for a scan:

`ScanView` (reads the limit and the chosen album from `@AppStorage`; a saved album is
checked with `ScanViewModel.loadAlbums()` first) → `ScanViewModel.scan(limit:albumID:)` →
`ScanCoordinator.scan(limit:albumID:)`:
`PhotoLibraryProviding.scanWindowIDs(albumID:)` (`recentImageIDs` or
`imageIDs(inAlbumID:)`, newest 500) minus `ScanStore.knownAssetIDs` →
for each, `PhotoLibrary.loadImage` (1024 px + thumbnail + `ImageSource`) → camera? record
skipped : `Triage.isCandidate` + `ImageAnalyzer.signals` → `ScanStore.record` (triaged /
skipped, with blur + feature print) → … up to the limit → skipped items from before the
cleanup feature get measured (no model yet) → `VLMServing.load()` → for each `triaged`
item: `Extractor` → `ScanStore.complete` (extracted / skipped "none" / failed) →
`CleanupJudge.applyRules()` (`DuplicateFinder` off the main actor, then blur) → for each
unjudged skipped item: `CleanupJudge.ask` (`UsefulnessQuestion`, same loaded model; loads
it only if extraction had nothing to read) → `VLMServing.unload()`. The card stack reads
`extracted` items through `@Query`, so new cards appear as each item is saved. No Photos
access ends in `ScanPhase.noPhotoAccess`; a failed load in `.modelLoadFailed(message:)`.
**Rescan everything**: `SettingsViewModel` → `ScanCoordinator.resetCache()` →
`ScanStore.deleteItemsNotDone()`.

Data flow for a swipe:

`CardStackView` (drag past 110 pt, or a button) → `CardStackViewModel.perform(item)` →
`AppDependencies.actionPerformers[type]` (`EventAction` / `PlaceAction` / `ReceiptAction`,
all behind `ActionPerformer`) → `ActionOutcome` → item `done` + toast + success haptic
(`completedCount`; the view also plays a light impact on every committed swipe). A thrown
`ActionError` keeps the item `extracted` and shows its message. Skip → item `skipped`.
`EditSheet` → `CardStackViewModel.save(_:for:)` rewrites the item's result.
`ExpenseListView` reads `Expense` through `@Query`; `ExpensesViewModel` sums per currency.
A left swipe also records `SkipReason.swipedLeft`, which makes the card eligible for cleanup.

Data flow for cleanup: `RootView` `@Query`s items with a `cleanupReasonRaw` to show or hide
the tab → `CleanupView` grid → `CleanupViewModel.deleteSelected` →
`PhotoLibraryProviding.deleteAssets` (`PHAssetChangeRequest.deleteAssets`, iOS confirms; a
`userCancelled` error means "declined") → deleted items' `ScreenshotItem`s removed, the
unselected get `cleanupKeptAt` and leave the pile.

Eval flow (debug): `EvalView` → `EvalViewModel` → `PhotoLibrary` → `Triage` (OCR, timing)
→ `Extractor` → row on screen + `eval-report.json`.

`AppDependencies.live` builds the one `VLMService`, the SwiftData container, and the
`ScanCoordinator`, and hands services out as protocols (`VLMServing`, `PhotoLibraryProviding`,
`ImageTriaging`, `ImageAnalyzing`), so features never import Inference and tests swap in a fake.

Layer rules (dependencies point downward only) are listed in `CLAUDE.md`.

## Dependencies (Swift Package Manager)

- `mlx-swift-lm` 3.32.x: `MLXVLM`, `MLXLMCommon`
- `mlx-swift` 0.32.x: `MLX` (memory cache control; already a dependency of mlx-swift-lm)
- `swift-transformers` 1.3.x: `Tokenizers` (mlx-swift-lm 3.x needs a tokenizer package)
- `swift-huggingface` 0.13.x: `HuggingFace` (model download, the documented downloader)

The Xcode project is generated from `project.yml` with XcodeGen. The generated
`SlothRoll.xcodeproj` is committed, so XcodeGen is only needed when the spec changes.
