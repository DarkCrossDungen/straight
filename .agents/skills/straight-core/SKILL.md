---
name: straight-core
description: >-
  Core reasoning rubric and operational guidelines for Dark's Straight offline dictation startup project. Use before every task, code change, or architecture decision in the Straight project.
---

# How to Reason Before Every Task

Before writing a single line of code, always do this:

### Step 1 — Understand the actual problem
Ask: What is Dark really trying to accomplish? Not just the literal request — the goal behind it.

### Step 2 — Map the blast radius
Ask: What else in the codebase does this touch? State which files will change and why.

### Step 3 — Spot the traps
Ask: What can go wrong? What assumptions am I making? Name at least one thing that could silently break.

### Step 4 — Pick the simplest path
Ask: Is there a way to do this with less code or fewer moving parts? Simpler is always better here. This is a vibe-coded project.

### Step 5 — Explain in plain English before coding
Tell Dark what you're about to do and why, in 3-5 sentences max. If he says "go" — then write the code.

---

## How to Explain Things
* Use plain English. No jargon unless unavoidable.
* If you must use a technical term, define it in one sentence immediately after.
* Use comparison tables for anything with multiple options or trade-offs.
* Keep explanations short but complete — every sentence must earn its place.
* When something is uncertain or untested, say so directly. Don't pretend.

---

## Startup Mindset (Always Active)
This is not just a coding project. It is a product with real users and a business model. Keep this in mind:
* **Reliability > features.** A thing that works beats a thing that almost works.
* **Polish matters for launch.** The README, installer, and first-run experience determine adoption.
* **The open source repo is the marketing channel.** Every file a developer sees is a first impression.
* **Paid tier = sync + auto-updates.** Don't build cloud features into the free tier.
* **Target audience:** Privacy-conscious developers, Windows power users, people who tried Wispr Flow and balked at the price.

---

## Priority Order (When Dark Asks "What Should I Do Next?")
1. Confirm end-to-end pipeline works (mic → STT → pipeline → inject in one shot)
2. Fix Qwen3-ASR model download (multi-file directory, not single file)
3. Wire snippets to voice trigger (lookup in CommandParser or new SnippetExpander step)
4. Add snippets to nav (route in app.dart + AppDrawer link)
5. Implement start on boot (HKCU registry write)
6. Fix waveform (hook audio amplitude into BubbleController)
7. Fix NumberFormatter direction (words→digits for most dictation use cases)
8. Rewrite README (real project description + install instructions)
9. Build CI installer (GitHub Actions → signed .exe via Inno Setup)

---

## File Map (Quick Reference)
| File | Role |
| :--- | :--- |
| `lib/core/coordinator.dart` | Main brain, orchestrates everything |
| `lib/core/audio/vad.dart` | Voice activity detection |
| `lib/core/stt/stt_pipeline.dart` | Mic capture + VAD + engine |
| `lib/core/stt/whisper_engine.dart` | Whisper FFI (proven) |
| `lib/core/stt/qwen_asr_engine.dart` | Qwen3-ASR FFI (untested) |
| `lib/core/pipeline/` | All 9 text processing steps |
| `lib/core/injection/text_injector.dart` | Win32 SendInput |
| `lib/core/hotkey/hotkey_service.dart` | Global hotkey |
| `lib/core/storage/` | Hive stores (settings, dict, history, snippets) |
| `lib/core/llm/` | Optional Qwen2.5 LLM pass |
| `lib/core/download/` | Model downloader |
| `lib/features/bubble/` | Main UI (floating bubble) |
| `lib/features/settings/` | Settings page |
| `lib/features/dictionary/` | Dictionary CRUD |
| `lib/features/history/` | History list |
| `lib/features/snippets/` | Snippets CRUD (not in nav yet) |
| `lib/features/onboarding/` | 4-step onboarding flow |
| `native/prebuilt/` | All prebuilt DLLs |

---

## Rules You Must Never Break
1. **Never assume the end-to-end pipeline works.** Treat it as unverified until proven.
2. **Never add cloud dependencies to the core app.** Everything local. Cloud is paid tier only.
3. **Never write code without explaining it first** unless Dark explicitly says "just do it."
4. **Never ignore a known bug when it's relevant to the task at hand.** Surface it.
5. **Always state which files you're changing before you change them.**
6. **When in doubt, do less.** A small working change beats a large broken one.
