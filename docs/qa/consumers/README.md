# Unchanged consumer probes

These external acceptance drivers use the actual engine modules and unchanged
published mods. They are deliberately outside the ROM-free engine suite.
Run from an engine source checkout through a `qa_storage`-guarded launcher,
with LuaJIT and the supported imported **Red** dataset selected through
`POKEPORT_DATA_DIR`. Pin inputs before cache cleanup and run workers at nice 19.

- `read-only-qol.lua` takes the frozen QoL source directory, imported asset
  directory, `rectangle-glyphs`, and `qol-native-water.lua`, in that order.
  It maps read-only mod/art reads before executing the consumer.
- `battleart-native.lua` takes the verified package-source parent containing
  `battleart/` and `interiors/`, imported asset directory, `host` or `combined`,
  decoded-pixel fixture directory, and `pixel-hardware.lua`, in that order.
  It reads both packages unchanged, redirects persistence into memory, and
  refuses disk writes. No native callbacks or mod runtime methods are replaced.
- The pixel fixture contains `index.json`, mapping logical PNG paths to
  `width`, `height`, RGBA `file`, original `input_sha256`, and `rgba_sha256`.
  Decode pinned PNGs losslessly to RGBA. The accepted fixture covers imported
  tilesets/sprites/battle art, selected small package PNGs and the Interiors
  material/emission atlases. FileData names `interior-materials.png` and
  `native-emission.png` alias those same atlas records.

The pixel/mesh adapter validates CPU data. It leaves shaders and graphics-device
staging unavailable, and the battle probe explicitly checks the 2D fallback.
Neither no-op draw calls nor matching geometry counts establish visual equality,
shader validity, depth/reflections, FPS or handheld acceptance. The fixture's
ROM-derived pixels and third-party mod packages are not distributed here.

The formatted public probes have byte-for-byte identical stripped LuaJIT
bytecode to the successfully executed originals. See the adjacent
[acceptance receipt](../unchanged-mod-consumers.json) for refs, package SHA-256
values, raw log fingerprints, exact checks and remaining work.
