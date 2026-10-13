# Changelog

All notable changes to **Straight** will be documented in this file.

## [v0.1.0] - MVP Release

### Added
- **Core Voice Pipeline:** Full local speech-to-text pipeline powered by `whisper.cpp` FFI and Win32 `SendInput` Unicode injection.
- **Voice Snippets:** Voice-triggered text expansions (`SnippetExpander`), integrated with Hive storage and full CRUD interface.
- **Reverse NumberFormatter:** Converts spoken words into digits (`"twenty five"` $\to$ `25`, `"fifty dollars"` $\to$ `$50`, `"first"` $\to$ `1st`).
- **Noise-Proof VAD:** Adaptive noise floor tracking and zero-crossing rate filtering to reject keyboard clicks and ambient noise.
- **Audio-Reactive Waveform:** Real-time microphone amplitude streaming to the floating bubble UI overlay.
- **Whisper Mode:** High mic gain ($+2.5\times$) and sensitive VAD threshold for quiet dictation in public or quiet rooms.
- **Windows Start-on-Boot:** System registry manager to launch Straight automatically on computer startup.
- **Automated Cloud CI & Installer:** GitHub Actions workflow compiling `Straight-Setup.exe` via Inno Setup and portable `.zip` releases.
- **Unit Test Suite:** 84+ passing unit tests covering commands, fillers, numbers, snippets, and pipeline integration.
