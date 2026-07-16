# dime_store_macro

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Safe Development Loop

Use this loop to ship changes with less breakage:

1. Create a feature branch.
2. Run the app with hot reload while making small changes.
3. Run analyze + tests before each commit.
4. Run full preflight before merge/release.

### VS Code Tasks

Open Command Palette and run `Tasks: Run Task`:

- `Flutter: Run App`
- `Flutter: Analyze`
- `Flutter: Test`
- `Flutter: Dev Check (analyze + test)`
- `Flutter: Preflight (clean + get + analyze + test + debug build)`

### Terminal Commands

Quick check:

```powershell
powershell -ExecutionPolicy Bypass -File tooling/dev_check.ps1
```

Full preflight:

```powershell
powershell -ExecutionPolicy Bypass -File tooling/preflight.ps1
```
