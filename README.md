# Sloth Roll

## Overview

Sloth Roll is an iOS app that reads your screenshots on-device with an open-weight
vision-language model (VLM) and turns them into actions: a calendar event, a Maps place,
or an in-app expense. You only swipe. Nothing leaves the phone except the one-time model
download.

## How it works

Today (day 2) the app turns one screenshot into a checked, typed answer, and has a debug
screen to measure how well that works.

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

**Eval screen (debug builds).** Tap **Load model**, then **Run eval**. The app reads every
screenshot in the Photos album "Sloth Test" (camera photos and saved images are skipped), runs Apple's text recognition and then the model on
each, and lists thumbnail, type, title, date, amount, and time taken. The summary shows
counts per type, average times, retries, and accuracy. Use the menu on each row to mark it
correct, or wrong and what it should have been. Marks are saved to
`Documents/eval-report.json` and carried over to the next run.

## Architecture

```
SlothRoll/
  App/         SlothRollApp (entry), AppDependencies (composition root), RootView
  Features/    one folder per screen (View + @Observable @MainActor ViewModel)
    Debug/     (DEBUG only) EvalView, EvalRowView, EvalViewModel, EvalRow, EvalMark,
               EvalSummary, EvalReport, EvalReportStore, EvalConfig,
               PreviewVLM + PreviewPhotoLibrary (fakes for SwiftUI previews)
  Pipeline/    Extractor (VLM + parse + retry), ExtractionPrompt, ResultParser,
               ExtractionReport, Triage (Vision OCR) + TextScan,
               PhotoLibraryProviding + PhotoLibrary (PhotoKit) + LibraryImage,
               PipelineError, PipelineConfig
  Inference/   VLMService (actor), ModelCatalog, InferenceConfig, InferenceError,
               HubDownloader + TransformersTokenizer(Loader) (mlx-swift-lm adapters)
  Actions/     (empty) EventKit / Maps / expense performers
  Models/      ActionResult, ActionType, Currency, Confidence, VLMServing (protocol)
  Storage/     (empty) SwiftData models
  Shared/      Log (os.Logger categories), MemoryProbe, Duration+Seconds
  Resources/   Assets, Info.plist, SlothRoll.entitlements
SlothRollTests/
  ParserTests/     ResultParserTests
  PipelineTests/   ExtractorTests (scripted fake VLM), ExtractionPromptTests
  FeaturesTests/   EvalSummaryTests
```

Data flow for one screenshot:

`EvalView` → `EvalViewModel` → `PhotoLibrary` (loads the image) → `Triage` (OCR, timing
only) → `Extractor` → `ExtractionPrompt` + `VLMServing` / `VLMService` (MLX on the GPU) →
`ResultParser` → `ActionResult` (or the fallback) → row on screen + `eval-report.json`.

`AppDependencies.live` builds the one `VLMService` and hands it to the view model as a
`VLMServing`, so features never import Inference and tests swap in a fake.

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

Logs: Console.app, filter subsystem `SlothRoll`, category `eval` (per-image timings and the
run summary), `pipeline` (attempts, parse failures) or `inference`.

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
