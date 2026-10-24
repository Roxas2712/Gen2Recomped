#!/usr/bin/env bash
# Launch the combined portability branch with its own LÖVE save identity.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export POKEPORT_SKIP_LEGACY_MIGRATION=1
export POKEPORT_ISOLATED_TESTING=1
export POKEPORT_IDENTITY="${POKEPORT_IDENTITY:-Gen2RecompPortabilityTesting}"
printf 'Portability test identity: %s\n' "$POKEPORT_IDENTITY"
if [ -n "${POKEPORT_LOVE:-}" ]; then
  if [ ! -x "$POKEPORT_LOVE" ]; then
    printf 'POKEPORT_LOVE is not an executable: %s\n' "$POKEPORT_LOVE" >&2
    exit 1
  fi
  exec "$POKEPORT_LOVE" "$ROOT" "$@"
fi
exec bash "$ROOT/scripts/run.sh" "$@"
