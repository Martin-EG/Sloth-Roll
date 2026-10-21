![Sloth Roll](public/sloth-roll-banner.png)
# Sloth Roll

## Overview

Sloth Roll is an iOS app that reads your screenshots on-device with an open-weight
vision-language model (VLM) and turns them into actions: a calendar event, a Maps place,
or an in-app expense. You only swipe. Nothing leaves the phone except the one-time model
download.

## How it works

Today (day 3) you tap **Scan** and the app works through your newest images on its own,
saving every answer on the phone. The swipe cards come next; for now the results show as a
plain list grouped by type.

1. **Find new images.** The app asks for Photos access (if you only allow some photos, it
   scans those and says so). It looks at the newest 500 images and skips anything it has
   already seen. Camera photos (files with camera make/model/lens info) are skipped and
   remembered; screenshots and saved images (flyers from WhatsApp, images from Safari) go on.
2. **Triage first, for up to 50 new images.** Apple's text recognition reads each one. If it
   finds fewer than 20 characters, the image is marked skipped. No model is loaded yet.
3. **Then the model.** The vision model loads once and reads only the images that passed
   triage, one at a time, newest first. Each answer is saved right away: a real action
   (event, place, receipt), "no action", or "couldn't read this one". Then the model is
   unloaded to free about 2 GB.
4. **Stop, pause, resume.** "Stop after this one" finishes the current image and keeps
   everything so far. If iOS warns that memory is low, the app finishes the current image,
   unloads the model, and pauses with a message. Tapping **Resume scan** picks up the images
   that passed triage but weren't read yet.
**Reading one image** (the extraction step):

1. The app builds a prompt (Spanish + English) that includes the day the screenshot was
   taken (from Photos; today if unknown) and the seven days after it, with weekday names.
   So "hoy", "mañana" or "este sábado" mean those days relative to when you took the
   screenshot, not when you scan it. It asks for one JSON object: type (event / place /
   receipt / none, always required), title, date, time, location, amount, currency,
   confidence. Amounts must be money (a price or total); order, folio and booking numbers
   are called out as not amounts. AM/PM times are converted to 24-hour.
2. The on-device model reads the screenshot and answers.
3. The parser cuts the answer down to the JSON object (it ignores chatter, code fences,
   trailing commas, and junk after the object), decodes it, and checks it: the date must be
   a real day, the time a real 24-hour time, the amount not negative. Unknown words for
   type or confidence become the safe choice ("none", "low") instead of an error.
4. If the answer can't be used, the app asks once more with a stricter reminder. If that
   fails too, the screenshot is marked "Couldn't read this one". It never crashes on bad
   output.

**Debug menu (debug builds).** The ladybug button opens the eval screen and can clear the
scan cache (so the next scan redoes everything).

**Eval screen (debug builds).** Tap **Load model**, then **Run eval**. The app reads every
image in the Photos album "Sloth Test" (screenshots, saved images, and camera photos; each
row is labeled with its source), runs Apple's text recognition and then the model on
each, and lists thumbnail, type, title, date, amount, and time taken. The summary shows
counts per type, average times, retries, and accuracy. Use the menu on each row to mark it
correct, or wrong and what it should have been. Marks are saved to
`Documents/eval-report.json` and carried over to the next run.

## Architecture

```
SlothRoll/
  App/         SlothRollApp (entry), AppDependencies (composition root), RootView
  Features/    one folder per screen (View + @Observable @MainActor ViewModel)
    Scan/      ScanView, ScanViewModel, ScanStatsSection, ScanResultsSections (temporary
               list by type, via @Query), ScanResultRow, ScanConfig
    Debug/     (DEBUG only) EvalView, EvalRowView, EvalViewModel, EvalRow, EvalMark,
               EvalSummary, EvalReport, EvalReportStore, EvalConfig,
               PreviewVLM + PreviewPhotoLibrary (fakes for SwiftUI previews)
  Pipeline/    ScanCoordinator (@Observable @MainActor: triage pass, then extraction pass),
               ScanStore (SwiftData reads/writes for the scan), ScanPhase, ScanStats,
               Extractor (VLM + parse + retry), ExtractionPrompt, ResultParser,
               ExtractionReport, ImageTriaging + Triage (Vision OCR, 20+ chars) + TextScan,
               PhotoLibraryProviding + PhotoLibrary (PhotoKit) + PhotoAccess + LibraryImage
               + ImageSource, PipelineError, PipelineConfig
  Inference/   VLMService (actor), ModelCatalog, InferenceConfig, InferenceError,
               HubDownloader + TransformersTokenizer(Loader) (mlx-swift-lm adapters)
  Actions/     (empty) EventKit / Maps / expense performers
  Models/      ActionResult, ActionType, Currency, Confidence, VLMServing (protocol)
  Storage/     ScreenshotItem (@Model: assetID unique, status, skip reason, result JSON,
               capturedAt, processedAt), Expense (@Model), ScanStatus, SkipReason,
               Persistence (container; falls back to in-memory if the store won't open)
  Shared/      Log (os.Logger categories), MemoryProbe, Duration+Seconds
  Resources/   Assets, Info.plist, SlothRoll.entitlements
SlothRollTests/
  ParserTests/     ResultParserTests
  PipelineTests/   ExtractorTests (scripted fake VLM), ExtractionPromptTests,
                   ImageSourceTests, ScanCoordinatorTests + ScanFakes
  StorageTests/    ScreenshotItemTests
  FeaturesTests/   EvalSummaryTests
```

Data flow for a scan:

`ScanView` → `ScanViewModel` → `ScanCoordinator.scan()`:
`PhotoLibrary.recentImageIDs` (newest 500) minus `ScanStore.knownAssetIDs` →
for each, `PhotoLibrary.loadImage` (1024 px + thumbnail + `ImageSource`) → camera? record
skipped : `Triage.isCandidate` → `ScanStore.record` (triaged / skipped) → … up to 50 →
`VLMServing.load()` → for each `triaged` item: `Extractor` → `ScanStore.complete`
(extracted / skipped "none" / failed) → `VLMServing.unload()`. The list on screen reads
SwiftData through `@Query`, so it updates as each item is saved.

Eval flow (debug): `EvalView` → `EvalViewModel` → `PhotoLibrary` → `Triage` (OCR, timing)
→ `Extractor` → row on screen + `eval-report.json`.

`AppDependencies.live` builds the one `VLMService`, the SwiftData container, and the
`ScanCoordinator`, and hands services out as protocols (`VLMServing`, `PhotoLibraryProviding`,
`ImageTriaging`), so features never import Inference and tests swap in a fake.

Layer rules (dependencies point downward only) are listed in `CLAUDE.md`.

### Dependencies (Swift Package Manager)

- `mlx-swift-lm` 3.32.x: `MLXVLM`, `MLXLMCommon`
- `mlx-swift` 0.32.x: `MLX` (memory cache control; already a dependency of mlx-swift-lm)
- `swift-transformers` 1.3.x: `Tokenizers` (mlx-swift-lm 3.x needs a tokenizer package)
- `swift-huggingface` 0.13.x: `HuggingFace` (model download, the documented downloader)

The Xcode project is generated from `project.yml` with XcodeGen. The generated
`SlothRoll.xcodeproj` is committed, so XcodeGen is only needed when the spec changes.

## Setup

1. Xcode 27.1 or newer. Install the Metal Toolchain once (MLX compiles Metal shaders):
   `xcodebuild -downloadComponent MetalToolchain`
2. Open `SlothRoll.xcodeproj`. Signing is automatic with team `HYZ2GHP9BH` (Personal Team).
   If you use a different team, change it under Signing & Capabilities.
3. Entitlement `com.apple.developer.kernel.increased-memory-limit` is in
   `SlothRoll/Resources/SlothRoll.entitlements`; Xcode adds it to the provisioning profile
   automatically.
4. Run on a physical iPhone (MLX does not run in the Simulator). On first install, trust the
   developer profile on the phone: Settings → General → VPN & Device Management.
   Developer Mode must be on.
5. Keep the phone on Wi-Fi for the first **Load model** (~1.8 GB download). The model is
   stored in Application Support, so iOS won't purge it.
6. If `project.yml` changes: `brew install xcodegen && xcodegen generate`.

7. Photos: the app asks for library access on the first **Run eval**
   (`NSPhotoLibraryUsageDescription` is set in `project.yml` / `Info.plist`). Choose
   **Allow Full Access**, or include the test screenshots if you pick limited access.
8. Eval: create an album named exactly **Sloth Test** in Photos with the test screenshots
   (kept on the device, not only in iCloud). To run without taps, launch with the argument
   `-evalAutorun` (Xcode: Scheme → Run → Arguments, or
   `xcrun devicectl device process launch --device <UDID> com.martinespericueta.slothroll -- -evalAutorun`).
   Copy the report off the phone with
   `xcrun devicectl device copy from --device <UDID> --domain-type appDataContainer --domain-identifier com.martinespericueta.slothroll --source Documents/eval-report.json --destination eval-report.json`.

9. Scan timing run (debug): launch with `-scanAutorun -scanReset` (clears the cache, then
   scans). Stats land in `Documents/scan-stats.json`; copy them off with the same
   `devicectl ... copy from` command as step 8, with `--source Documents/scan-stats.json`. Keep the phone
   unlocked; the scan screen also keeps it awake while running.

Logs: Console.app, filter subsystem `SlothRoll`, category `eval` (per-image timings and the
run summary), `pipeline` (attempts, parse failures, `scan_done` summary, memory warnings),
`storage`, `scan` or `inference`.

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
