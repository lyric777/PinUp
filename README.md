# PinUp

[English](README.md) | [简体中文](README.zh-Hans.md)

PinUp keeps any macOS window visible above your workspace.

Pin a simulator, dictionary, video call, docs page, dashboard, or any small utility window, then keep working in another app without losing sight of it.

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

![Hover to interact](docs/media/hover-to-interact.gif)

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

![Permissions](docs/media/permissions.png)

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

## Media To Capture

Recommended assets:

- `docs/media/pin-next-to-editor.gif`: pin a simulator or utility window next to an editor, then keep editing.
- `docs/media/hover-to-interact.gif`: hover the pinned window, click or scroll it, then return to another app.
- `docs/media/follow-window.gif`: move or resize the original window and show PinUp following it.
- `docs/media/menu.png`: show the menu bar controls.
- `docs/media/permissions.png`: show the permissions onboarding screen.

Avoid recording private paths, real project names, tokens, personal messages, or sensitive code.

## Notes

PinUp does not use private APIs to modify other apps' window levels. It shows a live pinned preview and hands interaction back to the original window when you move your pointer over it.

Some system windows, protected content, and apps with unusual capture behavior may not preview correctly.
