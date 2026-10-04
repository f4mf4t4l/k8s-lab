#!/usr/bin/env bash
# Gemeinsame Funktionen – wird von allen Skripten eingebunden.
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$BASE"

if [[ ! -f env ]]; then
  echo "FEHLER: ./env fehlt. Bitte 'cp env.example env' ausfuehren und anpassen." >&2
  exit 1
fi
# shellcheck source=/dev/null
source ./env

BIN_DIR="$(realpath -m "$BIN_DIR")"
WORK_DIR="$(realpath -m "$WORK_DIR")"
INSTALL_DIR="$WORK_DIR/install"
export PATH="$BIN_DIR:$PATH"

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mFEHLER:\033[0m %s\n' "$*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "'$1' wird benoetigt, ist aber nicht installiert."; }
