#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
EDITOR_DIR="$REPO_ROOT/editor"
OUTPUT_DIR="$REPO_ROOT/src/updoc/Resources/editor"

mkdir -p "$OUTPUT_DIR"
cd "$EDITOR_DIR"

if ! command -v node &>/dev/null; then
  echo "warning: node not found, skipping editor bundle build"
  exit 0
fi

npm ci
npm run build
echo "editor.js built successfully → $OUTPUT_DIR/editor.js"
