#!/usr/bin/env python3
"""Qualify native scenes and measure isolated, freshly imported games."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import time

from qa_storage import qa_source, qa_cache, qa_copy, qa_profile, qa_run, qa_extract_archive
from check_full_game_performance import BOOTSTRAP

ROOT = Path(__file__).resolve().parents[1]
SCENES = {
    "red-pallet": {"version": "red", "names": ["PALLET_TOWN"]},
    "red-route1": {"version": "red", "names": ["ROUTE_1"]},
    "gold-goldenrod-day": {"version": "gold", "names": ["GOLDENROD_CITY"], "hour": 12},
    "gold-goldenrod-night": {"version": "gold", "names": ["GOLDENROD_CITY"], "hour": 22},
    "emerald-route101-103": {"version": "emerald", "names": ["ROUTE101", "OLDALE_TOWN", "ROUTE103"]},
    "emerald-route119-voxel": {"version": "emerald", "names": ["ROUTE119"], "voxel": True},
    # Native header identities are pinned by Gen4TownMap and Gen4AreaPopup.
    "platinum-twinleaf-201": {"version": "platinum", "headers": [411, 342]},
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--love", type=Path, required=True)
    parser.add_argument("--lua", type=Path, help="LuaJIT for compiling adapted host files before import")
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--scene", choices=sorted(SCENES), action="append", required=True)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--inventory", action="store_true", help="inspect scene identities")
    mode.add_argument("--setup-probe", action="store_true", help="inspect native scene admission without measuring speed")
    mode.add_argument("--walk-probe", action="store_true", help="verify native walking across the required seams; no speed claim")
    mode.add_argument("--measure", action="store_true", help="measure each required switch case for at least 60 real seconds")
    parser.add_argument("--seconds", type=float, default=60)
    parser.add_argument("--backend", choices=("metal", "opengl"), default="metal")
    parser.add_argument("--fps-cap", type=int, choices=(30,60,120,160), default=160)
    parser.add_argument("--atlas-bridge", action="store_true", help="exercise the production Gen-3 source field/atlas presentation")
    parser.add_argument("--hidden", action="store_true", help="Use an invisible native window for matched unfocused measurements")
    parser.add_argument("--stable-focus", action="store_true", help="Reject measurements whose actual native focus changes")
    parser.add_argument("--unfocused-sdl3", type=Path, help="SDL3 library for a real non-focusable show/hide transition; requires --hidden --stable-focus")
    parser.add_argument("--perf", help="Native POKEPORT_PERF overrides, e.g. atlasWorker=0")
    parser.add_argument("--variant", action="append", choices=("default", "idle-off", "idle-on", "voxel-idle-off", "voxel-idle-on", "voxel-warm-disk", "adaptive"))
    for version in ("red", "gold", "emerald", "platinum"):
        parser.add_argument("--" + version, type=Path)
    args = parser.parse_args()
    if args.unfocused_sdl3 and not (args.measure and args.hidden and args.stable_focus):
        parser.error("--unfocused-sdl3 requires --measure --hidden --stable-focus")
    if args.unfocused_sdl3:
        qa_source(args.unfocused_sdl3.resolve())
        assert args.unfocused_sdl3.is_file(), "SDL3 library is missing"
    if args.atlas_bridge and any(not name.startswith("emerald-") for name in args.scene):
        parser.error("--atlas-bridge requires Gen-3 scenes")
    if args.seconds < 60:
        parser.error("measurement intervals must be at least 60 real seconds")
    if args.variant and not args.measure:
        parser.error("--variant requires --measure")
    planned = {}
    for name in args.scene:
        scene = SCENES[name]
        variants = ["default"]
        if args.measure and len(scene.get("names", scene.get("headers", []))) > 1:
            variants = ["idle-off", "idle-on"]
        elif args.measure and scene.get("voxel"):
            variants = ["voxel-idle-off", "voxel-idle-on", "voxel-warm-disk", "adaptive"]
        if args.variant:
            variants = [v for v in variants if v in args.variant]
            if "voxel-warm-disk" in variants and "voxel-idle-on" not in variants:
                variants.insert(0,"voxel-idle-on")
        if variants:
            planned[name] = variants
    if not planned:
        parser.error("no selected scene supports the requested variant")
    binary = args.love.resolve(strict=True)
    versions = sorted({SCENES[name]["version"] for name in planned})
    cartridges = {}
    for version in versions:
        path = getattr(args, version)
        if path is None:
            parser.error("--" + version + " is required for the selected scene")
        cartridges[version] = path.resolve(strict=True)
    for path in (ROOT, binary, *cartridges.values()):
        qa_source(path)
    lua = args.lua.resolve(strict=True) if args.lua else None
    if lua:
        qa_source(lua)
    out = qa_cache(args.out.resolve())
    out.mkdir(parents=True, exist_ok=False)
    hardware = {}
    if sys.platform == "darwin":
        for field, key in (("cpu", "machdep.cpu.brand_string"), ("physicalCores", "hw.physicalcpu"),
                           ("logicalCores", "hw.logicalcpu"), ("memoryBytes", "hw.memsize")):
            result = qa_run(["/usr/sbin/sysctl", "-n", key], capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                value = result.stdout.strip()
                hardware[field] = int(value) if value.isdigit() else value
        result = qa_run(["/usr/sbin/system_profiler", "SPDisplaysDataType", "-json"],
                        capture_output=True, text=True, timeout=30)
        if result.returncode == 0:
            hardware["gpus"], hardware["panels"] = [], []
            for gpu in json.loads(result.stdout).get("SPDisplaysDataType", []):
                hardware["gpus"].append({"name": gpu.get("sppci_model", gpu.get("_name")),
                                         "cores": gpu.get("spdisplays_totalcores", gpu.get("sppci_cores"))})
                for display in gpu.get("spdisplays_ndrvs", []):
                    hardware["panels"].append({"name": display.get("_name"),
                        "desktopMode": display.get("_spdisplays_resolution"),
                        "backingPixels": display.get("_spdisplays_pixels"),
                        "physicalPanelMode": display.get("spdisplays_pixelresolution")})
    source = qa_copy(out / "source", ephemeral=True)
    source.mkdir()
    head = qa_run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True,
                  text=True, check=True).stdout.strip()
    reference = qa_run(["git", "rev-parse", "origin/main"], cwd=ROOT, capture_output=True,
                       text=True, check=True).stdout.strip()
    diff = qa_run(["git", "diff", "--quiet", reference, head, "--", "src", "main.lua", "conf.lua", "mods", "assets"], cwd=ROOT)
    assert diff.returncode in (0,1), "runtime comparison failed"
    assert not qa_run(["git", "status", "--porcelain"], cwd=ROOT, capture_output=True,
                      text=True, check=True).stdout.strip(), "Commit the candidate first"
    git_dir = Path(qa_run(["git", "rev-parse", "--absolute-git-dir"], cwd=ROOT,
                          capture_output=True, text=True, check=True).stdout.strip())
    qa_extract_archive(git_dir, head, source)
    if args.hidden:
        conf = source / 'conf.lua'
        conf.write_text(conf.read_text() + '\nlocal configure=love.conf\nfunction love.conf(t)configure(t);t.window.visible=false end\n')
    engine = source / "main.lua"
    engine_hash = hashlib.sha256(engine.read_bytes()).hexdigest()
    adaptations = []
    if args.measure:
        code = engine.read_text()
        pacing = '  if os.getenv("POKEPORT_DRIVER") then return false end'
        assert code.count(pacing) == 1
        code = code.replace(pacing, '  if os.getenv("POKEPORT_DRIVER") and os.getenv("PERF_NATIVE_PACING") ~= "1" then return false end')
        begin = code.index('  if driverCo then\n')
        end = code.index('  if not Game then return end', begin)
        block = code[begin:end]
        update = '      Game:update(1 / 60)'
        assert block.count(update) == 1
        code = code[:begin] + block.replace(update, '      PlatformHooks.update(Game, dt)') + code[end:]
        engine.write_text(code)
        adaptations = ["Enable existing native pacing in the owned driver host",
                       "Use the interactive PlatformHooks.update and real dt after each driver observation"]
    patched_hash = hashlib.sha256(engine.read_bytes()).hexdigest()
    instrumented = {}
    if args.measure:
        def instrument(relative, replacements, suffix=None):
            path=source/relative
            before=path.read_bytes()
            text=before.decode()
            for old,new,expected in replacements:
                assert text.count(old)==expected,(relative,old,text.count(old))
                text=text.replace(old,new)
            if suffix:
                old,new=suffix
                assert text.rstrip().endswith(old),relative
                at=text.rindex(old);text=text[:at]+new+text[at+len(old):]
            text='local BaselineSections=require("tools.performance_baseline_sections")\n'+text
            path.write_text(text)
            instrumented[relative]={"originalSha256":hashlib.sha256(before).hexdigest(),
                                    "hostSha256":hashlib.sha256(path.read_bytes()).hexdigest()}
        instrument("src/render/TileRenderer.lua",[("self:syncGen3Palettes()",
            'BaselineSections.call("  tiles: syncGen3Palettes", self.syncGen3Palettes, self)',3)])
        instrument("src/render/Gen4Ground.lua",[("self:livePass(",
            'BaselineSections.call("  gen4: live pass", self.livePass, self, ',3)])
        instrument("src/core/Music.lua",[('require("src.audio.NitroAudio").update()',
            'BaselineSections.call("  audio: Nitro update", require("src.audio.NitroAudio").update)',1)])
        if args.atlas_bridge:
            instrument("src/compat/gen1/AtlasRuntime.lua",[],('return M', '''
local create=M.new
function M.new(api)
  local runtime=create(api)
  for _,name in ipairs({'prefetch','step'})do
    local original=runtime[name]
    local label='  atlas: '..name
    runtime[name]=function(...)return BaselineSections.call(label,original,...)end
  end
  return runtime
end
return M'''))
            instrument("src/core/BuildWorker.lua",[],('return BuildWorker', '''
local poll=BuildWorker.poll
function BuildWorker.poll(...)return BaselineSections.call('  atlas: pool delivery',poll,...)end
return BuildWorker'''))
        if any(SCENES[name].get("voxel") for name in planned):
            for module,method,export in (("Structures","forMap","Structures"),("Gen3","prepare","Gen3"),
                                         ("TerrainAtlas","forMap","TerrainAtlas"),("VoxelDiskCache","load","Cache")):
                instrument("mods/DRAMATIC_SHAPE/lib/"+module+".lua",[],
                    ('return '+export,export+'.'+method+'=BaselineSections.wrapSetup("    voxel: '+module+'.'+method+'",'+export+'.'+method+')\nreturn '+export))
            changes=[]
            for fn,label,count in (("buildGrassMesh","grass",2),("buildFlowerMesh","flowers",2),("buildFigureMeshes","figures",1)):
                changes.append(('pcall('+fn+', map)',
                    'pcall(BaselineSections.call,"    voxel: build '+label+'",'+fn+', map)',count))
            instrument("mods/DRAMATIC_SHAPE/lib/ChunkMesher.lua",changes)
        adaptations.append("Profile selected native calls in the owned copy with argument/return-preserving adapters")
    engine.rename(source / "engine_main.lua")
    seed = '''
local settings=os.getenv("PERF_BASELINE_OPTIONS")
if settings then
 require('src.storage.AccountStorage').enable()
 local Save=require("src.core.SaveData")
 require("src.core.GameVersion").set(assert(os.getenv("POKEPORT_VERSION")))
 local opts=Save.loadOptions()
 for key,value in pairs(require("src.link.Json").decode(settings)) do opts[key]=value end
 assert(Save.saveOptions(opts))
end
'''
    bootstrap = BOOTSTRAP.replace('assert(loadfile("engine_main.lua"))()', seed + '\nassert(loadfile("engine_main.lua"))()')
    (source / "main.lua").write_text(bootstrap)
    if lua:
        for relative in ("engine_main.lua", "main.lua", *instrumented,
                         "tools/performance_baseline_driver.lua", "tools/performance_baseline_meter.lua",
                         "tools/performance_baseline_sections.lua", "tools/performance_baseline_walk.lua"):
            qa_run([str(lua), "-e", "assert(loadstring(io.read('*a'),"+json.dumps("@"+relative)+"))"],
                   input=(source/relative).read_text(), capture_output=True, text=True, timeout=30, check=True)
    env = {k: v for k, v in os.environ.items()
           if not k.startswith(("POKEPORT_", "PERF_", "PALETTE_"))}
    env.update(POKEPORT_NO_MODS="1", POKEPORT_NO_BOOT_REPORT="1",
               POKEPORT_NO_DISCORD="1", POKEPORT_NOTIFY_ONLY_UPDATES="1",
               POKEPORT_GRAPHICS_BACKEND=args.backend)
    if args.perf:
        env["POKEPORT_PERF"] = args.perf
    if args.unfocused_sdl3:
        env["PERF_BASELINE_UNFOCUSED_SDL3"] = str(args.unfocused_sdl3.resolve())
        env["SDL_WINDOW_ACTIVATE_WHEN_SHOWN"] = "0"
        adaptations.append("Use actual non-focusable SDL3 show/hide; verify unmodified native focus queries")
    token = str(time.time_ns())
    profiles = {}
    inputs = {}
    results = []
    progress = {"complete":False,"sourceCommit":head,"referenceMainCommit":reference,
                "runtimeMatchesMain":diff.returncode==0,"hardware":hardware,"romSha1":inputs,
                "originalEntrypointSha256":engine_hash,"hostEntrypointSha256":patched_hash,
                "instrumentedFiles":instrumented,"testAdaptations":adaptations,"results":results}
    def checkpoint():
        temp=out/"progress.json.tmp"
        temp.write_text(json.dumps(progress,indent=2)+"\n")
        temp.replace(out/"progress.json")
    checkpoint()
    for version, rom in cartridges.items():
        identity = "oasc-gen2recomp-qa-perf-baseline-" + token + "-" + version
        profiles[version] = identity
        qa_source(Path.home() / "Library/Application Support/LOVE" / identity)
        qa_profile(Path.home() / "Library/Application Support/LOVE" / identity)
        inputs[version] = hashlib.sha1(rom.read_bytes()).hexdigest()
        checkpoint()
        child = dict(env, POKEPORT_IDENTITY=identity, POKEPORT_VERSION=version,
                     POKEPORT_IMPORT_ROM=str(rom), POKEPORT_IMPORT_ONLY="1")
        with (out / (version + "-import.log")).open("w") as log:
            qa_run([str(binary), str(source)], cwd=source, env=child,
                   stdout=log, stderr=log, timeout=600, check=True)
    for name, variants in planned.items():
        scene = SCENES[name]
        for variant in variants:
            spec = dict(scene, name=name, inventory=not args.measure, measure=args.measure,
                        seconds=args.seconds, fpsCap=args.fps_cap, variant=variant, atlasBridge=args.atlas_bridge, stableFocus=args.stable_focus,
                        setupProbe=args.setup_probe or args.walk_probe, walkProbe=args.walk_probe)
            version = spec["version"]
            label = name + ("-" + variant if args.measure else "")
            identity = profiles[version]
            if args.measure:
                identity += "-" + label
                qa_source(Path.home() / "Library/Application Support/LOVE" / identity)
                profile = qa_profile(Path.home() / "Library/Application Support/LOVE" / identity)
                seed_identity=profiles[version]
                if variant=="voxel-warm-disk":
                    seed_identity+="-"+name+"-voxel-idle-on"
                original = Path.home() / "Library/Application Support/LOVE" / seed_identity
                shutil.copytree(original, profile, dirs_exist_ok=True)
            target = out / (label + ".json")
            child = dict(env, POKEPORT_IDENTITY=identity, POKEPORT_VERSION=version,
                         POKEPORT_DRIVER=str(source / "tools/performance_baseline_driver.lua"),
                         PERF_BASELINE_SPEC=json.dumps(spec), PERF_BASELINE_OUT=str(target))
            if args.measure:
                child["PERF_NATIVE_PACING"] = "1"
            if args.measure and scene.get("voxel"):
                mods = {}
                for manifest in (source / "mods").glob("*/manifest.json"):
                    mod_id = json.loads(manifest.read_text())["id"]
                    mods[mod_id] = mod_id == "Gen2Recomped-DramaticShapes"
                child.pop("POKEPORT_NO_MODS", None)
                child["PERF_BASELINE_OPTIONS"] = json.dumps({"mods": mods})
            with (out / (label + ".log")).open("w") as log:
                result = qa_run([str(binary), str(source)], cwd=source, env=child,
                                stdout=log, stderr=log, timeout=max(600, args.seconds + 360))
            data = json.loads(target.read_text()) if target.exists() else {"passed": False}
            results.append({"scene": name, "variant": variant, "exit": result.returncode, "report": data})
            checkpoint()
            print(label, "PASS" if result.returncode == 0 and data["passed"] else "FAIL", flush=True)
    stable = qa_run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True,
                    text=True, check=True).stdout.strip() == head
    report = {"passed": stable and bool(results) and all(r["exit"] == 0 and r["report"]["passed"] for r in results),
              "sourceCommit": head, "sourceStable": stable, "inventoryOnly": not args.measure,
              "referenceMainCommit": reference, "runtimeMatchesMain": diff.returncode == 0,
              "performanceBaseline": args.measure, "freshImports": True, "playerProfilesUsed": False,
              "originalEntrypointSha256": engine_hash, "hostEntrypointSha256": patched_hash,
              "testAdaptations": adaptations, "separateCaseProfiles": args.measure,
              "instrumentedFiles": instrumented,
              "hostSyntaxChecked": lua is not None,
              "hardware": hardware,
              "benchmarkControls": {"fpsCap": args.fps_cap, "seconds": args.seconds,
                                    "performanceOverrides": args.perf, "atlasBridge": args.atlas_bridge,
                                    "hiddenWindow": args.hidden, "stableNativeFocus": args.stable_focus,
                                    "unfocusedNativeWindow": bool(args.unfocused_sdl3),
                                    "nativePacing": args.measure, "vsync": 0 if args.measure else None,
                                    "backgroundCapDisabled": args.measure, "randomSeed": 12345},
              "romSha1": inputs, "results": results}
    (out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
