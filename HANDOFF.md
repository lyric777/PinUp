# PinUp Handoff

## What This Project Is
`PinUp` is a native macOS menu bar app for keeping the currently focused window visible in a floating overlay.

Current product direction:
- Main workflow is `focus window -> press Option + Command + P -> pin`
- No crosshair / capture-mode primary UX
- Menu bar app, no Dock icon in normal app behavior
- Uses `ScreenCaptureKit + floating NSPanel`
- Target platform: `macOS 15+`, `Apple Silicon`, `Swift 6`, `SwiftUI`

## Current Repository State
- The repo contains a single Xcode app project: [PinUp.xcodeproj](/Users/katyxu.z/PinUp/PinUp.xcodeproj)
- Main source root: [PinUp](/Users/katyxu.z/PinUp/PinUp)
- Local build artifacts are ignored via [.gitignore](/Users/katyxu.z/PinUp/.gitignore)

Build status at handoff:
- `xcodebuild -project PinUp.xcodeproj -scheme PinUp -configuration Debug -derivedDataPath /Users/katyxu.z/PinUp/.derivedData build`
- Last known result: `BUILD SUCCEEDED`

## What Has Been Implemented
### App shell
- Menu bar app entry via SwiftUI `MenuBarExtra`
- `LSUIElement = true` in [Info.plist](/Users/katyxu.z/PinUp/PinUp/Info.plist)
- No normal Dock icon / no main app window
- Settings window and permissions onboarding window are available

### Permissions
- Accessibility permission checks
- Screen Recording permission checks
- Open System Settings helpers
- First-launch permissions onboarding window

Relevant files:
- [PermissionsManager.swift](/Users/katyxu.z/PinUp/PinUp/Permissions/PermissionsManager.swift)
- [PermissionsOnboardingView.swift](/Users/katyxu.z/PinUp/PinUp/AppShell/PermissionsOnboardingView.swift)

### Pin flow
- Global hotkeys:
  - `Option + Command + P` to pin
  - `Option + Command + U` to unpin
- Focused window resolution via Accessibility APIs
- Matching focused AX window to `CGWindowListCopyWindowInfo`
- `ScreenCaptureKit` stream setup for the matched window
- Single floating `NSPanel` overlay with SwiftUI content
- Single active pin session only

Relevant files:
- [PinUpAppState.swift](/Users/katyxu.z/PinUp/PinUp/State/PinUpAppState.swift)
- [FocusedWindowResolver.swift](/Users/katyxu.z/PinUp/PinUp/FocusedWindow/FocusedWindowResolver.swift)
- [WindowMatcher.swift](/Users/katyxu.z/PinUp/PinUp/FocusedWindow/WindowMatcher.swift)
- [CaptureService.swift](/Users/katyxu.z/PinUp/PinUp/Capture/CaptureService.swift)
- [OverlayPanelController.swift](/Users/katyxu.z/PinUp/PinUp/Overlay/OverlayPanelController.swift)

### UX/status improvements already added
- Pin flow now exposes explicit states instead of instantly pretending success
- Overlay status progression:
  - `Preparing preview…`
  - `Connecting to <app>…`
  - only after first frame arrives: success / pinned
- If no frame arrives within 2 seconds:
  - app stops capture
  - overlay shows `Preview unavailable for this window`
  - menu state becomes action-needed instead of fake success
- Menu bar menu shows current status text and target info

Relevant files:
- [PinSessionState.swift](/Users/katyxu.z/PinUp/PinUp/State/PinSessionState.swift)
- [PinnedOverlayView.swift](/Users/katyxu.z/PinUp/PinUp/Overlay/PinnedOverlayView.swift)
- [MenuBarContentView.swift](/Users/katyxu.z/PinUp/PinUp/MenuBar/MenuBarContentView.swift)

## What Has Been Manually Observed
These observations came from interactive debugging, not automated tests:

- App can launch from Xcode and run as a menu bar app
- Permissions onboarding appears
- Screen Recording flow on macOS prompts for restart/relaunch as expected
- Pinning Android Emulator reached the overlay stage
- The overlay showed the matched target name correctly
- Before the latest UX fix, Android Emulator could reach a black overlay state with `Live` shown too early

## Known Product / UX Notes
- Menu bar apps can appear confusing on multi-monitor setups because the icon may be easiest to spot on a different display's menu bar
- The no-Dock-icon behavior is correct for product intent, but it makes debugging and discoverability harder
- Current UX is better than before, but there is still no polished toast/banner success feedback beyond menu + overlay state

## Known Technical Gaps
### 1. Android Emulator compatibility is not solved yet
This is the biggest known issue.

Observed behavior:
- The focused window can be resolved and matched
- Overlay can open with the correct title
- `ScreenCaptureKit` capture may still fail to produce usable frames for Android Emulator

Possible causes to investigate next:
- Window matching lands on the wrong `CGWindowID`
- `SCShareableContent` exposes a different window than the one AX resolves
- The selected emulator window is capturable in theory but produces blank frames
- The capture configuration needs adjustment for special windows

### 2. No automated tests yet
- There are no XCTest targets
- State-machine logic, permission-state mapping, and matcher heuristics are untested

### 3. Settings are intentionally minimal
- No launch-at-login implementation
- No opacity / click-through / remember session / docking presets

### 4. No recent windows / browse-all-windows UI
- This was intentionally deferred from MVP

## Recommended Next Steps
### Highest priority
1. Debug Android Emulator capture specifically
2. Verify whether normal apps like `Terminal`, `Safari`, or `Chrome` render correctly after the first-frame UX changes
3. If standard apps work and Emulator does not, isolate Emulator-specific window/capture behavior

### After that
1. Add lightweight logging around:
   - resolved AX window title/frame
   - chosen `CGWindowID`
   - `SCShareableContent.windows` candidates for the same PID
   - whether any sample buffers actually arrive
2. Add a small debug surface in the menu or settings to inspect current target metadata
3. Add unit tests for:
   - `PermissionState`
   - `PinSessionState`
   - `WindowMatcher` scoring behavior
4. Consider a debug-only mode that temporarily shows a Dock icon if debugging becomes painful

## Suggested Manual Validation Flow
When picking this project up in a new thread, test in this order:

1. Open [PinUp.xcodeproj](/Users/katyxu.z/PinUp/PinUp.xcodeproj) in Xcode
2. Run scheme `PinUp` on `My Mac`
3. Grant `Accessibility`
4. Grant `Screen Recording`
5. Stop and rerun the app after permission changes
6. Test `Terminal` first:
   - focus Terminal
   - press `Option + Command + P`
   - confirm overlay moves from `Preparing` -> `Connecting` -> actual frames
7. Test `Option + Command + U`
8. Then test Android Emulator

## Important Files To Read First
- [PinUpAppState.swift](/Users/katyxu.z/PinUp/PinUp/State/PinUpAppState.swift)
- [CaptureService.swift](/Users/katyxu.z/PinUp/PinUp/Capture/CaptureService.swift)
- [FocusedWindowResolver.swift](/Users/katyxu.z/PinUp/PinUp/FocusedWindow/FocusedWindowResolver.swift)
- [WindowMatcher.swift](/Users/katyxu.z/PinUp/PinUp/FocusedWindow/WindowMatcher.swift)
- [OverlayPanelController.swift](/Users/katyxu.z/PinUp/PinUp/Overlay/OverlayPanelController.swift)
- [PinnedOverlayView.swift](/Users/katyxu.z/PinUp/PinUp/Overlay/PinnedOverlayView.swift)

## Short Summary For The Next Thread
The MVP app skeleton is in place and builds successfully. The main remaining challenge is not project setup anymore; it is capture reliability, especially for Android Emulator. UX has already been improved so that pinning now clearly distinguishes `preparing`, `connecting`, `pinned`, and `preview unavailable` instead of showing a misleading black-screen success state.
