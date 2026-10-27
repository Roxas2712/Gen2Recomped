#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
export POKEMON_XY_EDITION=x
exec ./Start-Recompiled-Ascendant.command "$@"
