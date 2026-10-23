# Xcode setup

First-time build on your own Mac and iPhone. The short version is in the
[README](../README.md#setup-quick-start).

## Requirements

- A Mac with **Xcode 27.1** or newer (iOS 27 SDK; the app targets **iOS 18.0+**).
- A **physical iPhone** (tested on an iPhone 17 Pro, 12 GB RAM; other models untested). MLX does not run in the Simulator: the app builds there and
  the unit tests run there, but scanning needs a real phone.
- About 2 GB free on the phone for the model, and Wi-Fi for the first launch.
- An Apple ID in Xcode (a free Personal Team works).

## Build from a clean clone

1. Clone and open the project (the generated `SlothRoll.xcodeproj` is committed; XcodeGen
   is not needed):
   `git clone <repo-url> && open slothRoll/SlothRoll.xcodeproj`
2. Install the Metal Toolchain once (MLX compiles Metal shaders):
   `xcodebuild -downloadComponent MetalToolchain`
3. Let Xcode resolve the Swift packages (automatic on open; File › Packages › Resolve
   Package Versions if it stalls). Versions are pinned in `Package.resolved`.
4. **Signing:** select the `SlothRoll` target › Signing & Capabilities. Keep "Automatically
   manage signing" on and pick your own Team (the committed team `HYZ2GHP9BH` only works on
   the author's account). If Xcode says the bundle ID is taken, change
   `com.martinespericueta.slothroll` to something unique (also in `project.yml` if you'll
   regenerate). The entitlement `com.apple.developer.kernel.increased-memory-limit` is
   added to the profile automatically.
5. On the iPhone: turn on Developer Mode (Settings › Privacy & Security › Developer Mode),
   connect it, pick it as the run destination, and press Run. On the first install with a
   free team, trust the developer: Settings › General › VPN & Device Management.
6. First launch: stay on Wi-Fi for the one-time model download (~1.8 GB) on the last
   onboarding screen. Allow **Full Access** to Photos when you tap **Scan**, and Calendars
   (add-only) on the first event swipe.

No API keys, accounts, or servers. The model files go to Application Support (iOS won't
purge them) and are excluded from iCloud backup.

Command-line build (no signing needed to check it compiles):
`xcodebuild -project SlothRoll.xcodeproj -scheme SlothRoll -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`
Tests: ⌘U in Xcode with an iPhone Simulator selected (102 unit tests), or
`xcodebuild -project SlothRoll.xcodeproj -scheme SlothRoll -destination 'platform=iOS Simulator,id=<simulator UDID>' test`
(use the UDID from `xcrun simctl list devices`; a `name=` destination can match a paired
phone of the same name and fail).

Version: 1.0 (build 1), set as `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in
`project.yml`. If `project.yml` changes: `brew install xcodegen && xcodegen generate`. The
accent color comes from `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor` in
`project.yml`; without it buttons fall back to system blue.
