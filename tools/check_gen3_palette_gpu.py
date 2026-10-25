#!/usr/bin/env python3
"""Fresh full imports + real Game/Overworld GPU acceptance; never reuse saves.

Requires a desktop LÖVE runtime and the supported user-owned BPEE0/BPRE0 ROMs.
All generated assets/screenshots stay in ignored local folders/save identities.
"""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
DRIVER = ROOT / "tools/gen3_palette_gpu_driver.lua"
TARGETS = {
    "emerald": ("MAP_G26_N21", 10, 5),
    "firered": ("MAP_G03_N00", 11, 11),
}

BOOTSTRAP = r'''
local identity=assert(os.getenv("POKEPORT_IDENTITY"))
assert(identity:match("^gen2%-palette%-gpu%-"),"test identity required")
assert(love.filesystem.getIdentity()==identity,"identity mismatch")
-- The normal startup migrates legacy player data even with a new identity.
-- Bypass it BEFORE requiring main, and reject any later identity switch.
assert(love.filesystem.write("migrated-from-pokemon-love2d.txt",
  "Isolated GPU test: legacy migration deliberately bypassed.\n"))
local setIdentity=love.filesystem.setIdentity
love.filesystem.setIdentity=function(value,...)
  assert(value==identity,"isolated test rejected identity switch")
  return setIdentity(value,...)
end
assert(require("src.core.SaveData").portableBaseDir()==nil,"portable mode forbidden")
assert(require("src.import.CacheFs").root()==nil,"external cache root forbidden")
io.stdout:setvbuf("no")
print("[isolated-gpu] identity="..identity.." save="..love.filesystem.getSaveDirectory())
assert(loadfile("engine_main.lua"))()
love.errorhandler=function(err)
  local f=assert(io.open(assert(os.getenv("PALETTE_GPU_OUT")).."/error.txt","w"))
  f:write(debug.traceback(tostring(err),2));f:close()
  print("[isolated-gpu] ERROR "..tostring(err))
  return function() return 1 end
end
'''


def environment(identity, version, out):
    # Inherited developer/editor/autopilot flags must not redirect this run.
    env = {k: v for k, v in os.environ.items()
           if not k.startswith(("POKEPORT_", "PALETTE_GPU_"))}
    env.update(POKEPORT_IDENTITY=identity, POKEPORT_VERSION=version,
               POKEPORT_NO_BOOT_REPORT="1", POKEPORT_NO_DISCORD="1",
               POKEPORT_NOTIFY_ONLY_UPDATES="1", POKEPORT_TOUCH="0",
               PALETTE_GPU_OUT=str(out))
    return env


def child(love, source, env, log, timeout, tick=None):
    with log.open("w") as stream:
        process = subprocess.Popen([str(love), str(source)], cwd=source,
                                   env=env, stdout=stream, stderr=subprocess.STDOUT)
        try:
            if tick is None:
                code = process.wait(timeout=timeout)
            else:
                deadline = time.monotonic() + timeout
                while process.poll() is None:
                    if time.monotonic() >= deadline:
                        raise subprocess.TimeoutExpired(process.args, timeout)
                    tick(process.pid)
                    time.sleep(.02)
                code = process.returncode
        except BaseException:
            # Only the process created here; no global process/window control.
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
            raise
    if code:
        raise RuntimeError(f"Test exited {code}; see {log}")


def os_window_proof(out, colour_profile="gba"):
    # A valid GBC scene can have fewer than 16 colors in the central crop.
    # Keep the GBA/voxel guard unchanged; native GB tests select their profile.
    if colour_profile not in ("gba", "gbc"):
        raise ValueError("Unknown window colour profile")
    minimum_colours = 4 if colour_profile == "gbc" else 16
    """Only the window ID reported by our own child; one capture, no retries."""
    from PIL import Image
    proofs = {}

    def tick(pid):
        request = out / "window-request.json"
        if not request.exists():
            return
        try:
            row = json.loads(request.read_text())
        except json.JSONDecodeError:  # writer has not closed its new packet yet
            return
        tag = row["phase"]
        if tag in proofs:
            return
        if row["pid"] != pid or not isinstance(row["window"], int) or row["window"] <= 0:
            raise RuntimeError("Rejected window request outside the owned child")
        if tag not in ("initial-map", "second-map", "resized", "map-return"):
            raise RuntimeError("Unknown window proof phase")
        path = out / f"os-window-{tag}.png"
        subprocess.run(["/usr/sbin/screencapture", "-x", "-o", "-l", str(row["window"]),
                        str(path)], check=True, timeout=15, capture_output=True)
        with Image.open(path) as raw:
            image = raw.convert("RGB")
        dpi = image.width / row["logicalWidth"]
        top = image.height - round(row["logicalHeight"] * dpi)
        if top < 0:
            raise RuntimeError("OS image does not fit the owned game window")
        stamp = 0
        for bit in range(32):
            red, green, _ = image.getpixel((int((bit * 2 + 1) * dpi), top + int(dpi)))
            # OS colour management can mix channels even for saturated RGB.
            if abs(red - green) <= 80:
                raise RuntimeError("OS window has no valid fresh-frame marker")
            if red > green:
                stamp += 2 ** bit
        if stamp < row["minimumStamp"]:
            raise RuntimeError("OS window contains a stale frame")
        region = image.crop((int(image.width * .2), top + int(row["logicalHeight"] * dpi * .2),
                             int(image.width * .8), top + int(row["logicalHeight"] * dpi * .7)))
        colours = len(region.getcolors(region.width * region.height) or [])
        if colours < minimum_colours:
            raise RuntimeError("OS window game area is blank")
        proofs[tag] = dict(freshFrameStamp=stamp, minimumFrameStamp=row["minimumStamp"],
                           centralColours=colours, colourProfile=colour_profile,
                           minimumColours=minimum_colours, screenshot=path.name, attempts=1)
        (out / f"window-{tag}.ok").write_text("PASS\n")
        print(f"Own OS window {tag}: PASS", flush=True)
    return tick, proofs


def preflight(love, run, identity, backend=None):
    """A texture-only pass must not hide a broken window/backbuffer capture."""
    source = run / "runtime-probe"
    source.mkdir()
    (source / "conf.lua").write_text('''function love.conf(t)
 t.version=love.getVersion()>=12 and "12.0" or "11.5"
 t.identity=os.getenv("POKEPORT_IDENTITY");t.window.title="Isolated GPU preflight"
 t.window.width=400;t.window.height=300
 if love.getVersion()>=12 and os.getenv("POKEPORT_GRAPHICS_BACKEND") then
  t.graphics.renderers={os.getenv("POKEPORT_GRAPHICS_BACKEND")}
 end
end
''')
    (source / "main.lua").write_text("package.path=" + json.dumps(str(ROOT) + "/?.lua;", ensure_ascii=False)
                                     + "..package.path\n" + r'''
local Frame=require("src.render.WindowFrame")
local n=0
function love.update() n=n+1;if n>180 then love.event.quit(1) end end
local function body()
 love.graphics.clear(1,0,0,1)
 love.graphics.setColor(0,1,0,1);love.graphics.circle("fill",200,150,100)
end
function love.draw()
 local capture
 if n==15 then capture=function(d)
  local r,g,b=d:getPixel(1,1)
  local a,version,vendor,device=love.graphics.getRendererInfo()
  local report={visible=r==1 and g==0 and b==0,
    renderer=a,version=version,vendor=vendor,device=device}
  local function quote(s)return '"'..s:gsub('\\','\\\\'):gsub('"','\\"')..'"' end
  local f=assert(io.open(os.getenv("PALETTE_GPU_OUT").."/probe.json","w"))
  f:write('{"visible":'..tostring(report.visible)..',"renderer":'..quote(a)..
   ',"version":'..quote(version)..',"vendor":'..quote(vendor)..',"device":'..quote(device)..'}')
  f:close();love.event.quit(report.visible and 0 or 1)
 end end
 Frame.draw(body,capture)
end
function love.quit()Frame.shutdown()end
''')
    env = environment(identity + "-probe", "emerald", run)
    if backend:
        env["POKEPORT_GRAPHICS_BACKEND"] = backend
    child(love, source, env, run / "probe.log", 30)
    report = json.loads((run / "probe.json").read_text())
    if not report["visible"]:
        raise RuntimeError("Window readback failed; texture-only results are insufficient")
    if backend and report["renderer"].lower() != backend:
        raise RuntimeError(f"Requested {backend}, but runtime uses {report['renderer']}")
    device = report["device"].lower()
    if not device or any(s in device for s in ("software", "llvmpipe", "swiftshader")):
        raise RuntimeError("A hardware GPU is required")
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--love", required=True, type=Path)
    parser.add_argument("--emerald", required=True, type=Path)
    parser.add_argument("--firered", required=True, type=Path)
    parser.add_argument("--out", type=Path, help="New, non-existing output folder")
    parser.add_argument("--backend", choices=("opengl", "metal"))
    parser.add_argument("--engine-ref", default="HEAD",
                        help="Engine commit/ref to export; acceptance driver stays in this checkout")
    parser.add_argument("--repeat-window-stamps", action="store_true",
                        help="With --async-window-frames, exercise verified identical-image reuse")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--window-frames", action="store_true",
                        help="Continuous frame/movement/resize tests; macOS OS proofs require Pillow")
    mode.add_argument("--async-window-frames", action="store_true",
                     help="Test actual deferred Cocoa frames, requires macOS --backend opengl and Pillow")
    mode.add_argument("--window-performance", action="store_true",
                     help="Uncapped native frame timings at two sizes, no timed observers/captures")
    args = parser.parse_args()
    window_mode = args.window_frames or args.async_window_frames or args.window_performance
    if args.repeat_window_stamps and not args.async_window_frames:
        parser.error("--repeat-window-stamps requires --async-window-frames")
    if args.async_window_frames and (sys.platform != "darwin" or args.backend != "opengl"):
        parser.error("--async-window-frames requires macOS --backend opengl")
    if window_mode and sys.platform == "darwin":
        try:
            import PIL.Image
        except ImportError:
            parser.error("Pillow is required for the own-window OS proofs")
    love = args.love.expanduser().resolve(strict=True)
    roms = {v: getattr(args, v).expanduser().resolve(strict=True) for v in TARGETS}
    hashes = {}
    for version, rom in roms.items():
        manifest = json.loads((ROOT / f"tools/rom_manifest_{version}.json").read_text())
        hashes[version] = hashlib.sha1(rom.read_bytes()).hexdigest()
        if hashes[version] != manifest["romSha1"]:
            parser.error(f"Unsupported {version} ROM revision")
    head = subprocess.check_output(["git", "rev-parse", "--verify", "--end-of-options",
                                    args.engine_ref + "^{commit}"], cwd=ROOT, text=True).strip()
    token = uuid.uuid4().hex
    run = (args.out or ROOT / ".local/palette-gpu" / ("run-" + token)).resolve()
    run.mkdir(parents=True, exist_ok=False)
    identity = "gen2-palette-gpu-" + token
    print(f"Fresh test artifacts: {run}", flush=True)
    gpu = preflight(love, run, identity, args.backend)
    print(f"Visible hardware GPU: {gpu['renderer']} / {gpu['device']}", flush=True)
    source = run / "source"
    source.mkdir()
    archive = subprocess.check_output(["git", "archive", head, "main.lua", "conf.lua",
                                       "src", "assets", "data", "tests", "tools"], cwd=ROOT)
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
        tar.extractall(source, filter="data")
    (source / "main.lua").rename(source / "engine_main.lua")
    (source / "main.lua").write_text(BOOTSTRAP)
    # The snapshot is the recorded engine revision; the candidate driver is
    # loaded explicitly from this checkout. No mods directory is exported.
    result = {"engineCommit": head, "gpu": gpu, "games": {}}
    private = {"source": str(source), "identities": {}}
    for version, (map_id, x, y) in TARGETS.items():
        out = run / version
        out.mkdir()
        game_identity = identity + "-" + version
        private["identities"][version] = game_identity
        env = environment(game_identity, version, out)
        if args.backend:
            env["POKEPORT_GRAPHICS_BACKEND"] = args.backend
        env.update(POKEPORT_IMPORT_ROM=str(roms[version]), POKEPORT_IMPORT_ONLY="1")
        print(f"{version}: full fresh import", flush=True)
        child(love, source, env, out / "import.log", 900)
        env.pop("POKEPORT_IMPORT_ROM"); env.pop("POKEPORT_IMPORT_ONLY")
        driver = (ROOT / "tools/window_frame_performance_driver.lua" if args.window_performance
                  else ROOT / "tools/gen3_async_window_frame_driver.lua" if args.async_window_frames
                  else ROOT / "tools/gen3_window_frame_driver.lua" if args.window_frames else DRIVER)
        env.update(POKEPORT_DRIVER=str(driver), PALETTE_GPU_ROM=str(roms[version]),
                   PALETTE_GPU_MAP=map_id, PALETTE_GPU_X=str(x), PALETTE_GPU_Y=str(y))
        if args.repeat_window_stamps:
            env["POKEPORT_TEST_STAMP_PERIOD"] = "4"
        print(f"{version}: real Game/Overworld GPU test", flush=True)
        tick, proofs = None, {}
        if window_mode and sys.platform == "darwin":
            tick, proofs = os_window_proof(out)
            env["POKEPORT_OS_WINDOW_PROOF"] = "1"
        child(love, source, env, out / "game.log",
              600 if window_mode else 180, tick)
        report = json.loads((out / "gpu.json").read_text())
        if not report.get("pass"):
            raise RuntimeError(f"{version}: acceptance report did not pass")
        if tick and len(proofs) != 4:
            raise RuntimeError("Incomplete OS window proofs")
        if proofs:
            report["osWindowProof"] = proofs
        if hashlib.sha1(roms[version].read_bytes()).hexdigest() != hashes[version]:
            raise RuntimeError(f"{version}: source ROM changed during test")
        result["games"][version] = report
        summary = (f"{sum(p['measuredFrames'] for p in report['phases'])} measured frames"
                   if args.window_performance else f"{report['checks']} checks")
        print(f"{version}: PASS ({summary})", flush=True)
    (run / "private-run.json").write_text(json.dumps(private, indent=2) + "\n")
    (run / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"PASS: {run / 'result.json'}", flush=True)


if __name__ == "__main__":
    main()
