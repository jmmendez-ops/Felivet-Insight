# 🐾 FeliVet Insight

**A fast, on-device AI first-read on common feline skin conditions  from a photo.**

## Overview

FeliVet Insight is a Flutter mobile app that helps cat owners get a quick, AI-assisted first look at common feline skin conditions using their phone's camera. An on-device YOLOv8 model scans a photo for signs of Scabies, Ringworm, and Flea Allergy, and a deterministic expert system combines visual evidence strength, disease-specific clinical risk, and reported symptoms into a clear **Stable / Moderate / High** urgency result with plain-language reasoning and a recommendation.

> ⚠️ **This is a triage aid, not a diagnosis.** Always consult a licensed veterinarian.


## Installation (Users)

There's currently no app store listing or standalone APK — the app runs by building the project and installing it directly to your phone through VS Code.

1. Install [VS Code](https://code.visualstudio.com/) and the [Flutter](https://docs.flutter.dev/get-started/install) + [Dart](https://docs.flutter.dev/get-started/install) extensions.
2. Download or clone this repository:
   ```bash
   git clone https://github.com/jmmendez-ops/feline-detector-public.git
   ```
3. Open the project folder in VS Code.
4. Connect your Android or iOS phone via USB and enable **USB debugging** (Android: Developer Options → USB Debugging).
5. In VS Code, select your connected phone as the run target (bottom-right device selector, or `flutter devices` in the terminal).
6. Press **Run** (or `F5`) to build and install the app directly onto your phone.
7. Grant camera/gallery permissions when prompted on first launch.

## Installation (Developers)

**Requirements**
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel)
- Dart ≥ 3.11.1 (bundled with Flutter)
- Android Studio / Xcode (for emulators) or a physical Android/iOS device
- Windows only: Developer Mode enabled (`start ms-settings:developers`) — required for plugin symlink support
- Trained YOLOv8 `.tflite` model + labels file (already bundled under `assets/`):
  - `assets/CatDisease.tflite`
  - `assets/labels.txt`

**Setup**

1. Clone the repo:
   ```bash
   git clone https://github.com/jmmendez-ops/feline-detector-public.git
   cd feline-detector-public
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. (Windows only) Enable Developer Mode if prompted:
   ```powershell
   start ms-settings:developers
   ```
4. Connect a device or start an emulator:
   ```bash
   flutter devices
   ```
5. Run the app:
   ```bash
   flutter run
   ```
6. Grant camera/gallery permissions when prompted on first launch.

## Contributor Expectations

- Fork the repo and work off a feature branch.
- Keep pull requests focused - one feature or fix per PR, with a clear description of what changed and why.
- Follow existing Dart/Flutter style conventions in the codebase; run `flutter analyze` before submitting.
- Test on at least one physical device or emulator before opening a PR.
- Open an issue first for larger changes (new detection classes, model swaps, UI overhauls) so the approach can be discussed.
- Be respectful and constructive in code review - this is a community health tool, and clarity matters more than cleverness.

## Known Issues

- **Limited training data** — the YOLOv8 model has only seen a relatively small, curated image set, so accuracy varies with lighting, fur color, and image quality.
- **Limited disease coverage** — only Scabies, Ringworm, and Flea Allergy are currently detectable; many other feline skin conditions aren't recognized and won't be flagged.
- **No differentiation between look-alike conditions** — visually similar conditions not in the training set may be misclassified as one of the three supported classes.
- **Single-image analysis only** — the model evaluates one photo at a time and doesn't track changes over time or across multiple angles.
- **No cloud fallback** — detection is fully on-device, so there's no server-side model to cross-check a low-confidence result.
- **Not a substitute for veterinary diagnosis** — results are meant purely for triage guidance, not confirmed medical findings.

## Features

- 📷 Camera or gallery photo capture
- 🧠 On-device YOLOv8 detection (no images leave the device)
- 🩺 Expert-system triage — confidence, evidence strength, and clinical risk evaluated independently, not conflated
- ✅ Symptom checklist (vomiting, lethargy, loss of appetite) that factors into urgency
- 🔍 Tap-to-enlarge photo on the result screen
- 🕘 Permanent analysis history — saved on-device, with per-entry and clear-all delete
- 🌗 Dark mode toggle
- 📱 Clean Material 3 UI

## Usage

1. Open the app and wait for the detection model to finish loading.
2. Tap **Camera** or **Gallery** to select a photo of your cat.
3. Check any systemic symptoms your cat is showing (optional).
4. Tap **ANALYZE HEALTH**.
5. Review the urgency level, diagnosis summary, and evidence breakdown. Tap the photo to enlarge it.
6. Open the ☰ menu (top-left) to toggle dark mode or view/delete your saved History.

## Disclaimer

FeliVet Insight is an AI-assisted screening tool for informational purposes only. It does not replace professional veterinary diagnosis or care.
