# Sloth Roll

iOS app that reads screenshots on-device with open-weight vision models and turns them
into actions (calendar event, Maps place, in-app expense). The user only swipes.

## Stack
- Swift 6, SwiftUI, iOS 18+, Xcode project, Swift Package Manager only (no CocoaPods)
- MLX Swift via the mlx-swift-lm package (MLXVLM, MLXLMCommon), 4-bit models from mlx-community
- PhotoKit, Vision, EventKit, MapKit, SwiftData
- Test device: iPhone 17 Pro (12GB RAM). MLX does not run in the Simulator.

## Repo structure

SlothRoll/
  App/                 SlothRollApp.swift, AppDependencies.swift (wires services), RootView.swift
  Features/            one folder per screen; each owns its View + ViewModel
    Onboarding/        OnboardingView, ModelDownloadView, OnboardingViewModel
    Scan/              ScanView, CardStackView, CardView, EditSheet, ScanViewModel
    Expenses/          ExpenseListView, ExpensesViewModel
    Cleanup/           (bonus) CleanupView, CleanupViewModel
    Settings/          SettingsView
    Debug/             EvalView (#if DEBUG only)
  Pipeline/            ScanCoordinator, PhotoLibrary, Triage, Extractor,
                       ExtractionPrompt, ResultParser
  Inference/           VLMService (actor), ModelCatalog (model IDs + sizes in one place)
  Actions/             ActionPerformer protocol, EventAction, PlaceAction, ReceiptAction
  Models/              ActionResult, ActionType, Confidence, ActionOutcome (plain value types)
  Storage/             SwiftData @Model types (ScreenshotItem, Expense), Persistence setup
  Shared/              UI components (Toast, TypeBadge), extensions, Logger categories
  Resources/           Assets.xcassets, Localizable strings, Info.plist, entitlements
SlothRollTests/        mirrors the source folders (PipelineTests/, ParserTests/, ActionsTests/)

## Layer rules (dependencies point downward only)
1. Features -> Pipeline, Actions, Storage, Models, Shared
2. Pipeline -> Inference, Storage, Models
3. Actions -> Storage, Models
4. Inference -> Models only (knows nothing about Photos, UI, or storage)
5. Models and Shared import nothing from other app folders
- Views never call VLMService, PhotoKit, or EventKit directly; they go through a ViewModel.
- Services are protocols with one live implementation, injected via AppDependencies,
  so tests can swap in fakes. No singletons except AppDependencies itself.

## Code conventions
- One type per file; file name = type name. Files over ~250 lines get split.
- ViewModels are @Observable and @MainActor. Pipeline and Inference are actors or
  Sendable types; heavy work never runs on the main actor.
- async/await only (no Combine, no completion handlers in new code).
- Errors are typed enums per layer (InferenceError, PipelineError, ActionError);
  the UI shows user-facing messages, never raw errors.
- Logging via os.Logger, subsystem "SlothRoll", one category per folder. No print().
- No magic numbers: thresholds and limits live in a Config enum per layer.
- New public types get a one-line doc comment saying what they are for.

## Rules
- Everything runs on-device. No network calls except the one-time model download.
- Load one model at a time; unload before loading the next.
- Model output is untrusted: decode defensively, never crash on bad JSON.
- Expenses stay in-app only (no export in the MVP).
- Before finishing a task: build for a physical device, run the tests, fix all warnings
  you introduced, and confirm no file breaks the layer rules above.
- Don't create new top-level folders; ask first if something doesn't fit.

## End of every task (required)
1. Update README.md (create it on day 1 if missing, with sections: Overview, How it works,
   Architecture, Setup, Dev log):
   - "How it works": keep it current with what actually works today, in plain words.
   - "Architecture": update if folders, layers, or data flow changed.
   - "Setup": add any new manual step (permissions, entitlements, Info.plist keys).
   - "Dev log": add a dated entry: what was built, files added or changed, known issues.
2. Then reply in chat with a summary in this format:
   - What we did: 3-6 bullets
   - How it works: a short walkthrough of the flow you built, naming the key types/files
     and how they connect (enough for me to explain it to a judge)
   - Decisions and trade-offs: anything you chose or changed and why
   - Manual steps for me: things I must do in Xcode or on the device
   - Known issues / next up: what's shaky and what tomorrow should start with

## Git
- main is always buildable. One commit per day minimum: "dayN: <summary>".
- Don't commit model weights, DerivedData, or xcuserdata.

## Action types (MVP)
event -> EventKit, place -> Maps, receipt -> in-app expense list, none -> skip.
