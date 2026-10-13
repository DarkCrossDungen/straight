# Contributing to Straight 🎙️

Thank you for your interest in contributing to Straight! We are building a free, 100% offline, local-first alternative to Wispr Flow.

## Core Guidelines

1. **100% Local & Offline:** Never add cloud dependencies to the core desktop app. All processing must run locally on the user's machine.
2. **Reliability > Features:** Dictation tools must never crash or silently drop keystrokes.
3. **Simplicity:** Keep code modular and clean. Avoid unnecessary dependencies.

## Development Workflow

1. Fork and clone the repository:
   ```bash
   git clone https://github.com/<your-username>/straight.git
   cd straight
   ```
2. Install Flutter packages:
   ```bash
   flutter pub get
   ```
3. Run test suite:
   ```bash
   flutter test
   ```
4. Run locally on Windows:
   ```bash
   flutter run -d windows
   ```

## Adding Pipeline Steps

All text cleaning rules live in `lib/core/pipeline/`. If you add a new formatting step:
- Keep latency minimal (regex or string iteration).
- Add corresponding unit tests in `test/pipeline_test.dart`.
- Wire into `lib/core/pipeline/dictation_pipeline.dart`.

## Pull Requests

1. Create a branch: `git checkout -b feature/your-feature-name`.
2. Commit your changes with clear messages.
3. Verify that `flutter test` passes with 0 failures.
4. Submit a Pull Request targeting `main`.
