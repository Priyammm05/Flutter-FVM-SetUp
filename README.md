# setup_flutter.sh

Full Flutter development environment setup for macOS. Installs everything needed for both Android and iOS development in one shot. Safe to re-run — skips anything already installed.

## Usage

```bash
# Default (Flutter 3.35.0)
bash setup_flutter.sh

# Specific Flutter version
bash setup_flutter.sh 3.35.4
```

## What gets installed

| Component | Details |
|---|---|
| Homebrew deps | `git`, `curl`, `unzip`, `wget`, `cocoapods` |
| Java 17 | Temurin via Homebrew — required for Android toolchain |
| Android Studio | + `ANDROID_HOME` and `platform-tools` added to PATH |
| CocoaPods | For iOS builds |
| FVM | Flutter Version Manager |
| Flutter | Version you specify (default `3.35.0`), set as FVM global |

Shell config written to `~/.zshrc` (or `~/.bashrc`):
- `JAVA_HOME`, `ANDROID_HOME`, PATH entries
- `flutter` aliased to `fvm flutter`
- `dart` aliased to `fvm dart`

## After the script finishes

```bash
# 1. Reload your shell
source ~/.zshrc

# 2. Open Android Studio → SDK Manager, install:
#    - Android SDK Platform (API 34+)
#    - Android SDK Build-Tools
#    - Android Emulator
#    - Android SDK Platform-Tools

# 3. Accept Android licenses
flutter doctor --android-licenses

# 4. Check overall setup
flutter doctor

# 5. Verify the alias works
flutter --version
```

## Requirements

- macOS only
- [Homebrew](https://brew.sh) must be installed before running
