# Native world-canvas compatibility

The native compositor consumes a pipeline's `worldOrientation` contract. An
explicit `native` declaration and the portable `renderData.v1` boundary keep
current coordinates; an explicit `legacy` declaration requests the legacy
completed-world orientation. UI composition remains separate.

Published Battle Art Voxel Gen2 2.1.4 additionally flips its completed Gen2
world on LÖVE12 Metal/Apple ES in `WorldCanvasOrientation.present`. The native
engine already normalizes the producer's legacy shader projection, so that
extra completed-world copy arrives inverted. `WorldCanvasContracts` supplies
the existing legacy presentation contract for this exact published producer.

The rule requires the declared repository and exact version, successful mod
loading, the actual pipeline owner, and matching SHA256 for both orientation
helpers. A mod ID alone does not qualify. Different or edited helper files,
other releases, other producers and native Gen2 mods keep their prior
behavior. An explicit pipeline convention always takes precedence. The
producer definition, installed files and mod functions are not rewritten.
Bindings retire on load/teardown and retain no mod objects. Verification runs
once during loading; there is no filesystem hashing in the draw loop.

ROM-free contracts cover ownership, backend/version/generation gating,
explicit declarations, file mismatch, bounded reads and session retirement.
Actual published-mod GPU/window verification remains a separate acceptance
requirement. Contributions by Roxas2712; existing contributor rights remain.
