#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
export POKEMON_XY_ROOT="$PWD"
export VK_ICD_FILENAMES="$PWD/.local/pokemon-x/vulkan/MoltenVK_icd.json"
export DYLD_FALLBACK_LIBRARY_PATH="$PWD/.local/pokemon-x/vulkan/packages/vulkan-loader/1.4.363.0/lib${DYLD_FALLBACK_LIBRARY_PATH:+:$DYLD_FALLBACK_LIBRARY_PATH}"
export RUST_LOG="info,cranelift_jit=warn"
exec "$PWD/.local/pokemon-x/Gen2Recomp Ascendant.app/Contents/MacOS/love" "$PWD" "$@"
