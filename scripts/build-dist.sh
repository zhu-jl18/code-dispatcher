#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT/dist"

mkdir -p "$OUT_DIR"

echo "[build-dist] building fish-agent-wrapper artifacts into: $OUT_DIR"

(
  cd "$ROOT/fish-agent-wrapper"
  CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o "$OUT_DIR/fish-agent-wrapper-linux-amd64"
  CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -o "$OUT_DIR/fish-agent-wrapper-windows-amd64.exe"
  CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -o "$OUT_DIR/fish-agent-wrapper-darwin-arm64"
)

chmod +x "$OUT_DIR/fish-agent-wrapper-linux-amd64" "$OUT_DIR/fish-agent-wrapper-darwin-arm64" || true

echo "[build-dist] done:"
ls -la "$OUT_DIR" | sed -n '1,200p'
