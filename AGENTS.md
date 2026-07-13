# Straight — Project State & Recovery Plan

> Read this first. The repo is at ~40% completion. Do not skip verification steps.

## What this project is

Free, offline, private Windows dictation app. Hotkey → speak → text typed into the
active app. Flutter (Dart) desktop on Windows. Current stack: whisper.cpp
Whisper Base as the working STT, rules-based cleanup (+ optional small Qwen helper),
Hive local storage, `hotkey_manager`, `window_manager`, Win32 `SendInput` for
text injection, `record` package + energy VAD for audio.

Current model decision: use **Whisper Base** for STT. `Qwen3-ASR-0.6B` loads in
the isolated smoke test, but the current `qwen_asr.dll` is too slow for real-time
dictation (~60s for 1s fake audio) because it is not built with proper
acceleration. Do not make Qwen ASR the default until it is rebuilt and benchmarked.

## Actual directory structure (verified, not assumed)

```
lib/
  main.dart                                  # Hive + WindowManager bootstrap
  app.dart                                   # MaterialApp, theme, routes
  core/
    coordinator.dart                         # main brain (HOT)
    app_context.dart                         # `late final coordinator` global
    audio/
      vad.dart                               # energy-based PCM VAD (fixed sign bug)
    stt/
      stt_engine.dart                        # abstract SttEngine
      stt_pipeline.dart                      # AudioRecorder + VAD + engine + race-safe stop()
      whisper_engine.dart                    # FFI → whisper_wrapper.dll (PROVEN)
      qwen_asr_engine.dart                   # FFI → qwen_asr_wrapper.dll (loads, slow)
    llm/
      llm_engine.dart                        # abstract LlmEngine
      qwen_engine.dart                       # FFI → qwen_wrapper.dll (opt-in helper)
    pipeline/
      dictation_pipeline.dart                # rules pipeline + optional LLM pass
      command_parser.dart                    # "new line", "period", "scratch that"...
      style_cleaner.dart                     # spaces, I-capitalization
      filler_remover.dart                    # um/uh/like/you know
      capitalizer.dart
      punctuator.dart                        # pause-aware
      number_formatter.dart
      backtrack_handler.dart
      contraction_normalizer.dart
      word_replacer.dart                     # dictionary
    hotkey/
      hotkey_service.dart                    # alt+space, toggle/PTT modes
    injection/
      text_injector.dart                     # win32 SendInput (Unicode + VK_RETURN)
    storage/
      storage_service.dart                   # Hive box facade
      settings_store.dart                    # theme, hotkey, models, push-to-talk
      dictionary_store.dart
      history_store.dart
      snippets_store.dart                    # EXISTS in code but feature is NOT in plan
  features/
    bubble/
      bubble_overlay.dart                    # the main floating dictation UI
      bubble_controller.dart
      waveform_painter.dart
    settings/
      settings_page.dart
      model_selector.dart                    # tiny inline list — no separate model UI
      hotkey_capture_tile.dart
    dictionary/
      dictionary_page.dart
      add_word_dialog.dart
    history/
      history_page.dart
    onboarding/
      onboarding_page.dart
      permission_step.dart
      hotkey_step.dart
      mic_test_step.dart
      tutorial_step.dart
    snippets/                                # EXISTS but the plan says OUT OF SCOPE
      snippets_page.dart
      add_snippet_dialog.dart
  shared/
    theme/
      app_theme.dart
      colors.dart
    widgets/
      search_field.dart
      empty_state.dart
      app_drawer.dart

native/
  prebuilt/                                  # DLLs the app loads at runtime
    whisper.dll            (1.3 MB)          # whisper.cpp (PROVEN)
    whisper_wrapper.dll    (107 KB)
    qwen_asr.dll           (411 KB)          # antirez/qwen-asr (no OpenBLAS — slow)
    qwen_asr_wrapper.dll   (93 KB)
    qwen_wrapper.dll       (94 KB)           # llama.cpp-based LLM wrapper (opt-in)
    libqwen_asr_wrapper.dll
    libqwen_wrapper.dll
    ll*.dll                                 # llama.cpp runtime
    ggml*.dll
  qwen-asr/                                  # MISSING locally; needed for rebuild work
  qwen_asr_wrapper/                          # our C wrapper that loads qwen_asr.dll
  qwen_wrapper/                              # llama-based LLM wrapper
  whisper.cpp/                               # Local checkout of whisper.cpp
  llama.cpp/                                 # Local checkout of llama.cpp

models/
  qwen/
    Qwen3-ASR-0.6B/
      model.safetensors            (406 MB)  # CORRUPT — need ~1.74 GB
      config.json, tokenizer files, etc.

windows/                                     # Flutter Windows runner
build/                                       # Flutter build artifacts
```

## What's actually broken (verified)

1. **The end-to-end voice pipeline still needs user mic testing.** No one has spoken into this app
   and gotten text out.
2. **`qwen_asr.dll` is too slow for real-time dictation.** It loads and runs, but
   measured ~60s for 1s generated audio. Treat Qwen ASR as experimental until the
   upstream source is restored and the DLL is rebuilt with acceleration.
3. **The helper Qwen LLM is optional.** Do not load it by default; rules should
   carry the default experience.

## What's actually working (verified)

- `flutter analyze` — clean.
- `flutter test` — **85/85 passing**.
- Whisper Base native smoke test passes.
- Qwen ASR isolated smoke test loads and completes, but is too slow for real-time use.
- Storage layer (Hive boxes for settings/dictionary/history/snippets).
- Text inject (Win32 SendInput, Unicode + newlines).
- Pipeline (rules only) — fillers, contractions, commands, etc. are unit tested.
- Theme and core UI screens — settings, dictionary, history, onboarding render.

## Recovery plan (exact order)

This was scaffolded by Claude from outside-context. It is correct in shape but
has been **adjusted after reading the actual repo**. Follow in order. Do not skip.

### Step 1 — Verify the build
- Run `flutter analyze`. Fix the 7 warnings so the analyzer is clean.
- Run `flutter test` and confirm 83/83 pass.
- Do NOT build Windows yet; that is slow and not needed until step 5.

### Step 2 — Re-download the model files
Use `curl` (not `Invoke-WebRequest`, which chokes on large files). Use
`-C -` for resume. Verify sizes after.

```bash
# Qwen3-ASR safetensors (~1.74 GB)
curl -L -C - -o models/qwen/Qwen3-ASR-0.6B/model.safetensors \
  https://huggingface.co/Qwen/Qwen3-ASR-0.6B/resolve/main/model.safetensors

# Qwen2.5 0.5B Instruct GGUF (~390 MB)
curl -L -C - -o models/qwen/qwen2.5-0.5b-instruct-q4_k_m.gguf \
  https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf
```

Size check:
- `Get-Item models\qwen\Qwen3-ASR-0.6B\model.safetensors | Select Length`
- `Get-Item models\qwen\qwen2.5-0.5b-instruct-q4_k_m.gguf | Select Length`

### Step 3 — Test Whisper end-to-end BEFORE touching Qwen
The Whisper DLL is proven. `whisper_base` is the default STT.
**The default app data path the coordinator looks for is
`<AppData>\Straight\models\whisper\ggml-*.bin`, NOT `models/whisper/`.**
We need to either:
- Place the Whisper ggml model in `<AppData>\Straight\models\whisper`, or
- Tweak the coordinator's path resolver (preferred — easier to ship).

Plan: download a `ggml-base.bin` (~140 MB) into `models/whisper/` and add a
fallback in the coordinator to look in the dev-tree path first when the file
exists there. This way `flutter run` works without manual Hive file copying.

### Step 4 — Test Qwen DLL in isolation
Write a small Dart FFI test that:
1. Loads `qwen_asr_wrapper.dll` from `native/prebuilt/`.
2. Calls `qwen_asr_wrapper_init("models/qwen/Qwen3-ASR-0.6B")`.
3. Calls `qwen_asr_wrapper_transcribe` on a short generated 16 kHz float32 sine.
4. Confirms it returns a non-null char*.

If it crashes, fix it here before running the full app.

### Step 5 — Keep Whisper Base as active engine
Do **not** flip the default `sttModel` to Qwen ASR. Use Whisper Base for the
full pipeline: mic → VAD → Whisper Base → rules → optional helper → text inject.
Qwen ASR work is deferred until native acceleration is rebuilt and benchmarked.

### Step 6 — Bubble UI smoke test
- Window appears, dark theme.
- Alt+Space toggles, bubble red→idle.
- Text appears in the active app (Notepad, etc.) after toggling off.
- Status, history, dictionary, settings all reachable.
- Bubble returns to idle cleanly.

## What was fixed in this session (OpenCode recovery, July 2026)

### Code fixes
- **model_selector.dart** — Suppressed deprecated `RadioListTile` warnings
- **test/pipeline_test.dart** — Removed 5 unused `result` variables in command parser tests
- **coordinator.dart** — Added dev-tree path fallback (`models/whisper/`, `models/qwen/`) so
  `flutter run` works without copying models to `<AppData>/Straight/models/`
- **qwen_asr_engine.dart** — Fixed DLL loading path from bare `qwen_asr_wrapper.dll` to
  `native/prebuilt/qwen_asr_wrapper.dll` (matching how whisper and qwen_engine load)

### Model downloads (completed)
- `models/whisper/ggml-base.bin` — 141 MB (valid ggml format, magic verified)
- `models/qwen/Qwen3-ASR-0.6B/model.safetensors` — ~1.79 GB (valid safetensors format)
- `models/qwen/qwen2.5-0.5b-instruct-q4_k_m.gguf` — ~491 MB (valid GGUF format)

### Structural verification
- FFI C function signatures (`qwen_asr_wrapper_init`, `_transcribe`, `_set_prompt`,
  `_set_language`, `_free_string`) all confirmed to match Dart typedefs
- Whisper DLL signatures also confirmed matching
- Full pipeline flow verified: coordinator → stt_pipeline → engine → transcribe →
  dictation_pipeline → text_injector

## What still requires runtime testing
These cannot be verified from code analysis alone:
- **Step 3** — Run `flutter run`, whisper loads, speak, text appears in Notepad
- **Qwen ASR** — Rebuild native Qwen ASR with acceleration before full-app use
- **Step 6** — Bubble UI smoke test (dark theme, hotkey toggle, idle return)

- Alt+Space → bubble turns red → speak → Alt+Space → text in the other app.
- Commands ("new line", "period", "scratch that") work.
- Bubble returns to idle.
- Dictionary words are applied.
- History saves what was said.
- RAM under ~1.3 GB total.
- Bubble UI is intentional, minimal, dark.

## Hard "do not"s

- Do NOT run Qwen DLL before Step 3 and Step 4 both pass.
- Do NOT download models with `Invoke-WebRequest`.
- Do NOT add snippets/sync/mac/linux features.
- Do NOT load the helper Qwen LLM by default — opt-in only.
- Do NOT start a fresh folder — keep this repo.
- Do NOT make GUI changes that the user has not approved.
