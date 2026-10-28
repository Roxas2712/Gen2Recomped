# Shared native RS outline cursor

The public cursor and the fork's native RS battle panel share
`Gen3RsMenuCursor`. It uses the imported common-UI manifest and central native
Assets cache. Detached segment queries preserve the cartridge's cap/overlap
positions; a bounded sixteen-width plan cache avoids constructing strips on
ordinary repeated draws. Edition/dataset replacement, asset invalidation and
owner teardown retire manifest metadata. Borrowed images are never released by
the cursor, and graphics failures restore the caller's state.

Images retain their logical 8/32 by16 size independently of texel density.
The native controller changes only its cursor binding; no rule, input, queue,
clock, random or save owner is replaced. The older-public composition offers
the shared drawing service and public facade against its own controller set;
it does not overlay the fork's later RS controller body.

Fork frozen source `16fd33d5e5` passes45 groups, including644 cursor checks and
RS native-panel readiness. The older-public composition `b60bac3ca5` passes28
groups, including131 portable cursor checks. The fork additionally compares
513 widths against its retained pinned native reference.

Owned-output GPU runs `acc5ab25cd` (fork) and `bb8bfe6dd8` (public) each pass
1474 checks across256 constructed frames on Metal and on OpenGL: golden cap/
overlap placement, DPI1/2, texture density1/2/3, fades/grayscale/brightness,
and actual native two-tone font pixels through the indexed colour facade for
all five editions. Synthetic artwork is deliberate: these are drawing-contract
proofs, not cartridge-art, OS-window, full-game or sustained-FPS acceptance.
Managed QA keeps20GiB free and uses separate identities; reference mods and
player saves are untouched.
