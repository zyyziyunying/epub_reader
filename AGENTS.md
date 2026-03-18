# Repository Guidelines

## Project Structure & Module Organization
`lib/` uses a layered Flutter layout. Keep core business models in `lib/domain/`, persistence and database code in `lib/data/`, EPUB and file helpers in `lib/services/`, and UI state/screens in `lib/presentation/`. Shared routing, theme, and platform setup live in `lib/core/`; reusable logging and extensions live in `lib/common/`. App entry points are `lib/main.dart` and `lib/app.dart`. Tests live under `test/`, and implementation notes belong in `docs/`.

## Build, Test, and Development Commands
Use the standard Flutter workflow from the repo root:

```bash
flutter pub get
flutter run -d windows
flutter test
flutter test test/common/log/app_logger_test.dart
dart format lib test
```

`flutter run` can target any supported device. Prefer focused test commands before broader runs. Generated folders such as `build/`, `.dart_tool/`, and platform runner artifacts should not be edited by hand.

## Coding Style & Naming Conventions
Follow `analysis_options.yaml`, which includes `flutter_lints`. Use 2-space indentation and keep imports organized. Name files with `snake_case.dart`, types with `UpperCamelCase`, members with `lowerCamelCase`, and Riverpod providers with a `Provider` suffix, for example `libraryBooksProvider`. Place screen-specific widgets beside their screen under `lib/presentation/screens/.../widgets/`. Run `flutter analyze` manually when you need a full static check. Keep maintained source files under 700 lines when practical; if you touch an oversized file, add `//TODO 拆分`.

## Testing Guidelines
Use `flutter_test` for unit and widget tests. Name test files `*_test.dart` and mirror the production path when possible, for example `test/common/log/app_logger_test.dart` for `lib/common/log/`. Add focused tests for repository, service, and provider changes; include regression coverage for reader navigation and persistence behavior when those areas change.

## Commit & Pull Request Guidelines
Recent history uses short, imperative commit subjects, in either English or Chinese, such as `Fix chapter index not updating in bottom bar` or `重构阅读器为连续滚动模式`. Keep commits narrowly scoped. Pull requests should explain the user-visible change, list verification steps, link related issues, and include screenshots or recordings for `lib/presentation/` UI changes.

## Configuration Notes
Environment-specific values live in `.test.env` and `.production.env`. Do not commit secrets. If you change logging behavior, update `docs/logging_guide.md` alongside the code.
