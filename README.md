# PinUp

[English](README.md) | [简体中文](README.zh-Hans.md)

PinUp keeps any macOS window visible above your workspace.

Pin a simulator, dictionary, video call, docs page, dashboard, or any small utility window, then keep working in another app without losing sight of it.

## Download

[Download PinUp 1.0 for Apple Silicon](https://github.com/lyric777/PinUp/releases/download/v1.0.0/PinUp-1.0-macOS-arm64.zip)

Requires macOS 15 or later.

1. Download and unzip PinUp.
2. Move `PinUp.app` to Applications.
3. Open PinUp.
4. If macOS blocks the first launch, open System Settings > Privacy & Security and click Open Anyway.

PinUp is distributed directly through GitHub. macOS may ask you to confirm the first launch.

![PinUp demo](docs/media/pin-next-to-editor.gif)

## Highlights

- Pin the focused window with `Option + Command + P`
- Keep the pinned window visible above other apps
- Move your pointer over the pinned window to interact with the original app
- Keep the preview aligned as the original window moves or resizes
- Launch automatically when you log in
- Use English or Simplified Chinese
- Run quietly from the menu bar

## Examples

PinUp is useful when you want to:

- keep an Android Emulator beside your editor
- keep a dictionary or translator available while writing
- keep a reference page visible while switching between apps
- watch a build, dashboard, or video call without giving it the whole screen

## Usage

1. Launch PinUp.
2. Grant Accessibility and Screen Recording permissions.
3. Focus the window you want to pin.
4. Press `Option + Command + P`.
5. Move your pointer over the pinned window when you want to click, scroll, or type in it.
6. Press `Option + Command + U` to unpin.

You can also pin, unpin, open settings, switch language, and copy debug logs from the menu bar icon.

## Permissions

PinUp needs two macOS permissions:

- Accessibility: detect and focus the active window
- Screen Recording: capture the pinned window preview

After granting Screen Recording, macOS may require you to quit and reopen the app.

## Build From Source

Requirements:

- macOS 15+
- Xcode with the macOS SDK
- Apple Silicon Mac

Build:

```bash
xcodebuild -project PinUp.xcodeproj -scheme PinUp -configuration Debug -derivedDataPath .derivedData build
```

Run the debug app:

```bash
open .derivedData/Build/Products/Debug/PinUp.app
```

## Notes

PinUp does not use private APIs to modify other apps' window levels. It shows a live pinned preview and hands interaction back to the original window when you move your pointer over it.

Some system windows, protected content, and apps with unusual capture behavior may not preview correctly.
