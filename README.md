# Straight 🎙️

> **Free, 100% Offline, Local-First Voice Dictation for Windows.**  
> An open-source alternative to Wispr Flow. Zero cloud servers. Zero monthly subscriptions. Everything runs on your machine.

---

## ✨ Features

- **⚡ Instant Dictation at Cursor:** Press your global hotkey (`Alt + Space` or Push-to-Talk) from anywhere, speak, and watch clean text type directly into any active app (VS Code, Slack, Word, Chrome, Notepad).
- **🔒 100% Private & Local:** No audio ever leaves your computer. All speech recognition and formatting happen on your local CPU.
- **🌊 Live Audio-Reactive Waveform:** Floating minimal dark bubble that pulses and animates to the true volume of your voice.
- **🤫 Whisper Mode:** Adaptive gain and sensitive Voice Activity Detection for quiet dictation in libraries, offices, or shared rooms.
- **✂️ Voice Snippets:** Save repetitive text templates and expand them with spoken trigger phrases (e.g., saying *"my calendly"* inserts your full scheduling link).
- **📖 Custom Dictionary:** Teach the app teammate names, technical jargon, or acronyms for automatic phonetic replacement.
- **🧹 Rules-Based Post-Processing:**
  - Auto-removes filler sounds (*um, uh, like, you know*).
  - Normalizes contractions (*don't, can't, I'm*).
  - Formats spoken numbers and currency (*"twenty five"* $\to$ `25`, *"fifty dollars"* $\to$ `$50`, *"first"* $\to$ `1st`).
  - Recognizes spoken formatting commands (*"new line"*, *"new paragraph"*, *"scratch that"*).
  - Handles mid-sentence self-corrections (*"meet at five no six"* $\to$ *"meet at six"*).
- **📜 Local History Log:** Automatically logs past dictations locally for quick retrieval and review.
- **🚀 Start on Boot:** Launches seamlessly in the Windows system tray on startup.

---

## 🛠️ Architecture & Tech Stack

| Component | Technology |
| :--- | :--- |
| **Framework** | Flutter (Dart Desktop) |
| **STT Engines** | Whisper FFI (`whisper.cpp`) / Qwen3-ASR FFI |
| **Text Injection** | Windows Win32 API (`SendInput` Unicode) |
| **Audio & VAD** | 16 kHz PCM stream + Noise-proof Adaptive Voice Activity Detection |
| **Storage** | Hive local database |
| **Installer** | Inno Setup & GitHub Actions CI |

---

## 🚀 Getting Started

### 1. Download Pre-Built Release
Head over to the **[Releases](../../releases)** tab on GitHub and download `Straight-Setup.exe` or the portable zip. Run the installer and launch Straight.

### 2. Building From Source (Developers)

```bash
# Clone the repository
git clone https://github.com/DarkCrossDungen/straight.git
cd straight

# Fetch Flutter dependencies
flutter pub get

# Run unit tests
flutter test

# Run the desktop app
flutter run -d windows
```

---

## ⌨️ Default Shortcuts

* **Toggle Dictation:** `Alt + Space` (Press once to speak, press again to insert).
* **Push-to-Talk:** Can be enabled in **Settings $\to$ Behavior** (Hold to speak, release to insert).

---

## 📄 License

Distributed under the **MIT License**. See `LICENSE` for more information.
