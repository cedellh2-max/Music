#!/usr/bin/env bash
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { printf "${BLUE}info${RESET}  %s\n" "$*"; }
success() { printf "${GREEN}✓${RESET}     %s\n" "$*"; }
warn()    { printf "${YELLOW}warn${RESET}  %s\n" "$*" >&2; }
error()   { printf "${RED}error${RESET} %s\n" "$*" >&2; exit 1; }

# ── Platform detection ────────────────────────────────────────────────────────
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Linux*)  PLATFORM="linux" ;;
  Darwin*) PLATFORM="macos" ;;
  *)       error "Unsupported operating system: $OS" ;;
esac

# ── Helpers ───────────────────────────────────────────────────────────────────
need_cmd() {
  if ! command -v "$1" &>/dev/null; then
    error "Required command not found: '$1' — please install it and re-run."
  fi
}

check_cmd() {
  command -v "$1" &>/dev/null
}

# ── Banner ────────────────────────────────────────────────────────────────────
printf "\n${BOLD}Automatic Album Sequencing — Installer${RESET}\n"
printf "Platform: %s/%s\n\n" "$PLATFORM" "$ARCH"

# ── Prerequisite checks ───────────────────────────────────────────────────────
info "Checking prerequisites..."

need_cmd git
need_cmd pip

# Python >=3.10
if check_cmd python3; then
  PYTHON=python3
elif check_cmd python; then
  PYTHON=python
else
  error "Python 3.10 or newer is required. Download: https://www.python.org/downloads/"
fi

PY_VERSION="$("$PYTHON" -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
PY_MAJOR="$("$PYTHON" -c 'import sys; print(sys.version_info.major)')"
PY_MINOR="$("$PYTHON" -c 'import sys; print(sys.version_info.minor)')"

if [ "$PY_MAJOR" -lt 3 ] || { [ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -lt 10 ]; }; then
  error "Python 3.10+ is required (found $PY_VERSION). Download: https://www.python.org/downloads/"
fi
success "Python $PY_VERSION"

# ffmpeg — required for audio processing
if check_cmd ffmpeg; then
  FFMPEG_VER="$(ffmpeg -version 2>&1 | head -1 | awk '{print $3}')"
  success "ffmpeg $FFMPEG_VER"
else
  printf "\n${YELLOW}ffmpeg is required but was not found.${RESET}\n"
  if [ "$PLATFORM" = "macos" ]; then
    printf "Install via Homebrew:  ${BOLD}brew install ffmpeg${RESET}\n"
  else
    printf "Install via apt:       ${BOLD}sudo apt install ffmpeg${RESET}\n"
    printf "Install via dnf:       ${BOLD}sudo dnf install ffmpeg${RESET}\n"
  fi
  error "Please install ffmpeg and re-run this script."
fi

# ── Virtual environment ───────────────────────────────────────────────────────
printf "\n"
VENV_DIR=".venv"

if [ ! -d "$VENV_DIR" ]; then
  info "Creating virtual environment in $VENV_DIR ..."
  "$PYTHON" -m venv "$VENV_DIR"
  success "Virtual environment created"
else
  info "Virtual environment already exists at $VENV_DIR"
fi

# Activate
# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"
success "Virtual environment activated"

# ── Dependencies ──────────────────────────────────────────────────────────────
info "Upgrading pip..."
pip install --quiet --upgrade pip

if [ -f "requirements.txt" ]; then
  info "Installing Python dependencies from requirements.txt..."
  pip install --quiet -r requirements.txt
  success "Dependencies installed"
else
  warn "requirements.txt not found — skipping dependency install"
fi

# ── Optional: build executable archive (Linux/macOS with make) ────────────────
if check_cmd make && [ -f "Makefile" ]; then
  printf "\n"
  info "Makefile detected — running 'make install'..."
  make install
  success "make install complete"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
printf "\n${GREEN}${BOLD}Installation complete!${RESET}\n\n"
printf "Activate the virtual environment before use:\n"
printf "  ${BOLD}source %s/bin/activate${RESET}\n\n" "$VENV_DIR"
printf "Then launch the web app:\n"
printf "  ${BOLD}streamlit run app.py${RESET}\n\n"
printf "Or use the CLI:\n"
printf "  ${BOLD}sdistil files [files ...]${RESET}\n\n"
