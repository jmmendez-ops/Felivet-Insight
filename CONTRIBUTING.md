# Contributing to Feline Detector

Thanks for helping improve this project.

## Development Setup

1. Install Flutter (stable) and verify with `flutter doctor`.
2. Run `flutter pub get` in the project root.
3. Confirm static checks pass with `flutter analyze`.
4. Run tests with `flutter test`.

## Branching

- Use a feature branch per change.
- Branch naming examples:
  - `feature/add-camera-overlay`
  - `fix/android-permission-flow`
  - `chore/update-dependencies`

## Pull Request Checklist

- Code builds locally.
- `flutter analyze` passes.
- `flutter test` passes.
- PR description explains:
  - what changed
  - why it changed
  - how it was tested
- Include screenshots for UI changes.

## Commit Style

Use clear commit messages in imperative form.

Examples:
- `Add confidence threshold control`
- `Fix null handling in result parsing`
- `Refactor camera permission state`

## Reporting Issues

When opening an issue, include:
- expected behavior
- actual behavior
- reproduction steps
- Flutter version (`flutter --version`)
- target device and OS
