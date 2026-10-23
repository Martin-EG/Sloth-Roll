## Dev log

### 2026-10-20 (day 1): VLM spike

- Built: Xcode project (iOS 18+, Swift 6, strict concurrency), full folder layout from
  `CLAUDE.md`, mlx-swift-lm integration, `VLMService` actor (load / describe / unload /
  download progress), temporary `SpikeView` with metrics, os.Logger "spike" metrics,
  increased-memory-limit entitlement, unit tests for the spike view model.
- Files added: `project.yml`, `SlothRoll.xcodeproj`, `App/*`, `Features/Debug/Spike*`,
  `Inference/*`, `Models/VLMServing.swift`, `Shared/*`, `Resources/*`,
  `SlothRollTests/FeaturesTests/SpikeViewModelTests.swift`, `README.md`, `.gitignore`.
- Model: `mlx-community/Qwen3-VL-2B-Instruct-4bit`, 1,798,023,774 bytes (~1.8 GB) download.
- Known issues: device timings not recorded yet (phone was unreachable at the end of the
  session); `downloadProgress` is single-consumer; Release builds show a placeholder screen.
- Added SwiftUI previews: `SpikeView` (Idle, Loading, Described, Load failed) and `RootView`,
  backed by `Features/Debug/PreviewVLM.swift` (canned answers, fake progress, placeholder
  screenshot). Previews never load MLX, so they work in the canvas. Added DEBUG-only
  `SpikeViewModel.setImageForPreview(_:)` because PhotosPicker can't run in previews.

### 2026-10-20 (day 2): typed extraction + eval screen

- Built: `ActionResult` schema with forgiving enums (unknown type → none, unknown confidence →
  low, unknown currency → nil, Spanish type names accepted); bilingual `ExtractionPrompt`
  with today plus the next 7 days spelled out (English/Spanish weekdays) and one JSON example;
  `ResultParser` (first `{` to last `}`, falls back to the first balanced object, JSON5 for
  trailing commas, validates date/time/amount, typed `PipelineError`); `Extractor` (one
  stricter retry, then "Couldn't read this one", never throws); `Triage` (Vision fast OCR,
  timing only for now); `PhotoLibrary`; debug `EvalView` replacing the spike, with
  correct/wrong marks, summary, saved JSON report and a `-evalAutorun` launch argument.
- Files added: `Models/{ActionResult,ActionType,Confidence,Currency}.swift`,
  `Pipeline/*` (12 files), `Features/Debug/Eval*.swift`, `PreviewPhotoLibrary.swift`,
  tests in `ParserTests/`, `PipelineTests/`, `FeaturesTests/EvalSummaryTests.swift`.
  Removed: `SpikeView`, `SpikeViewModel`, `SpikeConfig`, `SpikeViewModelTests`.
  Changed: `AppDependencies`, `RootView`, `Log`, `PreviewVLM`, `project.yml` (Photos usage
  string), `.gitignore`.
- Fixed: `.gitignore` had `models/`, which on macOS (case-insensitive) also ignored
  `SlothRoll/Models/`, so `VLMServing.swift` was never committed. Now `/models/`.
- Tests: 30 pass (simulator). Device build: no new warnings.
- First device eval (iPhone 17 Pro): only 1 image reached the app. A party invite
  ("5 de julio 2026, hora 19") came back as `none` with no title: wrong. Extraction 14.4 s
  (first call after load, likely includes warm-up), OCR fast mode 0.24 s.
- Fix after first eval: an answer with no "type" key (the model once replied
  `{"error": "..."}`) used to pass as a valid `none`; it now fails and triggers the retry.
  Eval report now records album size and skipped (iCloud-only) images.
- Eval run 2 (album "Sloth Test" = 2 images, 0 skipped): type correct 2/2 (the invite was
  0/1 before the fix; the retry recovered it). Fields are weak: the cinema ticket says
  "Hoy, 16 de julio, 08:25 PM" but came back dated today (2026-10-20), time 08:25 (an
  earlier run gave 20:25), and the order number 5435 as an amount in MXN. Extraction 7.4 s
  for one attempt, 14.9 s with a retry; OCR fast mode 0.09-0.12 s.
- Known issues: relative dates ("Hoy") resolve against today, not the day the screenshot
  was taken; order numbers get read as amounts; AM/PM conversion is unstable; the model
  wraps JSON in code fences every time (parser handles it). 2 images is too few to judge
  accuracy or triage; no junk screenshots in the album yet.

### 2026-10-21 (day 2, cont.): dates anchored to the screenshot, amount rule

- Built: the prompt now counts relative dates from the screenshot's creation date
  (`PHAsset.creationDate` → `LibraryImage.capturedAt` → `Extractor.extract(image:capturedAt:)`
  → `ExtractionPrompt`). Amount rule: money only, never order/folio/booking/ticket/seat/phone
  numbers. AM/PM conversion examples. `"type"` is listed as a required first field, and a
  missing type gets its own error (`PipelineError.missingType`) and a specific retry reason.
- Files changed: `Pipeline/{ExtractionPrompt,Extractor,LibraryImage,PhotoLibrary,
  PipelineError,ResultParser}.swift`, `Features/Debug/{EvalRow,EvalReport,EvalViewModel,
  PreviewPhotoLibrary}.swift`, tests (35 pass).
- Lesson: the first version of the new prompt made the model drop the `"type"` key on 23 of
  24 images, so every image needed a retry and 6 fell back. Listing `"type"` as a required
  field fixed it: 0 retries, 0 fallbacks in the next run.
- Eval (19 images, judged against OCR text): type right on 18/19 (95%); the miss is a
  Cinépolis purchase history ("Total: $490") read as an event, should be receipt. All 6
  junk images came back `none`. Relative dates right on 4/5 ("Hoy, 16 de julio" now gives
  2026-07-16). Events with date and time both right: 6 of 10 checked. Errors: the chat
  message timestamp or status-bar clock used as the event time (2 rows), a past "25 abr"
  dated 2026 instead of 2027, one wrong relative date. Order number no longer read as an
  amount (came back 0 instead of null).
- Timing: median 7.9 s per image, mean 8.5 s without one 84.5 s outlier (a camera photo,
  cause unknown), 12.5 s with it. OCR fast mode mean 0.15 s.
- Triage: "no text" (0 characters) drops 2 of 6 junk images; a 20-character threshold drops
  3 of 6 and loses no real action (shortest real one had 40). Text-heavy junk (chats) still
  needs the model.
- Known issues: event time taken from message timestamps or the status bar; no-year dates in
  the past; amount 0 instead of null; the 84.5 s outlier; album contents changed between
  runs (24 → 19 images), so runs aren't directly comparable.

### 2026-10-21 (day 2, cont.): screenshots only

- Built: `PhotoLibrary.assetIDs(inAlbum:)` fetches only assets with the `photoScreenshot`
  subtype (PhotoKit predicate `(mediaSubtypes & photoScreenshot) != 0`). Files changed:
  `Pipeline/PhotoLibrary.swift`, `Pipeline/PhotoLibraryProviding.swift`,
  `Features/Debug/EvalReport.swift` (doc only).
- Eval (album: 19 images → 14 screenshots): the filter dropped 5 images: 3 camera photos and
  a dog meme (junk, good) and the "Anuar 50's" party flyer (a real event, saved from a chat,
  not screenshotted: lost). Type right 13/14; the miss is still the Cinépolis purchase
  history (receipt read as event).
- Triage after the filter: every screenshot has at least 40 OCR characters (the status-bar
  clock alone adds some), so "no text" drops 0 and a 20-character threshold drops 0. The 2
  junk screenshots left are chats with 222 and 581 characters. Conclusion: once only
  screenshots are fetched, an OCR text gate adds nothing; OCR (0.10 s mean) is only worth
  keeping as an input for a smarter pre-classifier.
- Timing: median 7.8 s, but two outliers (329.5 s and 39.9 s) push the mean to 33.1 s. Likely
  the phone locked or the app went to the background mid-run (iOS pauses GPU work in the
  background); not confirmed.
- Known issues: saved images (flyers from WhatsApp) are skipped by the screenshot filter;
  same image can get a different date between runs (temperature 0.2), e.g. "sábado"
  → 2026-10-24 last run, 2026-10-20 this run.

### 2026-10-21 (day 2, cont.): all images back in, labeled by source

- Changed course: the screenshots-only filter dropped a flyer saved from WhatsApp, and a
  camera photo of a flyer would be dropped the same way. The album fetch now returns every
  image again. New `Pipeline/ImageSource.swift` labels each one `screenshot` (Photos
  subtype), `camera` (file has camera make/model/lens metadata), or `saved` (no camera
  metadata, e.g. WhatsApp). The label is recorded per eval row; nothing is skipped by it.
- Eval screen keeps the phone awake during a run (`isIdleTimerDisabled`), since stalls of
  107-329 s hit OCR as well as the model, which points to the phone locking mid-run.
- Files: `Pipeline/{ImageSource,LibraryImage,PhotoLibrary,PhotoLibraryProviding}.swift`,
  `Features/Debug/{EvalRow,EvalReport,EvalRowView,EvalViewModel,PreviewPhotoLibrary}.swift`,
  `SlothRollTests/PipelineTests/ImageSourceTests.swift`. 38 tests pass.
- Eval (19 images: 14 screenshots, 2 saved, 3 camera): sources labeled correctly on all 19.
  Type right 18/19 (Cinépolis purchase history still read as event). The saved Anuar flyer
  is back and fully right (event, 2026-10-23 19:00, venue).
- Triage (6 junk: 3 camera photos of kids, 1 saved meme, 2 chats): 0 OCR characters drops
  2 of 6; under 20 characters drops 3 of 6 (all camera photos) and loses no real action
  (shortest real one: 40). The meme (39) and chats need the model. Source alone is not a
  safe filter.
- Timing: median 7.8 s per image; mean 13.5 s because of one 119 s stall (before the
  keep-awake fix, which hasn't been re-measured). OCR typically 0.02-0.15 s.

### 2026-10-21 (day 3): scan pipeline, library to stored results

- Built: SwiftData models (`ScreenshotItem`, `Expense`) and `Persistence`; `ScanCoordinator`
  (skips cached assets, triages every new image before any model loads, then loads the
  model and reads only candidates one at a time, saves each item immediately, progress
  phase/done/total/thumbnail, cancel, pause on memory warning with model unload, resume picks
  up triaged-but-unread items); `Triage.isCandidate` (Vision OCR, 20+ characters);
  `PhotoLibrary.recentImageIDs` (newest first) and `PhotoAccess` (full / limited / denied);
  `loadImage` now decodes straight to 1024 px (long side) plus thumbnail via ImageIO;
  `ScanView` + `ScanViewModel` with a temporary results list by type and last-scan stats;
  debug menu (eval screen as a sheet, clear scan cache); `-scanAutorun` / `-scanReset`.
- Decisions: triage = OCR with 20 characters (day-2 numbers). Fetch = screenshots and saved
  images, camera photos skipped (the screenshot-only filter lost a WhatsApp flyer on day 2).
  Model is unloaded after every scan.
- Files added: `Storage/{ScreenshotItem,Expense,ScanStatus,SkipReason,Persistence}.swift`,
  `Pipeline/{ScanCoordinator,ScanStore,ScanPhase,ScanStats,PhotoAccess,ImageTriaging}.swift`,
  `Features/Scan/{ScanView,ScanViewModel,ScanStatsSection,ScanResultsSections,ScanResultRow,
  ScanConfig}.swift`, tests `PipelineTests/{ScanCoordinatorTests,ScanFakes}.swift`,
  `StorageTests/ScreenshotItemTests.swift`. Changed: `App/*`, `Pipeline/{PhotoLibrary,
  PhotoLibraryProviding,PipelineConfig,Triage,TextScan}.swift`, `Shared/Log.swift`,
  `Features/Debug/{EvalView,EvalViewModel,EvalSummary,PreviewPhotoLibrary}.swift`,
  `project.yml` unchanged (project regenerated with XcodeGen).
- Tests: 47 pass (simulator). Device build: no new warnings.
- Device run (iPhone 17 Pro, real library, cache cleared): 50 images triaged, 43 sent to the
  model (19 actions, 24 none, 0 failed). Total 221 s: triage 33.9 s, model load 1.4 s,
  reading 185.6 s (4.3 s per image). Peak memory 2.77 GB (footprint since launch); highest
  sample between images 2.0 GB. No memory warning, no crash.
- Known issues: the library's newest 500 images held 394 camera photos, and each is loaded
  (and decoded to 1024 px) just to be skipped, which is most of the 33.9 s triage time; they
  are cached as skipped, so the next scan doesn't repeat it. Triage only dropped 7 of 50
  (status-bar text and chats pass 20 characters easily); the model answered "none" on 24.
  OCR now runs on the 1024 px image (day-2 numbers were at full size), and the eval screen
  now also gets 1024 px images. A scan unloads the shared model, so an open eval screen thinks
  the model is still loaded (debug only).

### 2026-10-21 (day 4): swipe review cards, actions, expenses tab

- Built: `ActionPerformer` protocol with three performers: `EventAction` (EventKit,
  write-only access via `requestWriteOnlyAccessToEvents`, default calendar, 1 hour or
  all-day), `PlaceAction` (MKLocalSearch best match opened in Maps, `maps://?q=` fallback),
  `ReceiptAction` (inserts an `Expense`; undated receipts take the screenshot's date). Each
  returns a one-line `ActionOutcome`; failures are typed `ActionError` with user-facing
  messages. Swipe card stack (top 3 drawn, rotation + green/red tint while dragging, fly-out,
  spring back on failure, buttons and VoiceOver actions for the same), "not sure" tag on
  low confidence, toast, edit sheet, empty state. Expenses tab with per-currency totals and
  swipe-to-delete. TabView navigation; the temporary results list is gone and the last-scan
  stats moved to the debug menu.
- Files added: `Actions/{ActionPerformer,ActionError,ActionsConfig,EventDraft,EventAction,
  PlaceAction,ReceiptAction}.swift`, `Models/{ActionOutcome,ActionResult+Dates,
  Currency+Format}.swift`, `Features/Scan/{CardStackView,CardStackViewModel,CardView,
  CardText,TypeBadge,EditSheet}.swift`, `Features/Expenses/{ExpenseListView,
  ExpensesViewModel,CurrencyTotal}.swift`, `Shared/{Toast,ToastOverlay}.swift`, tests in
  `ActionsTests/` and `FeaturesTests/`. Removed: `Features/Scan/{ScanResultsSections,
  ScanResultRow}.swift`. Changed: `App/{AppDependencies,RootView}.swift`,
  `Features/Scan/{ScanView,ScanConfig}.swift`, `Pipeline/{PhotoLibrary,
  PhotoLibraryProviding}.swift` (new `loadPreview` for card images via PHImageManager),
  `Features/Debug/PreviewPhotoLibrary.swift`, `Shared/Log.swift` (`actions`, `expenses`
  categories), `project.yml` + `Info.plist` (calendar usage string), test fakes.
- Tests: 65 pass (simulator). Device build: no new warnings.
- Known issues: not tried on the phone yet (swipe feel, permission prompt, Maps hand-off).
  `MKLocalSearch` is a network call to Apple's place search, which bends the "no network"
  rule (the user asked for it; Maps itself needs the network anyway). Event dates use the
  phone's current time zone. The edit sheet can't change the type (a receipt read as an
  event stays an event). Cards for screenshots deleted from Photos show a blank image.

### 2026-10-21 (day 5): demo-ready fresh install

- Built: first-launch onboarding (two intro pages + model download screen with size,
  Wi-Fi hint, progress in MB, retry, Start; completion in `@AppStorage`). Download-only
  path in the Inference layer (`VLMServing.isDownloaded()` / `download(progress:)`, via
  `MLXLMCommon.resolve`, no model load); model cache excluded from iCloud backup. Scan
  states: "reading your screenshots" while cards are pending, a result line after each
  scan (new cards / nothing to do / no new screenshots), a full-screen Photos-denied view
  with Open Settings, and a model-failed message with **Try again**. Settings tab: scan
  limit 25/50/100, Rescan everything (with confirmation; keeps `done` items so actions
  never repeat), model ID/size/status, "Runs on-device", debug section (eval screen, show
  onboarding again, last scan stats; the ladybug menu is gone). Branding: sloth-green
  accent (light #4A7A50, dark #4F8455; white text passes contrast in both), wired through
  the build setting, SlothMark logo on page one, green swipe tint and action button. Haptics:
  light impact on every committed swipe, success when an action finishes.
- Cleanup: renamed `ModelCatalog.spike*` to `extraction*`; removed unused
  `MemoryProbe.availableBytes` and `Log.app`; replaced `ScanPhase.failed(message:)` with
  typed `.noPhotoAccess` and `.modelLoadFailed(message:)`. No `print()` in the app.
- Files added: `Features/Onboarding/{OnboardingView,OnboardingPage,ModelDownloadView,
  OnboardingViewModel,ModelDownloadState,OnboardingConfig}.swift`,
  `Features/Settings/{SettingsView,SettingsViewModel}.swift`, `Shared/SettingsKey.swift`,
  `Assets.xcassets/SlothMark.imageset`, tests `FeaturesTests/{OnboardingViewModelTests,
  ScanViewModelTests}.swift`. Moved: `ScanStatsSection` to `Features/Settings/`.
  Changed: `App/RootView.swift`, `Features/Scan/{ScanView,ScanViewModel,CardStackView,
  CardStackViewModel,ScanConfig}.swift`, `Features/Debug/PreviewVLM.swift`,
  `Pipeline/{ScanCoordinator,ScanStore,ScanPhase,PipelineConfig}.swift`,
  `Inference/{VLMService,HubDownloader,ModelCatalog,InferenceConfig,InferenceError}.swift`,
  `Models/VLMServing.swift`, `Shared/{Log,MemoryProbe}.swift`, `AccentColor.colorset`,
  `project.yml`, test fakes, `ScanCoordinatorTests` (+3 tests).
- Tests: 76 pass (simulator). Device build (clean): no warnings from app code.
  Light and dark mode checked in the Simulator (onboarding, Scan, Photos-denied, Settings).
- Known issues: the download wasn't run end to end on the phone today (Simulator only up
  to the Download button). If the app's data is restored from a backup without the model,
  onboarding is marked done and the first scan downloads the model with only "Loading the
  model…" as progress. No free-space check before the 1.8 GB download. Cancelling the
  download isn't possible (leaving the app pauses it; Retry resumes from the cache).
  Haptics not felt on hardware yet.

### 2026-10-21 (day 6): Clean up pile for useless screenshots

- Built: blur score (Laplacian variance on a 512 px grayscale copy, plus a contrast guard so
  blank screens aren't "blurry") and a Vision feature print (revision 2) computed during
  triage while the image is already loaded, saved on `ScreenshotItem`. After extraction,
  `CleanupJudge` groups near-duplicates among skipped items (`DuplicateFinder`, Euclidean
  distance < 0.25, transitive groups, newest kept), marks blurry ones, and asks the loaded
  VLM "Is this screenshot still useful to keep? Answer only yes or no." for the rest (only
  a clear "no" counts). New **Clean up** tab (only when there are candidates, with a badge):
  grid with reason badges, all selected, select/deselect all, "Delete N screenshots" via
  `PHAssetChangeRequest.deleteAssets` (iOS confirmation, Recently Deleted). Unselected items
  are kept for good after a delete. Left swipes now record `SkipReason.swipedLeft`.
  Skipped items scanned before today are measured on the next scan before the model loads.
- Files added: `Storage/CleanupReason.swift`, `Pipeline/{ImageSignals,ImageAnalyzing,
  ImageAnalyzer,DuplicateFinder,UsefulnessQuestion,CleanupJudge}.swift`,
  `Features/Cleanup/{CleanupView,CleanupCell,CleanupReasonBadge,CleanupViewModel,
  CleanupConfig}.swift`, `App/RootTab.swift`, tests `PipelineTests/{DuplicateFinderTests,
  ImageAnalyzerTests,UsefulnessQuestionTests}.swift`, `FeaturesTests/CleanupViewModelTests.swift`.
  Changed: `Storage/{ScreenshotItem,SkipReason}.swift`, `Pipeline/{ScanCoordinator,ScanStore,
  ScanPhase,ScanStats,PipelineConfig,PipelineError,PhotoLibrary,PhotoLibraryProviding,
  Extractor}.swift`, `App/{AppDependencies,RootView}.swift`, `Features/Scan/{ScanView,
  ScanViewModel,CardStackViewModel}.swift`, `Features/Settings/ScanStatsSection.swift`,
  `Features/Debug/PreviewPhotoLibrary.swift`, `Shared/Log.swift`, test fakes,
  `SlothRoll.xcodeproj` (XcodeGen). Removed `Features/Cleanup/.gitkeep`.
- Decisions: the model's "none" items count as leftovers too (memes and chats are the best
  cleanup targets), not only triage skips and left swipes. The coordinator now loads the
  model at most once per scan and unloads at the end, so extraction and the cleanup
  question share one load. `ScanCoordinator` is 257 lines after moving the log line into
  `ScanStats` and sharing one per-photo loop.
- Tests: 98 pass (simulator). Device build: no warnings from app code.
- Known issues: thresholds (blur 50, flat contrast 8, duplicate 0.25) are educated guesses,
  not measured on the phone yet. Duplicate grouping compares every pair of skipped
  screenshots each scan (fine for hundreds, slow for many thousands). Left swipes are
  judged on the next scan, not right away. An asset deleted outside the app still shows in
  the grid with a blank thumbnail until you delete it there. The SwiftData store gained
  fields (lightweight migration) — not yet opened on the phone with day-5 data.

### 2026-10-21 (day 7): release prep for submission

- Built: no features, no refactors. README rewritten in a short submission layout (pitch,
  how it works, Mermaid architecture diagram, quick start, limitations, models and licenses
  table, credits), with the long detail moved to tracked `docs/` pages. Added an MIT
  `LICENSE`. Version 1.0 (build 1), now set as `MARKETING_VERSION` /
  `CURRENT_PROJECT_VERSION` in `project.yml` so XcodeGen keeps it.
- Audit: no TODO/FIXME, no `print()`, no hardcoded test data in app code (the only sample
  text is the JSON example inside the extraction prompt, on purpose). Every debug-only
  piece was already behind `#if DEBUG`: the whole `Features/Debug/` folder (EvalView and
  its view model, previews, fakes), the Settings debug section, `ScanStatsSection`, the
  `-evalAutorun` / `-scanAutorun` / `-scanReset` launch arguments, and the stats file. The
  Release build contains none of it.
- Files added: `LICENSE`, `docs/{how-it-works,architecture,xcode-setup,debug-and-eval}.md`.
  Changed: `README.md`, `.gitignore` (archives, dSYMs, eval/scan JSON copied off the phone;
  `docs/` is tracked now except the two private planning notes), `project.yml`,
  `SlothRoll/Resources/Info.plist`, `SlothRoll.xcodeproj` (XcodeGen).
- Checked from a fresh `git clone`: Release and Debug builds for a generic iOS device with
  no warnings from app code, 98 tests pass in the Simulator.
- Known issues: screenshots, demo GIF and video link are placeholders. A `name=`
  Simulator destination in `xcodebuild` can match a paired phone with the same name; use
  the Simulator's UDID or ⌘U.

### 2026-10-23 (day 8): scan one album, onboarding mentions it

- Built: **Scan from** row above the Scan button opens a sheet: all recent photos, Photos'
  Screenshots album, then your own albums with image counts. The choice is remembered
  (`@AppStorage` album ID + title); an album deleted in Photos falls back to all recent
  photos on the next scan. `ScanCoordinator.scan(limit:albumID:)` triages only that album's
  newest 500 images; everything after triage (model, cards, Clean up) is unchanged. New
  third onboarding page: "Scan one album, then clean it up." `ModelSession` pulled out of
  the coordinator (one model load per scan) to keep the file near 250 lines (now 254).
- Files added: `Pipeline/{PhotoAlbum,ModelSession,PhotoLibraryProviding+ScanWindow}.swift`,
  `Features/Scan/AlbumPickerView.swift`. Changed: `Pipeline/{PhotoLibrary,
  PhotoLibraryProviding,ScanCoordinator}.swift`, `Features/Scan/{ScanView,
  ScanViewModel}.swift`, `Features/Onboarding/{OnboardingView,OnboardingConfig}.swift`,
  `Features/Debug/PreviewPhotoLibrary.swift`, `Shared/SettingsKey.swift`,
  `App/RootView.swift`, test fakes, `ScanCoordinatorTests` (+1), `ScanViewModelTests` (+3),
  `docs/{how-it-works,architecture,xcode-setup}.md`, `SlothRoll.xcodeproj` (XcodeGen).
- Decisions: shared and synced albums aren't listed (their photos can't be deleted from the
  phone, which breaks scan-then-clean-up). Albums are only listed when the picker opens or a
  saved album is checked before a scan, so opening the Scan tab never shows the Photos
  prompt by itself.
- Tests: 102 pass (Simulator). Device build: no warnings from app code.
- Known issues: the Clean up tab offers candidates from every scan, not only the chosen
  album. Not tried on the phone yet (album list speed with many albums, the new onboarding
  page on a small screen). Screenshots/GIF placeholders from day 7 still open.

### 2026-10-23 (day 8, cont.): screenshots and demo video in the README

- README: demo video link (YouTube Short; the thumbnail links to it) replaces the
  placeholder, and the Screenshots section shows four phone screenshots (onboarding, album
  page, album picker, a scan with an event card). The two HEIC captures were converted to
  PNG because GitHub and DEV don't show HEIC.
- Files added: `public/{Onboarding-screen.PNG,onboarding-select-album-screen.PNG,
  selecting-album.png,reading-screenshots.png}`. Changed: `README.md`. No code changed.
- Known issues: no screenshot of the Expenses or Clean up tabs yet. The original `.HEIC`
  files are left out of git.
