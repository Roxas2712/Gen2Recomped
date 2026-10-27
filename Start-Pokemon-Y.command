#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
export POKEMON_XY_EDITION=y
exec ./Start-Recompiled-Ascendant.command "$@"
