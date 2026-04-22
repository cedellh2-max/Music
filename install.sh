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
  Linux*)   PLATFORM="linux" ;;
  Darwin*)  PLATFORM="macos" ;;
  MINGW*|CYGWIN*|MSYS*) PLATFORM="windows" ;;
  *)        error "Unsupported operating system: $OS" ;;
esac

case "$ARCH" in
  x86_64|amd64) ARCH="x86_64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *) warn "Unrecognized architecture: $ARCH — proceeding anyway" ;;
esac

# ── Helpers ───────────────────────────────────────────────────────────────────
need_cmd() {
  if ! command -v "$1" &>/dev/null; then
    error "Required command not found: $1 — please install it and re-run."
  fi
}

check_cmd() {
  command -v "$1" &>/dev/null
}

# ── Prerequisite checks ───────────────────────────────────────────────────────
printf "\n${BOLD}Music — Installer${RESET}\n"
printf "Platform: %s/%s\n\n" "$PLATFORM" "$ARCH"

info "Checking prerequisites..."

need_cmd curl
need_cmd git

# Node.js (>=18)
need_cmd node
NODE_VERSION="$(node --version | sed 's/v//')"
NODE_MAJOR="${NODE_VERSION%%.*}"
if [ "$NODE_MAJOR" -lt 18 ]; then
  error "Node.js 18 or newer is required (found $NODE_VERSION). Download: https://nodejs.org"
fi
success "Node.js $NODE_VERSION"

# npm or yarn or pnpm — prefer whichever is present
if check_cmd pnpm; then
  PKG_MGR="pnpm"
elif check_cmd yarn; then
  PKG_MGR="yarn"
else
  need_cmd npm
  PKG_MGR="npm"
fi
success "Package manager: $PKG_MGR"

# Optional: ffmpeg for audio processing
if check_cmd ffmpeg; then
  success "ffmpeg $(ffmpeg -version 2>&1 | head -1 | awk '{print $3}')"
else
  warn "ffmpeg not found — some audio features may be unavailable"
  warn "Install: https://ffmpeg.org/download.html"
fi

# ── Install dependencies ──────────────────────────────────────────────────────
printf "\n"
info "Installing dependencies..."

if [ -f "package.json" ]; then
  case "$PKG_MGR" in
    pnpm) pnpm install ;;
    yarn) yarn install ;;
    npm)  npm install ;;
  esac
  success "Dependencies installed"
else
  warn "No package.json found — skipping dependency install"
fi

# ── Environment setup ─────────────────────────────────────────────────────────
if [ ! -f ".env" ]; then
  if [ -f ".env.example" ]; then
    cp .env.example .env
    success "Created .env from .env.example"
    warn "Edit .env and fill in any required values before running the project"
  fi
fi

# ── Done ──────────────────────────────────────────────────────────────────────
printf "\n${GREEN}${BOLD}Installation complete!${RESET}\n"
printf "Run ${BOLD}npm start${RESET} (or equivalent) to launch the project.\n\n"
