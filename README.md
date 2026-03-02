# SpeechMore

[中文](README_CN.md) | English

A lightweight macOS menu bar voice assistant powered by [StepFun](https://www.stepfun.com/) Realtime ASR and LLM APIs.

Hold a hotkey to start real-time speech recognition, AI Q&A, or translation. Release to stop. Results appear in a floating overlay at the bottom of the screen.

## Features

| Shortcut | Mode | Description |
|----------|------|-------------|
| Hold **Right ⌥ (Option)** | Voice Input | Real-time speech-to-text (ASR only) |
| Hold Right ⌥ → then press **Space** | Ask Anything | Voice question → AI answer (ASR + LLM) |
| Hold Right ⌥ → then press **Left Shift** | Translate | Voice translation to target language (ASR + LLM) |

- Holding Right Option immediately starts recording; press Space / Shift during recording to upgrade the mode
- Releasing Right Option stops recording
- Results are shown in a bottom overlay with a manual copy button

## Requirements

- macOS 13.0 (Ventura) or later
- Swift 5.9+
- [StepFun API Key](https://platform.stepfun.com/)

## Build & Install

```bash
# Clone the repo
git clone <repo-url>
cd speechmore

# Build and install to /Applications
bash build-app.sh

# Run
open /Applications/SpeechMore.app
```

On first launch, the app will prompt for Accessibility permission. Grant it in **System Settings → Privacy & Security → Accessibility**.

## Configuration

Click the **waveform icon** in the menu bar → **Open Main Window**:

1. Enter your StepFun API Key
2. Choose the translation target language (default: English)

Settings are persisted via UserDefaults.

## Project Structure

```
Sources/SpeechMore/
├── App/                # App entry point, AppDelegate
├── Audio/              # Microphone recording (AudioRecorder)
├── Core/               # AppState, Constants, Settings, LogStore
├── Features/           # FeatureCoordinator, FeatureMode, TextInjector
├── HotKey/             # Global hotkey monitoring (HotKeyManager)
├── Network/            # ASR WebSocket client, LLM HTTP client
└── UI/                 # Menu bar, main window, overlay (OverlayPanel/View)
```

## Tech Stack

- **Language**: Swift / SwiftUI
- **Build**: Swift Package Manager
- **ASR**: StepFun Realtime ASR (WebSocket streaming)
- **LLM**: StepFun Chat Completions (SSE streaming)
- **Audio**: AVFoundation (PCM 16-bit 16kHz)

## Main Window & Logs

The app provides a standalone main window (accessible from the menu bar popover → "Open Main Window") with:

- **Home Tab**: API Key settings, language selection, shortcut reference
- **Logs Tab**: Real-time runtime logs for debugging

## License

MIT
