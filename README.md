# Straight 🎙️

[![License: MIT](https://img.shields.io/badge/License-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2B%20(x64)-blue.svg)](https://github.com/DarkCrossDungen/straight)
[![Offline](https://img.shields.io/badge/100%25-Local%20%26%20Offline-success.svg)](https://github.com/DarkCrossDungen/straight)
[![Build Status](https://github.com/DarkCrossDungen/straight/actions/workflows/build-release.yml/badge.svg)](https://github.com/DarkCrossDungen/straight/actions)

> **Free, 100% Offline, Local-First Voice Dictation for Windows.**  
> An open-source alternative to Wispr Flow. Zero cloud servers. Zero subscriptions. No audio ever leaves your computer.

---

## ⚡ Why Straight? (Straight vs. Wispr Flow)

| Feature | Wispr Flow | Straight (This App) |
| :--- | :---: | :---: |
| **Price** | $20 / month ($240/yr) | **100% Free Forever** |
| **Privacy** | Audio streamed to cloud servers | **100% Local (Air-gapped ready)** |
| **Windows Support** | Limited / Closed Beta | **Windows-First Native (x64)** |
| **Source Code** | Closed Proprietary | **Open Source (MIT License)** |
| **Latency** | Network + cloud roundtrip | **Instant On-Device CPU Inference** |
| **Custom Vocabulary** | Cloud-synced | **Local Hive Database** |
| **Voice Snippets** | Paid tier only | **Built-in & Unlimited** |

---

## ✨ Key Features

- **🎯 Instant Text Injection:** Tap `Alt + Space` (or hold for Push-to-Talk) anywhere. Speak naturally, and your words appear instantly in whatever app has your cursor (VS Code, Slack, Word, Notepad, Chrome).
- **🌊 Live Audio-Reactive Waveform:** Floating dark-mode bubble that dynamically pulses and jumps to the actual volume of your voice.
- **🤫 Whisper Mode:** Sensitive VAD and $+2.5\times$ software audio gain for quiet speaking in offices, coffee shops, or libraries without waking anyone up.
- **✂️ Voice Snippets:** Spoken shortcuts expand into full text templates (e.g. saying *"my calendly"* inserts your full scheduling link).
- **📖 Custom Dictionary:** Teach the app teammate names, proprietary jargon, and technical acronyms for automatic correction.
- **🛡️ Noise-Proof VAD:** Adaptive noise-floor tracker and vocal zero-crossing rate filter prevent mechanical keyboard clicks and fan hum from triggering false recordings.
- **🧹 Rules-Based Clean-Up Pipeline:**
  - Removes filler sounds (*"um"*, *"uh"*, *"like"*, *"you know"*).
  - Normalizes contractions (*"dont"* $\to$ *"don't"*, *"im"* $\to$ *"I'm"*).
  - Formats numbers, currency, and dates (*"twenty five"* $\to$ `25`, *"fifty dollars"* $\to$ `$50`, *"first"* $\to$ `1st`).
  - Self-corrections & backtracking (*"meet at five no six"* $\to$ *"meet at six"*).
  - Spoken formatting commands (*"new line"*, *"new paragraph"*, *"scratch that"*).
- **🚀 Start on Boot:** Silent minimize-to-tray launch on Windows startup.

---

## 🗣️ Spoken Voice Commands

| Say This | What Happens |
| :--- | :--- |
| `"new line"` | Inserts a line break (`\n`) |
| `"new paragraph"` | Inserts two line breaks (`\n\n`) |
| `"period"` / `"comma"` | Inserts `.` or `,` |
| `"scratch that"` | Deletes the previous phrase |
| `"all caps"` | Capitalizes all letters |
| *`<snippet trigger>`* | Expands to full text block (e.g. *"my email"*) |

---

## 🛠️ Architecture

```
[ Microphone Input ]
         │
         ▼
[ Adaptive Noise-Proof VAD ] (Filters out fan hum & keyboard clicks)
         │
         ▼
[ Whisper / Qwen Speech Engine ] (Local C++ FFI — 100% on CPU)
         │
         ▼
[ Rules Clean-Up Pipeline ]
  ├─ Backtrack Handler ("no wait, actually...")
  ├─ Filler Word Remover ("um", "uh")
  ├─ Number & Currency Formatter ("fifty dollars" ➔ "$50")
  ├─ Spoken Command Parser ("new line", "scratch that")
  ├─ Dictionary Replacer (Custom jargon/names)
  ├─ Snippet Expander (Voice shortcuts)
  ├─ Auto-Punctuator & Capitalizer
  └─ Style Cleaner
         │
         ▼
[ Win32 Text Injection ] (Direct Unicode SendInput at cursor)
```

---

## 📥 Installation

### Download Pre-Built Binary
Download the latest `Straight-Setup.exe` installer or portable `.zip` from the **[Releases](../../releases)** page.

### Build from Source
```bash
# Clone the repository
git clone https://github.com/DarkCrossDungen/straight.git
cd straight

# Install Flutter dependencies
flutter pub get

# Run unit tests
flutter test

# Run desktop app
flutter run -d windows
```

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
