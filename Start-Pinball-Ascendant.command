#!/bin/zsh
# Contributions by Roxas2712. Uses a locally prepared cartridge/runtime only.
set -eu
ROOT="${0:A:h}"
LOVE_BIN="${ASCENDANT_LOVE_BIN:-}"
if [[ -z "$LOVE_BIN" && -f "$ROOT/.local/pinball-rs/love-bin.txt" ]]; then
  IFS= read -r LOVE_BIN < "$ROOT/.local/pinball-rs/love-bin.txt" || true
fi
if [[ -z "$LOVE_BIN" ]]; then
  if command -v love >/dev/null 2>&1; then LOVE_BIN="$(command -v love)"
  elif [[ -x '/Applications/love.app/Contents/MacOS/love' ]]; then LOVE_BIN='/Applications/love.app/Contents/MacOS/love'
  elif [[ -x "$ROOT/.local/pokemon-x/Gen2Recomp Ascendant.app/Contents/MacOS/love" ]]; then
    LOVE_BIN="$ROOT/.local/pokemon-x/Gen2Recomp Ascendant.app/Contents/MacOS/love"
  else
    print 'LÖVE fehlt. ASCENDANT_LOVE_BIN auf die vorhandene LÖVE-Datei setzen.'
    exit 1
  fi
fi
if [[ ! -x "$LOVE_BIN" ]]; then print 'Die konfigurierte LÖVE-Datei ist nicht ausführbar.'; exit 1; fi
export ASCENDANT_PINBALL_ROOT="$ROOT"
export ASCENDANT_PINBALL_START=1
exec "$LOVE_BIN" "$ROOT"
