#!/usr/bin/env bash
# =============================================================================
# setup_flutter.sh
# Full Flutter development environment setup for macOS.
#
# Installs:
#   - Homebrew dependencies (git, curl, unzip, wget, cocoapods, rbenv)
#   - Java 17 (Temurin via Homebrew) — required for Android toolchain
#   - Android Studio + Android SDK command-line tools
#   - FVM (Flutter Version Manager)
#   - Flutter (default: 3.35.0)
#
# Shell config written to ~/.zshrc (or ~/.bashrc):
#   - JAVA_HOME, ANDROID_HOME, PATH entries
#   - alias flutter="fvm flutter"
#   - alias dart="fvm dart"
#
# Usage:
#   bash setup_flutter.sh [flutter-version]
#   bash setup_flutter.sh 3.24.0
# =============================================================================

set -euo pipefail

# ─── Constants ────────────────────────────────────────────────────────────────
readonly DEFAULT_FLUTTER_VERSION="3.35.0"
readonly FLUTTER_VERSION="${1:-$DEFAULT_FLUTTER_VERSION}"
readonly JAVA_VERSION="temurin@17"
readonly ANDROID_SDK_ROOT="${HOME}/Library/Android/sdk"

# Detect which shell profile to write to
if [[ "${SHELL}" == */zsh ]]; then
  readonly SHELL_PROFILE="${HOME}/.zshrc"
else
  readonly SHELL_PROFILE="${HOME}/.bashrc"
fi

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ─── Helpers ──────────────────────────────────────────────────────────────────
log_info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
log_success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()    { echo -e "\n${BOLD}── $* ${RESET}"; }

die() {
  log_error "$*"
  exit 1
}

command_exists() {
  command -v "$1" &>/dev/null
}

# Appends a block to the shell profile only if the marker line isn't already present.
# $1 = unique marker string  $2 = full block to append
append_to_profile_once() {
  local marker="$1"
  local block="$2"
  if ! grep -qF "${marker}" "${SHELL_PROFILE}" 2>/dev/null; then
    echo "" >> "${SHELL_PROFILE}"
    echo "${block}" >> "${SHELL_PROFILE}"
    log_success "Written to ${SHELL_PROFILE}: ${marker}"
  else
    log_success "Already in ${SHELL_PROFILE}: ${marker} — skipping."
  fi
}

# ─── Step 0: Preflight ────────────────────────────────────────────────────────
preflight() {
  log_step "Step 0: Preflight checks"

  if [[ "$(uname)" != "Darwin" ]]; then
    die "This script is intended for macOS only. Detected: $(uname)"
  fi
  log_success "macOS detected."

  if ! command_exists brew; then
    die "Homebrew not found. Install it first:\n  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  fi
  log_success "Homebrew found: $(brew --version | head -1)"

  # Ensure shell profile exists
  touch "${SHELL_PROFILE}"
  log_success "Shell profile: ${SHELL_PROFILE}"
}

# ─── Step 1: Core system dependencies ────────────────────────────────────────
install_system_deps() {
  log_step "Step 1: Core system dependencies"

  local deps=(git curl unzip wget cocoapods)
  for dep in "${deps[@]}"; do
    if brew list --formula 2>/dev/null | grep -q "^${dep}$"; then
      log_success "${dep} already installed — skipping."
    else
      log_info "Installing ${dep}..."
      brew install "${dep}"
      log_success "${dep} installed."
    fi
  done
}

# ─── Step 2: Java 17 (Temurin) ───────────────────────────────────────────────
install_java() {
  log_step "Step 2: Java 17 (Temurin)"

  if brew list --cask 2>/dev/null | grep -q "^temurin@17$"; then
    log_success "Java 17 (Temurin) already installed — skipping."
  else
    log_info "Tapping homebrew/cask-versions for Temurin..."
    brew tap homebrew/cask-versions 2>/dev/null || true
    log_info "Installing Java 17 (Temurin)..."
    brew install --cask temurin@17
    log_success "Java 17 installed."
  fi

  # Resolve JAVA_HOME via /usr/libexec/java_home
  local java_home
  java_home="$(/usr/libexec/java_home -v 17 2>/dev/null || true)"

  if [[ -z "${java_home}" ]]; then
    log_warn "Could not auto-detect JAVA_HOME for Java 17."
    log_warn "You may need to set it manually in ${SHELL_PROFILE}."
  else
    log_success "JAVA_HOME resolved: ${java_home}"
    append_to_profile_once "# Java 17 (Temurin) — flutter setup" \
"# Java 17 (Temurin) — flutter setup
export JAVA_HOME=\"${java_home}\"
export PATH=\"\$JAVA_HOME/bin:\$PATH\""
  fi
}

# ─── Step 3: Android SDK ─────────────────────────────────────────────────────
install_android_sdk() {
  log_step "Step 3: Android SDK (command-line tools)"

  # Android Studio — check .app directly so we don't re-install if it was
  # installed manually (outside of Homebrew), which is a common case.
  if [[ -d "/Applications/Android Studio.app" ]]; then
    log_success "Android Studio already installed at /Applications/Android Studio.app — skipping."
  elif brew list --cask 2>/dev/null | grep -q "^android-studio$"; then
    log_success "Android Studio already installed via Homebrew — skipping."
  else
    log_info "Installing Android Studio (this may take a while)..."
    brew install --cask android-studio
    log_success "Android Studio installed."
  fi

  # Write ANDROID_HOME + platform-tools to PATH
  append_to_profile_once "# Android SDK — flutter setup" \
"# Android SDK — flutter setup
export ANDROID_HOME=\"${ANDROID_SDK_ROOT}\"
export ANDROID_SDK_ROOT=\"${ANDROID_SDK_ROOT}\"
export PATH=\"\$ANDROID_HOME/cmdline-tools/latest/bin:\$PATH\"
export PATH=\"\$ANDROID_HOME/platform-tools:\$PATH\"
export PATH=\"\$ANDROID_HOME/emulator:\$PATH\""

  log_warn "After first launch of Android Studio, open SDK Manager and install:"
  log_warn "  • Android SDK Platform (API 34 or latest stable)"
  log_warn "  • Android SDK Build-Tools"
  log_warn "  • Android Emulator"
  log_warn "  • Android SDK Platform-Tools"
  log_warn "Then run: flutter doctor --android-licenses"
}

# ─── Step 4: CocoaPods (iOS toolchain) ───────────────────────────────────────
ensure_cocoapods() {
  log_step "Step 4: CocoaPods (iOS toolchain)"

  if command_exists pod; then
    log_success "CocoaPods already available: $(pod --version)"
  else
    log_info "Installing CocoaPods gem..."
    # Prefer system gem on Apple Silicon; use sudo only if needed
    if gem install cocoapods --user-install 2>/dev/null; then
      log_success "CocoaPods installed via gem."
    else
      sudo gem install cocoapods
      log_success "CocoaPods installed via sudo gem."
    fi
  fi
}

# ─── Step 5: FVM ─────────────────────────────────────────────────────────────
ensure_fvm() {
  log_step "Step 5: FVM (Flutter Version Manager)"

  if command_exists fvm; then
    log_success "FVM already installed: v$(fvm --version)"
  else
    log_info "Installing FVM via Homebrew..."
    brew tap leoafarias/fvm
    brew install fvm

    if ! command_exists fvm; then
      die "FVM installation failed — 'fvm' not found in PATH after install."
    fi
    log_success "FVM installed: v$(fvm --version)"
  fi
}

# ─── Step 6: Flutter via FVM ─────────────────────────────────────────────────
ensure_flutter() {
  log_step "Step 6: Flutter ${FLUTTER_VERSION} via FVM"

  if fvm list 2>/dev/null | grep -qF "${FLUTTER_VERSION}"; then
    log_success "Flutter ${FLUTTER_VERSION} already in FVM cache — skipping download."
  else
    log_info "Installing Flutter ${FLUTTER_VERSION} via FVM (this may take a few minutes)..."
    fvm install "${FLUTTER_VERSION}"
    log_success "Flutter ${FLUTTER_VERSION} installed."
  fi

  log_info "Setting Flutter ${FLUTTER_VERSION} as global FVM version..."
  fvm global "${FLUTTER_VERSION}"
  log_success "Global FVM version set to ${FLUTTER_VERSION}."
}

# ─── Step 7: Shell profile — PATH + aliases ───────────────────────────────────
configure_shell() {
  log_step "Step 7: Shell profile — PATH & aliases"

  # FVM shims path
  append_to_profile_once "# FVM shims — flutter setup" \
"# FVM shims — flutter setup
export PATH=\"\$HOME/fvm/default/bin:\$PATH\""

  # flutter and dart aliases so you never need to type 'fvm flutter'
  append_to_profile_once "# FVM aliases — flutter setup" \
"# FVM aliases — flutter setup
alias flutter=\"fvm flutter\"
alias dart=\"fvm dart\""

  log_success "Aliases configured: 'flutter' → 'fvm flutter' | 'dart' → 'fvm dart'"
}

# ─── Step 8: flutter doctor ───────────────────────────────────────────────────
run_flutter_doctor() {
  log_step "Step 8: flutter doctor"

  # Source the profile so the current shell can find fvm shims
  # shellcheck disable=SC1090
  source "${SHELL_PROFILE}" 2>/dev/null || true

  local flutter_bin
  flutter_bin="$(fvm which flutter 2>/dev/null || true)"

  if [[ -n "${flutter_bin}" ]]; then
    log_info "Running flutter doctor..."
    "${flutter_bin}" doctor || true   # don't abort on doctor warnings
  else
    log_warn "Could not locate Flutter binary yet — skipping flutter doctor."
    log_warn "Open a new terminal and run: flutter doctor"
  fi
}

# ─── Final summary ────────────────────────────────────────────────────────────
print_summary() {
  echo ""
  echo -e "${BOLD}${GREEN}============================================${RESET}"
  echo -e "${BOLD}${GREEN}  Setup complete!${RESET}"
  echo -e "${BOLD}${GREEN}============================================${RESET}"
  echo ""
  echo -e "  Flutter version : ${CYAN}${FLUTTER_VERSION}${RESET} (managed by FVM)"
  echo -e "  Shell profile   : ${CYAN}${SHELL_PROFILE}${RESET}"
  echo ""
  echo -e "${BOLD}Next steps:${RESET}"
  echo -e "  1. Restart your terminal (or run ${CYAN}source ${SHELL_PROFILE}${RESET})"
  echo -e "  2. Open Android Studio → SDK Manager → install SDK Platform + Build-Tools"
  echo -e "  3. Run ${CYAN}flutter doctor --android-licenses${RESET} to accept licenses"
  echo -e "  4. Run ${CYAN}flutter doctor${RESET} — fix any remaining issues"
  echo -e "  5. Run ${CYAN}flutter --version${RESET} to verify the alias works"
  echo ""
  echo -e "${BOLD}Tip:${RESET} 'flutter' and 'dart' are now aliased to 'fvm flutter' / 'fvm dart'."
  echo -e "      You never need to prefix with 'fvm' manually again."
  echo ""
}

# ─── Entry point ──────────────────────────────────────────────────────────────
main() {
  echo ""
  echo -e "${BOLD}============================================${RESET}"
  echo -e "${BOLD}  Flutter Full Environment Setup (macOS)${RESET}"
  echo -e "${BOLD}  Flutter version: ${CYAN}${FLUTTER_VERSION}${RESET}"
  echo -e "${BOLD}============================================${RESET}"

  preflight
  install_system_deps
  install_java
  install_android_sdk
  ensure_cocoapods
  ensure_fvm
  ensure_flutter
  configure_shell
  run_flutter_doctor
  print_summary
}

main "$@"