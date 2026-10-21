# Sloth Roll

## Overview

Sloth Roll is an iOS app that reads your screenshots on-device with an open-weight
vision-language model (VLM) and turns them into actions: a calendar event, a Maps place,
or an in-app expense. You only swipe. Nothing leaves the phone except the one-time model
download.

## How it works

Today (day 1) the app is a model spike: one debug screen that proves a VLM runs on the
iPhone.

1. Tap **Load model**. The first time, the app downloads
   `mlx-community/Qwen3-VL-2B-Instruct-4bit` (~1.8 GB) from Hugging Face and shows
   progress. Later launches load it straight from disk with no network call.
2. Tap **Pick image** and choose a screenshot.
3. Tap **Describe**. The model writes one sentence about the screenshot and says whether it
   contains an event, a place, a receipt, or none.
4. The screen shows load time, inference time, peak memory (last run and since launch), and
   memory still available. The same numbers go to the system log.

**Unload model** frees the model so memory can be checked again.

## Architecture

```
SlothRoll/
  App/         SlothRollApp (entry), AppDependencies (composition root), RootView
  Features/    one folder per screen (View + @Observable @MainActor ViewModel)
    Debug/     SpikeView, SpikeViewModel, SpikeConfig  (temporary day-1 spike),
               PreviewVLM (DEBUG-only fake model for SwiftUI previews)
  Pipeline/    (empty) scan orchestration, triage, extraction, parsing
  Inference/   VLMService (actor), ModelCatalog, InferenceConfig, InferenceError,
               HubDownloader + TransformersTokenizer(Loader) (mlx-swift-lm adapters)
  Actions/     (empty) EventKit / Maps / expense performers
  Models/      VLMServing (protocol the features depend on)
  Storage/     (empty) SwiftData models
  Shared/      Log (os.Logger categories), MemoryProbe, Duration+Seconds
  Resources/   Assets, Info.plist, SlothRoll.entitlements
SlothRollTests/
  FeaturesTests/   SpikeViewModelTests (fake VLM, no MLX needed)
```

Data flow for the spike:

`SpikeView` → `SpikeViewModel` → `VLMServing` (protocol in Models) → `VLMService` (actor in
Inference) → mlx-swift-lm `VLMModelFactory` / `ChatSession` → MLX on the GPU.

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

Logs: Console.app, filter subsystem `SlothRoll`, category `spike` (metrics) or `inference`.

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
