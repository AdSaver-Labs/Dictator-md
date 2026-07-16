<p align="center">
  <h1 align="center">Dictator-md</h1>
  <p align="center">
    <strong>Free, local, and private dictation for macOS.</strong><br>
    Open-source speech-to-text that runs entirely on your Mac. No cloud, no subscriptions.<br>
    Hold a key. Speak. Release. Your words appear at the cursor.
  </p>
  <p align="center">
    <a href="https://dictatormd.app/">Website</a> &bull;
    <a href="DOWNLOAD.md">Download</a> &bull;
    <a href="#quick-start">Quick Start</a> &bull;
    <a href="#windows-status">Windows Status</a> &bull;
    <a href="#features">Features</a> &bull;
    <a href="#privacy--safety">Privacy</a> &bull;
    <a href="#models">Models</a> &bull;
    <a href="#contributing">Contributing</a>
  </p>
  <p align="center">
    <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="macOS 14+">
    <img src="https://img.shields.io/badge/price-free-brightgreen" alt="Free">
    <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License">
    <img src="https://img.shields.io/badge/powered%20by-whisper.cpp-orange" alt="whisper.cpp">
    <img src="https://img.shields.io/badge/privacy-100%25%20local-purple" alt="100% Local">
  </p>
</p>

---

**Free. Local. Private. No cloud. No API keys. No subscriptions. No data leaves your Mac.**

Dictator-md is a **free, open-source macOS dictation app** -- a local alternative to [Willow Voice](https://www.heywillow.io/), [WisprFlow](https://wisprflow.com/), and Apple Dictation. It runs OpenAI's [Whisper](https://github.com/openai/whisper) speech recognition model entirely on your machine using [whisper.cpp](https://github.com/ggerganov/whisper.cpp) with Metal GPU acceleration. Your voice never leaves your computer.

## Download First

For direct download instructions, start here:

- [`DOWNLOAD.md`](DOWNLOAD.md)
- Latest GitHub Release: https://github.com/AdSaver-Labs/Dictator-md/releases/latest

Use `Dictator-md.dmg` for macOS and `Dictator-md-windows-preview.zip` for the current Windows preview.

## Windows Status

**Windows support is currently a developer prototype, not a finished dictation app.**

The working product today is the macOS app. The Windows scaffold exists so contributors/testers can validate native Windows pieces such as the tray app, global hotkey, active-window detection, and text insertion. It does **not yet** record microphone audio or run Whisper transcription on Windows. Pressing the prototype hotkey currently inserts a placeholder sentence.

For Windows prototype build and manual testing steps, see:

- [`apps/windows/README.md`](apps/windows/README.md)
- [`docs/WINDOWS_MANUAL_TESTING.md`](docs/WINDOWS_MANUAL_TESTING.md)

Do not send normal end users to the Windows build yet. It is for technical feedback and porting work only.

**Why Dictator-md?**
- Apple's built-in dictation sends audio to Apple servers and has limited accuracy for technical terms
- Commercial tools like Willow Voice and WisprFlow cost $8-15/month
- Dictator-md is **completely free**, runs **100% offline**, and is **optimized for developers** with 500+ technical terms built in

## Features

- **Push-to-talk OR toggle mode** -- hold a hotkey and release, OR press once to start and once to stop. Toggle mode is **carpal-tunnel friendly** for long dictations and anyone with RSI; it requires a configurable hold (default 1.5s) to prevent accidental activation.
- **Works in any app** -- Terminal, VS Code, Claude Code, Xcode, Slack, browsers, email -- anywhere you can type
- **Fast** -- sub-second transcription on Apple Silicon (Metal GPU). Optimized CPU path for Intel Macs.
- **100% private** -- all audio processing happens locally. Nothing is sent to any server, ever.
- **Developer-optimized** -- built-in vocabulary of 500+ technical terms biases Whisper toward correct recognition of API, JSON, Kubernetes, PostgreSQL, GraphQL, etc.
- **Smart grammar correction** -- auto-capitalizes sentences, fixes 100+ acronym/term casings (api->API, javascript->JavaScript), adds punctuation
- **Number word conversion** -- "two four six eight" becomes "2,468", "three hundred forty two" becomes "342"
- **Multiple Whisper models** -- Base (142 MB, fastest), Small (466 MB, balanced), Medium (1.5 GB, most accurate)
- **Configurable hotkey** -- right Option by default, rebind to any key
- **Sound feedback** -- subtle audio cues for recording start, stop, and completion
- **Polished native UI** -- SwiftUI menu bar app with sidebar settings, dark/light mode support
- **Open source** -- MIT licensed, no telemetry, no analytics

## Privacy & Safety

Dictator-md runs **100% locally**. Your audio never leaves your Mac. There is no server, no account, no telemetry, no tracking of any kind.

**Don't trust us — verify it yourself.** The entire app is ~2,500 lines of Swift. You can audit every network call in one command:

```bash
grep -rE "URLSession|http" DictatorMD/**/*.swift
# Matches:
# - ModelManager.swift (fetches Whisper models from HuggingFace when you click Download)
# - AppUpdater.swift (checks GitHub Releases and downloads the signed DMG when you click Update)
```

### What we don't do

- ❌ Send audio or transcriptions anywhere
- ❌ Track, analyze, or log anything
- ❌ Auto-install updates without your click, telemetry, or license-check
- ❌ Read your clipboard
- ❌ Load web fonts or external scripts
- ❌ Require an account or an internet connection

See the full [Privacy breakdown](https://dictatormd.app/privacy.html) and [SECURITY.md](SECURITY.md) for the threat model and disclosure policy.

## Install

### macOS

Download the latest `.dmg` from [Releases](https://github.com/AdSaver-Labs/Dictator-md/releases), open it, and drag Dictator-md to Applications.

Dictator-md checks GitHub Releases for newer versions. When an update is available, the sidebar status card shows an **Update** button; clicking it downloads the release DMG, verifies the SHA256 checksum when present, installs the new app, and relaunches.

> **Note: The app is not notarized by Apple.** macOS will block it on first launch. To open it on Mac:
> 1. Open Dictator-md -- macOS will show a warning that it can't verify the developer
> 2. Go to **System Settings > Privacy & Security**
> 3. Scroll down and click **Open Anyway** next to the Dictator-md message
> 4. Click **Open** in the confirmation dialog
>
> You only need to do this once. After that, the app opens normally.

### Windows Preview

Download `Dictator-md-windows-preview.zip` from [Releases](https://github.com/AdSaver-Labs/Dictator-md/releases), extract it, and run `Dictator-md.exe`.

The Windows build is currently a preview: tray app, hotkey registration, focused-window tracking, and text insertion are wired. Real microphone capture and local Whisper transcription are still being ported, so the Windows build is not yet equivalent to the macOS dictation app. If Right Alt is unavailable on a given Windows keyboard layout, the app falls back to F8 and then Ctrl+Alt+Space.

Or build from source:

```bash
# Create a DMG after building
./scripts/create-dmg.sh
# Output: build/Dictator-md.dmg
```

## Quick Start

### Prerequisites

```bash
xcode-select --install    # Xcode Command Line Tools
brew install cmake         # CMake (for building whisper.cpp)
```

### Build from Source

```bash
git clone --recurse-submodules https://github.com/AdSaver-Labs/Dictator-md.git
cd Dictator-md

# 1. Build whisper.cpp static library (~1 min)
./scripts/build-whisper.sh

# 2. Download a Whisper model
./scripts/download-model.sh small.en    # 466 MB -- recommended
# or: ./scripts/download-model.sh base.en   # 142 MB -- faster, good for Intel Macs

# 3. Build and launch
make run
```

### First Launch

1. **Microphone** -- macOS will prompt automatically. Click Allow.
2. **Accessibility** -- required for the global hotkey and text injection. The app will guide you to System Settings > Privacy & Security > Accessibility. Add Dictator-md and toggle it on.

Once both permissions are granted, you'll see a green "Ready" status in the menu bar dropdown.

## Usage

| Step | Action |
|------|--------|
| 1 | Look for the waveform icon in your menu bar |
| 2 | **Hold Right Option** (or your configured hotkey) |
| 3 | Speak naturally |
| 4 | **Release the key** -- text appears at your cursor |

### Menu Bar States

| Icon | State | Meaning |
|------|-------|---------|
| Waveform | Idle | Ready to dictate |
| Red mic | Recording | Listening to your voice |
| Brain | Processing | Whisper is transcribing |
| Cursor | Typing | Text is being injected |

### Settings

Click the menu bar icon > Settings to configure:

- **General** -- hotkey binding, grammar correction toggle, sound feedback, launch at login
- **Model** -- download and switch between Whisper models
- **Vocabulary** -- customize the developer vocabulary prompt for better recognition
- **Permissions** -- check and manage macOS permissions

## Models

### Recommended: Quantized Models (Q5)

Quantized models are 2-3x smaller and faster than full precision with near-identical accuracy. **Use these.**

| Model | File | Size | Speed* | Accuracy | Recommended for |
|-------|------|------|--------|----------|-----------------|
| Base Q5 | `ggml-base.en-q5_1.bin` | 57 MB | ~0.2s | Good | Quick notes, Intel Macs |
| **Small Q5** | **`ggml-small.en-q5_1.bin`** | **181 MB** | **~0.4s** | **Better** | **Daily coding use (default)** |
| Medium Q5 | `ggml-medium.en-q5_0.bin` | 515 MB | ~1.0s | Best | Maximum accuracy |

### Full Precision Models

| Model | File | Size | Speed* | Accuracy |
|-------|------|------|--------|----------|
| Base | `ggml-base.en.bin` | 142 MB | ~0.3s | Good |
| Small | `ggml-small.en.bin` | 466 MB | ~0.7s | Better |
| Medium | `ggml-medium.en.bin` | 1.5 GB | ~1.5s | Best |

### Voice Activity Detection (VAD)

Download the Silero VAD model (2 MB) to automatically trim silence from recordings before inference. This significantly speeds up transcription, especially for short push-to-talk clips with silence at the start/end.

*Speed measured for a 5-second audio clip on Apple Silicon with Metal GPU. Intel Macs use CPU-only and will be 2-3x slower.

Download models via the script or the Settings > Model tab:
```bash
./scripts/download-model.sh small.en-q5_1    # Recommended
./scripts/download-model.sh base.en-q5_1     # Fastest
./scripts/download-model.sh medium.en-q5_0   # Most accurate
```

Or download directly from the Settings > Model tab in the app.

## Grammar Correction

Dictator-md automatically cleans up Whisper's raw output with a local, rule-based corrector (<5ms overhead):

**Capitalization**
- First letter of every sentence
- Standalone "I", "I'm", "I'll", "I've"

**500+ Developer Term Corrections**
| Whisper says | Dictator-md outputs |
|-------------|------------------------|
| "create a rest api" | "Create a REST API." |
| "set up the ci cd pipeline" | "Set up the CI/CD pipeline." |
| "deploy to aws using docker" | "Deploy to AWS using Docker." |
| "the javascript sdk uses graphql" | "The JavaScript SDK uses GraphQL." |
| "configure postgresql and redis" | "Configure PostgreSQL and Redis." |

**Punctuation**
- Adds missing periods at end of sentences
- Removes accidental spaces before punctuation
- Normalizes whitespace

Toggle on/off in Settings > General > "Auto-correct grammar & formatting".

## How It Works

```
You hold a key and speak
         |
    [AVAudioEngine]         Captures mic audio at native sample rate
         |
    [AVAudioConverter]      Resamples to 16kHz mono Float32
         |
    [Silero VAD]            Trims silence from start/end (if VAD model downloaded)
         |
    [whisper.cpp]           Runs Whisper inference (Metal GPU or CPU)
         |                  Beam search (Apple Silicon) / Greedy (Intel)
         |                  Temperature fallback for low-confidence results
         |                  Hallucination suppression via regex
    [TextCorrector]         Fixes capitalization, acronyms, punctuation
         |
    [CGEvent]               Types text at cursor position in any app
         |
You see the text appear
```

### Architecture

```
HotkeyMonitor (CGEvent tap -- global push-to-talk key detection)
       |
DictationEngine (@Observable state machine)
  |-- AudioCapture      AVAudioEngine -> 16kHz mono Float32 buffer
  |-- WhisperBridge     C bridging header -> whisper_full() with beam search
  |-- TextCorrector     Rule-based grammar, casing, punctuation (<5ms)
  |-- TextInjector      CGEvent keyboardSetUnicodeString (works in any app)
  |-- SoundFeedback     NSSound system audio cues
```

whisper.cpp is compiled as a **static library** with Metal GPU acceleration (`GGML_METAL=ON`, `GGML_METAL_EMBED_LIBRARY=ON`) and linked via a C bridging header. No dynamic libraries, no runtime dependencies.

## Build Commands

```bash
make whisper    # Build whisper.cpp static library with Metal
make model      # Download default model (small.en, 466 MB)
make app        # Compile Swift sources and create .app bundle
make run        # Build + launch the app
make clean      # Remove build artifacts
```

### Create a DMG

```bash
./scripts/create-dmg.sh
# -> build/Dictator-md.dmg
```

### Xcode Development

```bash
brew install xcodegen
xcodegen generate        # Generate .xcodeproj from project.yml
open Dictator-md.xcodeproj
```

## Project Structure

```
Dictator-md/
  App/                        SwiftUI @main entry point, MenuBarExtra
  Engine/
    AudioCapture.swift         AVAudioEngine mic recording + resampling
    WhisperBridge.swift        Swift wrapper for whisper.cpp C API
    TextCorrector.swift        Rule-based grammar/casing/punctuation
    TextInjector.swift         CGEvent text typing at cursor
    DictationEngine.swift      State machine orchestrating everything
    ModelManager.swift         Model download + selection
    SoundFeedback.swift        Audio cue playback
  UI/
    MenuBarView.swift          Menu bar dropdown with status + controls
    SettingsView.swift         Sidebar settings with cards UI
    OnboardingView.swift       First-launch permission guide
  Utilities/
    HotkeyMonitor.swift        Global hotkey via CGEvent tap
    PermissionManager.swift    Mic + Accessibility permission checks
    Settings.swift             UserDefaults persistence
    LaunchAtLoginHelper.swift  SMAppService integration
whisper.cpp/                   Git submodule (ggerganov/whisper.cpp)
scripts/
  build-whisper.sh             Build static lib with Metal
  download-model.sh            Download models from Hugging Face
  create-dmg.sh                Package .app into .dmg installer
.github/workflows/
  ci.yml                       Build + test on push/PR
  release.yml                  DMG + GitHub Release on git tag
```

## CI/CD

| Workflow | Trigger | What it does |
|----------|---------|-------------|
| `ci.yml` | Push to `main`, PRs | Builds whisper.cpp, compiles app, uploads artifact |
| `release.yml` | Git tag `v*` | Builds app, creates DMG, publishes GitHub Release |

### Creating a Release

```bash
git tag v1.0.0
git push origin v1.0.0
# GitHub Actions builds the DMG and creates a Release automatically
```

## Contributing

Contributions are welcome! Here's how to get started:

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Build and test (`make whisper && make app && make run`)
4. Commit your changes
5. Open a Pull Request

### Ideas for Contributions

- Additional language support (currently English-only)
- Custom sound packs for audio feedback
- Clipboard mode (copy to clipboard instead of typing)
- Per-app vocabulary profiles
- Post-processing via local LLM for full grammar correction
- Apple Silicon optimizations and benchmarking
- Homebrew Cask formula

## Troubleshooting

**"Failed to create event tap"** -- Accessibility permission is not granted. Go to System Settings > Privacy & Security > Accessibility and add Dictator-md.

**No audio captured / empty transcription** -- Microphone permission is not granted, or the wrong input device is selected.

**Slow transcription on Intel Mac** -- Intel Macs use CPU-only inference (Metal GPU is disabled). Switch to the `base.en` model in Settings > Model for faster results.

**App crashes on launch** -- Make sure you built whisper.cpp first: `./scripts/build-whisper.sh`. If the model isn't downloaded, the app will show "No model found" in the menu bar.

**Text not appearing at cursor** -- Some sandboxed apps block CGEvent text injection. Try in a different app (Terminal, TextEdit) to verify it works.

## License

[MIT License](LICENSE)

## Third-Party Licenses

| Dependency | License | Usage |
|-----------|---------|-------|
| [whisper.cpp](https://github.com/ggerganov/whisper.cpp) | MIT | Speech recognition inference engine |
| [Whisper models](https://github.com/openai/whisper) (OpenAI) | MIT | Pre-trained speech recognition models |

All macOS frameworks used (AVFoundation, Metal, CoreGraphics, AppKit, etc.) are provided by Apple as part of the macOS SDK under the [Xcode license agreement](https://developer.apple.com/terms/).

## Acknowledgments

- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) by Georgi Gerganov -- the C/C++ port of Whisper that makes local real-time inference possible
- [Whisper](https://github.com/openai/whisper) by OpenAI -- the speech recognition model that powers everything
- Inspired by [Willow Voice](https://www.heywillow.io/) and [WisprFlow](https://wisprflow.com/)

---

<p align="center">
  Built with whisper.cpp + SwiftUI + Metal<br>
  <sub>Made by <a href="https://github.com/sam-pop">sam-pop</a></sub>
</p>
