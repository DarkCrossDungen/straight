# Project Plan: Offline Voice Dictation App

> A free, private, offline voice dictation app like Wispr Flow / Glaido
> 100% local — no cloud, no subscriptions, no data leaves your device

---

## Core Principles

- 100% offline, no data leaves device
- Completely free, no paid tiers, no word caps
- Open-source (MIT/Apache 2.0)
- Cross-platform (Windows, macOS, Linux, Android, iOS)
- Dark-mode minimalistic UI
- Must match or beat Wispr Flow output quality

---

## Research Completed

### Wispr Flow
- $81M funding, founded 2021 by ex-Apple/Meta engineers
- Architecture: distilled Whisper local + cloud LLM correction + personalization from first 2K words
- Pricing: $20/mo Pro, 14-day free trial
- Features: auto-editing, dictionary, snippets, styles, command mode, whisper mode, 100+ languages, team features
- Floating bubble UI (dark overlay, waveform, text injection at cursor)

### Glaido
- Pricing: free 2K words/week, $20/mo Pro

---

## STT Model: Qwen3-ASR

### Primary: Qwen3-ASR-0.6B (via antirez/qwen-asr)

| Metric | Value |
|--------|-------|
| Params | 600M (0.6B) |
| Inference Engine | `antirez/qwen-asr` — pure C by Redis creator |
| Dependencies | C stdlib + BLAS (Accelerate/OpenBLAS) only |
| Peak RAM (INT4) | ~1.0 GB |
| Disk (INT4) | ~350 MB |
| Accuracy (LibriSpeech clean) | 1.74% WER (5-bit) |
| Latency (TTFT) | ~92 ms |
| Speed (CPU RTFx) | 10-40x real-time |
| Languages | 52 languages, 22 Chinese dialects |
| Accent Robustness | Excellent — 16 English accent groups tested |
| Noise Robustness | Excellent — low SNR tested in paper |
| Streaming | 2-second chunks with prefix rollback |
| Prompt Biasing | Yes (`--prompt` flag for domain terms) |
| License | Apache 2.0 (weights), MIT (inference engine) |

### Desktop Upgrade: Qwen3-ASR-1.7B
- ~1.9 GB RAM (5-bit), 1.32% WER, 4-15x RTF on CPU

### Fallback: Whisper tiny
- For languages outside Qwen's 52 coverage
- ~273 MB RAM, ~5.5% WER, via whisper.cpp

---

## Model Comparison (All Metrics)

| Metric | Qwen3-ASR-0.6B | Qwen3-ASR-1.7B | Whisper tiny | Whisper base | Whisper small | Whisper medium | Whisper large-v3 |
|--------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| Params | 600M | 1.7B | 39M | 74M | 244M | 769M | 1.55B |
| WER (LibriSpeech clean) | **1.74%** | **1.32%** | ~5.5% | ~4.5% | ~3.4% | ~2.8% | ~2.0% |
| WER (Open ASR Leaderboard avg) | ~6.0% | **5.76%** | ~12% | ~10% | ~8.5% | ~7.8% | ~7.4% |
| Peak RAM (quantized) | **~1.0 GB** | ~1.9 GB | **~273 MB** | ~388 MB | ~852 MB | ~2.1 GB | ~3.9 GB |
| Disk (quantized) | ~350 MB | ~1.7 GB | **75 MB** | 142 MB | 466 MB | 1.5 GB | 2.9 GB |
| TTFT | **~92 ms** | ~150 ms | ~300 ms | ~350 ms | ~500 ms | ~800 ms | ~1-2 s |
| RTFx (CPU) | 10-40x | 4-15x | ~10x | ~8x | ~2x | ~1x | ~0.5x |
| Languages | 52 | 52 | **99** | **99** | **99** | **99** | **99** |
| Chinese dialects | **22** | **22** | None | None | None | None | None |
| Accent robustness | **Excellent** | **Excellent** | Poor | Poor | Decent | Decent | Good |
| Noise robustness | **Excellent** | **Excellent** | Poor | Poor | Decent | Decent | Good |
| Prompt biasing | ✅ Yes | ✅ Yes | ❌ No | ❌ No | ❌ No | ❌ No | ❌ No |
| Streaming | ✅ 2s chunks | ✅ 2s chunks | ✅ | ✅ | ✅ | ✅ | ✅ |
| License (weights) | Apache 2.0 | Apache 2.0 | MIT | MIT | MIT | MIT | MIT |
| License (engine) | MIT | MIT | MIT | MIT | MIT | MIT | MIT |
| Dependencies | **C stdlib + BLAS** | **C stdlib + BLAS** | C++17 + BLAS | same | same | same | same |

---

## Post-Processing Architecture

- **~70% rules-based** (regex/code): filler removal, capitalization, punctuation, backtrack, dictation commands, contractions, number formatting
- **~30% optional LLM** (future): Phi-4 Mini 3.8B (MIT license) for advanced AI cleanup — deferred to v3

### Candidate LLM for Cleanup Layer
- **Phi-4 Mini 3.8B** (MIT license, ~3GB Q4)
- Beats Phi-3 Mini: newer (2026), synthetic data from frontier models
- Matches 8B-class models on MMLU (~73%)
- Only 0.6GB more RAM than Phi-3 Mini

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| App Framework | **Flutter** (Dart) |
| STT Engine | **antirez/qwen-asr** (pure C) |
| Fallback STT | **whisper.cpp** (C++) |
| Post-Processing (rules) | **Dart native** (regex + string processing) |
| Post-Processing (LLM) | **Phi-4 Mini 3.8B** via llama.cpp (future) |
| UI Style | Dark mode, minimalistic, floating overlay |

---

## Target Platforms (Build Order)

1. **Windows** — MVP
2. **macOS** — v2
3. **Linux** — v2
4. **Android** — v2
5. **iOS** — v2

---

## App UI Sections (Left Sidebar Navigation)

### 1. Floating Dictation Bubble
- Dark pill/circle overlay on top of all apps
- Shows waveform animation when listening
- Shows idle state when not active
- Auto-injects text at cursor position
- Triggered by global hotkey

### 2. Dictionary
- List of learned words
- Add new words manually
- Star/favorite important words (higher priority)
- Import from CSV
- Auto-learned words marked with ✨ sparkle icon
- Sync across devices

### 3. Snippets
- Create voice shortcuts
- Trigger phrase → full formatted text block
- Examples: "signed" → email signature, "calendar" → scheduling link

### 4. History
- Last 2000 words of dictation
- Organized/scrollable
- Searchable

### 5. Settings
- Language selection
- Hotkey configuration
- Model selection (0.6B / 1.7B)
- Auto-add to dictionary toggle
- Whisper mode toggle
- Other preferences

---

## Full Feature Set

### Core Dictation
- [x] Microphone capture + streaming
- [x] Voice Activity Detection (VAD) — auto pause on silence
- [x] Qwen3-ASR-0.6B streaming transcription (2s chunks)
- [x] Qwen3-ASR-1.7B desktop upgrade option
- [x] Whisper tiny fallback (extra languages)
- [x] Language auto-detect + manual override
- [x] Global hotkey to start/stop
- [x] Floating bubble UI (dark, waveform, idle)
- [x] Text injection at cursor position
- [x] Copy to clipboard

### Auto-Editing
- [x] Filler word removal (um, uh, like, you know, etc.)
- [x] Auto-capitalization (first letter of sentences)
- [x] Auto-punctuation (period from pauses)

### Post-Processing
- [x] Contraction normalization (don't, I'm, can't)
- [x] Number formatting (123 → "one hundred twenty three")
- [x] Backtrack handling (mid-sentence self-corrections)
- [x] Dictation commands: scratch/delete, new line, paragraph, select all, copy, paste, cap
- [x] Custom dictionary (names, technical terms, jargon)
- [x] Personalization (learns vocabulary over time, without latency hit)

### Dictionary
- [x] Manual add words
- [x] Star favorites
- [x] Import CSV
- [x] Auto-learn from corrections (✨ marker)
- [x] Cross-device sync

### History
- [x] Last 2000 words of dictation
- [x] Organized/scrollable
- [x] Searchable

### Additional Features
- [x] Whisper mode (quiet dictation)
- [x] Snippets (voice shortcuts)

---

## Still Needed to Complete Plan

- [ ] **Flutter + C integration approach** — how antirez C engine connects to Flutter (dart:ffi, platform channels, or Rust bridge)
- [ ] **Directory structure** — folder layout for the project
- [ ] **Implementation phases** — step-by-step build order with time estimates
- [ ] **State management** — Flutter state management choice (Riverpod, Bloc, Provider, etc.)
- [ ] **Audio pipeline details** — how to capture mic audio in Flutter, pass to C engine, handle real-time streaming
- [ ] **Keyboard/text injection API** — platform-specific code for injecting text into active fields (Windows SendInput, macOS Accessibility API, etc.)
- [ ] **Global hotkey implementation** — platform-specific global hotkey registration
- [ ] **Data storage** — how dictionary, snippets, history, settings are stored locally (SQLite, Hive, etc.)
- [ ] **Sync mechanism** — cross-device sync for dictionary/snippets/settings (if offline-only, maybe manual export/import)

---

## References

- Qwen3-ASR paper: https://arxiv.org/abs/2601.21337
- antirez/qwen-asr: https://github.com/antirez/qwen-asr
- Qwen3-ASR official: https://github.com/QwenLM/Qwen3-ASR
- Whisper.cpp: https://github.com/ggml-org/whisper.cpp
- Phi-4 Mini: https://huggingface.co/microsoft/Phi-4-mini-instruct
- Open ASR Leaderboard: https://huggingface.co/spaces/hf-audio/open_asr_leaderboard
- Soniqo ASR Benchmarks: https://soniqo.audio/benchmarks
- Wispr Flow: https://wisprflow.ai
