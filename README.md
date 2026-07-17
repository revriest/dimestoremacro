# BareMacros

A bloat-free calorie and macro tracking app.

Track your daily protein, carbs, fat, and calories with a clean, focused interface. Search thousands of regional foods, scan barcodes, log your weight, and hit your goals without the noise.

## Features

- **Daily macro tracking** with visual progress indicators
- **Regional food database** covering 19+ countries
- **Barcode scanning** with OpenFoodFacts integration
- **USDA fallback** search for US foods
- **Custom meals library** with quick-access favorites
- **Weight tracking** with history chart
- **TDEE calculator** to estimate targets from your profile

## Getting Started

This is a Flutter project. To run it locally:

```bash
flutter pub get
flutter run
```

## Development Workflow

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
