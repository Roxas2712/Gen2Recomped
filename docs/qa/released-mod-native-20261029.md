# Unchanged published mods: native compatibility qualification

This is development-source evidence for PR375. The seven-candidate matrix is
still incomplete. Engine fixes are pushed; published mod entries, manifests
and functions are unchanged. Protected Gen1 checkouts, the player installation,
original ROMs and original saves were not changed. Yellow is tested inside a
separate instance of this fork, not the protected Gen1 installation.

## Current committed source and CI

Integration `c5334e8b43c5890c3aff1037b4d321a5a57d817f` incorporates main
`c45b43cd843bb18feccd19b3f550ce78168071c0`. Full
[CI40937440333](https://github.com/Roxas2712/Gen2Recomped/actions/runs/40937440333)
passed **993/993 engine suites, 4/4 SDK suites and all available ROM-free tiers**.
[Focused40937443265](https://github.com/Roxas2712/Gen2Recomped/actions/runs/40937443265)
independently passed, including216/216 restored-pipeline boot-order checks.
The actual hosted checkout `1b59e149d58ea2cf044e3ed84b63af3c81570133` has tree
`7f6b06cca4eac6daf59d6f1f0f2ed9882a1c34fa`, exactly matching this committed source.

These jobs belong to public `Roxas2712/Gen2Recomped`, use standard
`ubuntu-latest` runners and do not qualify desktop pixels or every mod.
The iOS job was skipped. Following the explicit budget instruction, no extra
CI dispatch, private CI, larger runner or budget/payment change was made.
Historical992/4 results on1b9c30fa and68961bdc remain separate evidence.

New public main `0bfdf7f9` was subsequently fetched and reviewed: GBA save-result
handling and main-thread HTTP-poll checks, seven files. It is locally merged in
`0d330088`; that unpushed descendant is not qualified by the c533 CI receipts.
No new CI was dispatched for source-only preparation.

## Published packages and actual native scope

ZIP digests were authenticated and installed files compared byte for byte.
Actual tests use LÖVE12 Metal on Apple M3, isolated own profiles, normal native
input and real owned ROM imports. Native updates and actual rendering remain
active. OS reviews use two advancing frames per recorded phase; initialization
alone is not treated as gameplay acceptance.

| Published package | Native observations | Remaining scope |
| --- | --- | --- |
| Battle Art Voxel Fork1.11.2,534files | Yellow ordinary story, staged rival combat, native move UI, normal win/SAVE and fresh CONTINUE | Completed fresh First/Third-camera review and remaining visual/reference attribution |
| Battle Art Gen2 2.1.4,178files | Crystal field/palettes, companion walking, cameras, NewBark→Route29, natural combat, green HP, win/EXP/SAVE and fresh CONTINUE | Outdoor camera/terrain and SAVE-underlay visual attribution |
| Legendary TEST134 host1.11.0,1904files | Separate Yellow installation, exact earned CONTINUE, First6/Third7 and detailed Oak lab/3D NPC rendering | Complete separate field/interior and battle scopes; diagnose actual pointer gate before orbit/return acceptance |
| Legendary Interiors0.20.0,84files | Installed unchanged alongside both hosts; furnished-room observations | Home geometry/window observed; exact submitted-home-mesh attribution prepared separately |
| TRUE3DNPCs1.1.6-test16,717files | Upright textured Mom/Oak/rival; ordinary NPC interaction;64 actual native graphics draws through the unchanged exported visible provider | Other NPC/model/map combinations |
| Legendary FreeOrbit0.1.0-test4,12files | Actual native battle touch drag changes orbit0→0.075 with upright move panels | Alternative Legendary-host battle continuation and other layouts |
| Better Battle UI0.2.1,3files | Standalone natural Rattata combat:15/15HP, NRM, C:46, STAB, native moves and win/EXP222→246 | Authored extra-panel overlap reference attribution; optional DRAMATIC_SHAPE integration |
| Gen1Follower1.8.0,423files | Current Yellow scoped run passes normal CONTINUE, native off/on, same-actor walking and actual Pikachu emotion; Crystal walking with voxel host also proved | Additional species/host/map combinations and Crystal talk |

The alternative Legendary host shares `BATTLE_ART_VOXEL_FORK` with the official
host. They are never coinstalled or given rewritten IDs. Optional Stadium
models/importers require their own applicable inputs; no substitute assets
or successful hardware/import claims are fabricated.

## Engine contracts supplied

- Native display-key dispatch and persistent world-pipeline admission, retaining
  plain-session fallback and explicit native Gen2 API ownership.
- Conservative LÖVE12 legacy shader-entry forwarding and producer-orientation
  handling. Unrelated textures and declared native/portable producers keep their
  conventions. Actual shader pixel/discard checks passed192 per backend on
  recorded source6e05037e under Metal and OpenGL; this is synthetic GPU evidence.
- Live owner-bound `world.palettes` for native Gen2 map consumers; data-only
  title atlas consumers remain usable, and native Gen3 descriptor dispatch stays.
- Native NPC rebuild, sprite definitions/metadata and follower lifecycle.
  The shared PikachuFollower setter resolves the current native Gen2 predicate
  seam without replacing existing Gen1/Gen3 or explicit Gen2 APIs.
- Classic staged-battle draw submission before native composition; current
  explicit window owners retain priority. Legacy orientation is admitted only
  for the exact verified producer helpers and live loader/dataset/registry/
  battle/canvas ownership.
- Staged GSC HP/EXP RGB composition without an extra grayscale pass; ordinary
  native panels retain their zone route.
- GSC saved-pipeline application before boot `save.created`, matching reference
  Game2 ordering. Previously a creation callback synchronized zero over saved
  First Person6 before the later full options application.

Focused frozen-source evidence includes palette/atlas/context/NPC suites with
31+30+348+182+419+152+14 = **1,176** assertions on ee72c716; the previous draft's
1,276 total was an arithmetic error. Follower suites on92ea26df passed
322+3,238+12+13 checks. The staged RGB fixture passed106 plus813 related checks;
the old path fails6 new assertions. The actual boot/event/pipeline fixture
passed216 across GSC/Red/Yellow/Emerald plus122 related checks; its exact old
source fails39. Current full CI above requalifies the combined committed code.

## Yellow story and saved-state evidence

On68961bdc, ordinary NEW GAME reached the furnished bedroom/home, native Mom
dialogue, dynamic LAST_MAP house exit, Pallet, Oak's native demonstration and
escort, and the lab. Actual interaction awarded Pikachu level5/19HP/125EXP.
Walking to the door naturally triggered the rival battle. OS reviews verified
its staged room, dialogue, green HP, commands and ELECTRIC30/30 move selection.
Native touch drag exercised FreeOrbit. Normal attacks won; Pikachu reached
level6/222EXP and the story healed it to21HP. Normal START→SAVE wrote the save;
native disk readback matched position/party/HP/level/EXP and every move ID/PP,
including newly learned TAIL_WHIP.

That combined journey receipt remains failed: its12-minute bound expired at
the last post-save OS review. Attempted late no-game/stale frames were rejected.
A following fresh CONTINUE matched the exact earned checkpoint, but a later
camera acknowledgement missed its180-second review deadline; that overall
receipt also remains failed. Earlier valid scoped observations are retained.
The earned SAVE has SHA256
`f73b33c9726d5c69b9b3cafc5e0e268e832c887151fec74a8e922a95c8f14168`.

## Current Yellow follower pass

The independent c5334e8b run passed exit0 with four accepted OS phases/eight
advancing frames: native party art/FOLLOWER, normal stop/FOLLOW? re-enable,
same-actor following with the published sprite path, and native Pikachu emotion.
All423 installed files and original ROM/archive/checkpoint/earned SAVE/options
inputs remained unchanged. Native updates stayed active:4,954 updates/errors0.
For the transient portrait the private driver repeated ordinary A only after
the preceding response ended; no timer/update/render was frozen. The response
settled normally. This qualifies the recorded standalone case.

Earlier failures remain failed: private Gen1 menu selection assumed a Gen2
value field, unwinding reopened START, a TextBox import used the wrong path,
and the talk observer tried to serialize an Image userdata. Only private
navigation/scalar observation was corrected; no mod or engine alias was added.

## Separate Legendary host and source-attributed fallback

On c5334e8b,2,717 installed members across TEST134/Interiors/NPCs/FreeOrbit
remained byte-identical. Normal CONTINUE matched OAKS_LAB position, party
HP/EXP/level, all move IDs/PP and saved pipeline1 before camera input. First6
and Third7 rendered an upright detailed lab/Oak with readable signage.

The overall receipts remain failed. First, the private continuation tried
FULL1 through3 even though published HOTKEY_ORDER deliberately excludes that
preset. The corrected ordinary-angle selection then passed, but a hardcoded
NPC index1 targeted the now-hidden rival. The actual imported map identifies
that object as OAKSLAB_RIVAL/SPRITE_BLUE. Private selection now searches the
actual visible SPRITE_OAK actor. The following native run successfully approached
visible Oak index3 through normal movement/facing/A and showed his dialogue.
It normally visited REDS_HOUSE_1F through the actual door, showing textured
floor, walls, lamps, furniture and Mom. Published stats report home/family_home,
14,466 triangles,244 floor cells and23 objects. The older global native graphics
observer had already filled its64 samples in Oak's lab, so it does not prove
which home mesh was submitted. A stronger read-only observer now compares the
actual `Interiors.draw` room argument and submitted mesh identity per room.
It does not replace a published mod function.

That run also normally returned through Pallet to Route1 and encountered a
natural Pidgey level4, showing staged figures, commands and green HP. Six
phases/twelve advancing OS frames were accepted. The360-second native bound
expired before move-selection OS acceptance; its raw complete receipt stays
failed. Field/interior and battle are now separate acceptance scopes to avoid
repeating earlier camera reviews inside every battle run.

The close coarse player billboard has a specific source explanation:
TRUE3DNPC TEST16 explicitly returns false for isPlayer/role=player in both
visible and shadow providers; its shipped tests assert that fallback. It
supplies NPC models rather than a player model. The companion's room catalogue
marks Oak's lab retained; the supported-home mesh test remains separate. No replacement player asset, mod
function change or full visual-parity claim follows from these observations.

A subsequent separate battle run on c533 normally continued and crossed to
Route1. After19 ordinary grass targets it naturally encountered Pidgey level2,
13HP/NORMAL+FLYING. Four advancing OS frames verified commands and upright
THUNDERSHOCK/GROWL/TAIL WHIP/ELECTRIC30/30 over actual staged figures and green
HP21/21. Native touch drag then failed the orbit-change assertion; child exit1
and failed complete receipt remain intact. Published FreeOrbit deliberately
honors `steerable`, pinned-back-sprite, still/VR and pose gates. Read-only live
gate diagnostics are prepared before assigning an engine cause. Ordinary
OPTIONS→BACK PLACEMENT→WORLD input is also prepared; no direct setting or
camera-state setter is used. Dark transparent HUD labels/blue ambient light
remain visual/reference findings, not a full parity pass.

## Remaining findings and gates

Crystal's recorded natural Hoothoot battle proves native commands/moves/PP,
green HP, normal win and earned EXP. Actual SAVE succeeded. Fresh CONTINUE
restored Route29(51,13), Cyndaquil level5/15HP/151EXP, TACKLE32/LEER30PP and
selected camera6. The functional child exited0, but close/dense/dark terrain
prevented full visual acceptance. Another natural arena occluded figures;
SAVE exposed a transparent START/CACHE underlay. Reference attribution remains
open. An earlier private restart reinstall created a duplicate folder; this
was not treated as an engine installer defect. Blue EXP fill was not separately
accepted in an OS capture; its RGB route is regression-tested.

Better Battle UI's functional child exited0; its conservative raw return-field
visual failure remains failed. Subsequent no-mod native controls on1b9c30fa
and prior68961bdc both passed the same earned CONTINUE and Route1(10,35) path,
with matching original GB tile presentation. This does not establish a new
atlas/main or UI field defect. Initial black quadrants occurred in the native
battle transition rather than the settled field. Reused no-mod restart metadata
once incorrectly said camera matched despite that check being inapplicable;
the producer is corrected and raw receipts remain unchanged.

Current Bryan dev cfa2b14c was fetched/read in the own read-only remote. New
stepped-installer, uiShiftRight and speed-step interfaces were identified;
source review alone is not implementation or complete parity. Final work
still includes applicable native cases, current-source visual/reference
attribution, complete acceptance audit, and packaged/Windows qualification.
PR375 stays draft. There is no universal-mod, completed-goal or new-release claim.

Storage uses the installed preserving QA helpers and actual20-GiB reserve.
Idle test hosts are archived/cleaned after the final child; models, ROMs,
original saves, sources and evidence are retained. The last requested sweep
freed about3GiB actual space. No system swap or player profile was removed.
