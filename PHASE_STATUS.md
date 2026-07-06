# STRAIGHT — Phase Status & Deviation Log

> Password: STRAIGHT
> Windows-first MVP

---

## Summary

This document tracks what has been completed, what deviated from the original plan, and why those deviations were necessary.

---

## Phase Completion Status

### Phase 1: Scaffold — Flutter project, deps, theme, directory structure
- **Status:** ✅ DONE (before this session)
- **What was done:**
  - Flutter project scaffolded
  - Dependencies added: flutter_riverpod, hive, hive_flutter, record, hotkey_manager, win32, path_provider, window_manager, system_tray, http, cupertino_icons
  - Directory structure created (lib/core/, lib/features/, lib/shared/, native/, assets/, test/)
  - Theme files (dark/light), colors (#6C63FF), basic widgets
  - main.dart with Hive init, window manager (minimize-to-tray on close)

### Phase 2: Native C — Build whisper.cpp DLL, FFI bindings
- **Status:** 🔄 IN PROGRESS
- **What was done before this session:**
  - whisper.cpp cloned and compiled to `native/prebuilt/whisper.dll`
  - Dart FFI bindings started in `lib/core/stt/whisper_engine.dart`
  - `stt_engine.dart` abstract interface defined
- **What was found during this session:**
  - The FFI bindings in `whisper_engine.dart` are BROKEN — they will crash at runtime
  - Reason: C function `whisper_full()` takes `struct whisper_full_params` BY VALUE, but Dart code passes a `Pointer<Void>` (pointer) to it
  - When Dart passes a Pointer as a value argument, the C function receives an 8-byte address instead of the ~500-byte struct, causing undefined behavior / crash
- **What is needed to complete Phase 2:**
  - Create a thin C wrapper that exposes pointer-based signatures for Dart FFI
  - Update `whisper_engine.dart` to use the wrapper DLL
  - Fix llama.cpp clone (directory exists but files not checked out — needs re-clone)

---

## Deviation: C Wrapper for whisper.cpp FFI

### Why a wrapper was added (deviation from original plan)

The original plan assumed direct FFI bindings to `whisper.dll`. This approach works for simple functions but FAILS for `whisper_full()` because:

1. `whisper_full()` takes a large struct (`whisper_full_params`) **by value** on the stack
2. Dart FFI cannot reliably pass large structs by value directly — it must define the entire struct layout (all 30+ fields, enums, function pointers, bools) in Dart
3. This struct is complex: nested enums, function pointers, bools with padding, string pointers. Defining it in Dart is error-prone and fragile.
4. One wrong field offset = silent corruption or crash.

### The wrapper solution

A thin C wrapper DLL (`whisper_wrapper.dll`) that links against `whisper.dll` and re-exports functions with pointer-based signatures that Dart FFI handles natively.

**What the wrapper does:**
- Accepts `whisper_full_params*` (pointer) instead of `whisper_full_params` (by value)
- Dereferences the pointer inside C and calls the real `whisper_full()` with correct by-value semantics
- No logic changes — just ABI adaptation

**Files added for wrapper:**
```
native/whisper_wrapper/
  whisper_wrapper.c    # ~50 lines — dereference + call real function
  CMakeLists.txt       # Build: link against whisper.dll, output whisper_wrapper.dll
```

**Files modified:**
- `lib/core/stt/whisper_engine.dart` — load `whisper_wrapper.dll`, use pointer-based signatures
- `native/build.sh` — add wrapper build step
- `pubspec.yaml` — add `ffi` dependency (was imported but not in deps)

### Why this is the correct choice

| Approach | Lines of Code | Fragility | Future-proof |
|----------|---------------|-----------|------------|
| Dart struct definition | ~150 lines | High (one offset wrong = crash) | Breaks if whisper.cpp changes struct |
| C wrapper (chosen) | ~50 lines C | Low (compiler handles layout) | Survives struct changes if API stays same |
| Direct FFI (original plan) | N/A | **Broken** | N/A |

The wrapper is a standard FFI pattern. Node.js, Python, Java — all use thin C wrappers for this exact reason when dealing with by-value structs.

**Impact on overall plan:** ZERO. Phase 3+ are unaffected. No directory restructure. No new dependencies. Just one extra DLL.

---

## Remaining Work to Complete Phase 2

1. Create `native/whisper_wrapper/` with wrapper C code + CMakeLists.txt
2. Build `whisper_wrapper.dll` (links against `whisper.dll`)
3. Update `whisper_engine.dart` with correct FFI signatures for wrapper
4. Add `ffi: ^2.1.3` to `pubspec.yaml` dependencies
5. Re-clone llama.cpp (current clone is broken — only `.git` folder exists)

---

## What Has Been Completed During THIS Session

1. ✅ Full project directory explored and understood
2. ✅ `whisper.dll` verified to have correct exports (`whisper_init_from_file`, `whisper_free`, `whisper_full_default_params_by_ref`, `whisper_full`, `whisper_full_n_segments`, `whisper_full_get_segment_text`)
3. ✅ llama.cpp clone verified as broken (only `.git/` exists, no files checked out)
4. ✅ Root cause of `whisper_engine.dart` bug identified: struct-by-value vs pointer mismatch
5. ✅ Solution designed: C wrapper for proper FFI ABI compliance

---

## Next Actions (Pending User Confirmation)

To proceed with the wrapper approach and complete Phase 2, the user should confirm.

Confirmation command: proceed with Option 2 (C wrapper)

---

*Document updated: 2026-07-05*
