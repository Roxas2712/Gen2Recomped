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
import tarfile
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


def child(love, source, env, log, timeout):
    with log.open("w") as stream:
        process = subprocess.Popen([str(love), str(source)], cwd=source,
                                   env=env, stdout=stream, stderr=subprocess.STDOUT)
        try:
            code = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            # Only the process created here; no global process/window control.
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            raise RuntimeError(f"Test timed out; see {log}") from None
    if code:
        raise RuntimeError(f"Test exited {code}; see {log}")


def preflight(love, run, identity):
    """A texture-only pass must not hide a broken window/backbuffer capture."""
    source = run / "runtime-probe"
    source.mkdir()
    (source / "conf.lua").write_text('''function love.conf(t)
 t.version=love.getVersion()>=12 and "12.0" or "11.5"
 t.identity=os.getenv("POKEPORT_IDENTITY");t.window.title="Isolated GPU preflight"
 t.window.width=400;t.window.height=300
end
''')
    (source / "main.lua").write_text(r'''
local n=0
function love.update() n=n+1;if n>180 then love.event.quit(1) end end
function love.draw()
 love.graphics.clear(1,0,0,1)
 love.graphics.setColor(0,1,0,1);love.graphics.circle("fill",200,150,100)
 if n==15 then love.graphics.captureScreenshot(function(d)
  local r,g,b=d:getPixel(1,1)
  local a,version,vendor,device=love.graphics.getRendererInfo()
  local report={visible=r==1 and g==0 and b==0,
    renderer=a,version=version,vendor=vendor,device=device}
  local function quote(s)return '"'..s:gsub('\\','\\\\'):gsub('"','\\"')..'"' end
  local f=assert(io.open(os.getenv("PALETTE_GPU_OUT").."/probe.json","w"))
  f:write('{"visible":'..tostring(report.visible)..',"renderer":'..quote(a)..
   ',"version":'..quote(version)..',"vendor":'..quote(vendor)..',"device":'..quote(device)..'}')
  f:close();love.event.quit(report.visible and 0 or 1)
 end) end
end
''')
    env = environment(identity + "-probe", "emerald", run)
    child(love, source, env, run / "probe.log", 30)
    report = json.loads((run / "probe.json").read_text())
    if not report["visible"]:
        raise RuntimeError("Window readback failed; texture-only results are insufficient")
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
    args = parser.parse_args()
    love = args.love.expanduser().resolve(strict=True)
    roms = {v: getattr(args, v).expanduser().resolve(strict=True) for v in TARGETS}
    hashes = {}
    for version, rom in roms.items():
        manifest = json.loads((ROOT / f"tools/rom_manifest_{version}.json").read_text())
        hashes[version] = hashlib.sha1(rom.read_bytes()).hexdigest()
        if hashes[version] != manifest["romSha1"]:
            parser.error(f"Unsupported {version} ROM revision")
    token = uuid.uuid4().hex
    run = (args.out or ROOT / ".local/palette-gpu" / ("run-" + token)).resolve()
    run.mkdir(parents=True, exist_ok=False)
    identity = "gen2-palette-gpu-" + token
    print(f"Fresh test artifacts: {run}", flush=True)
    gpu = preflight(love, run, identity)
    print(f"Visible hardware GPU: {gpu['renderer']} / {gpu['device']}", flush=True)
    source = run / "source"
    source.mkdir()
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
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
        env.update(POKEPORT_IMPORT_ROM=str(roms[version]), POKEPORT_IMPORT_ONLY="1")
        print(f"{version}: full fresh import", flush=True)
        child(love, source, env, out / "import.log", 900)
        env.pop("POKEPORT_IMPORT_ROM"); env.pop("POKEPORT_IMPORT_ONLY")
        env.update(POKEPORT_DRIVER=str(DRIVER), PALETTE_GPU_ROM=str(roms[version]),
                   PALETTE_GPU_MAP=map_id, PALETTE_GPU_X=str(x), PALETTE_GPU_Y=str(y))
        print(f"{version}: real Game/Overworld GPU test", flush=True)
        child(love, source, env, out / "game.log", 180)
        report = json.loads((out / "gpu.json").read_text())
        if not report.get("pass"):
            raise RuntimeError(f"{version}: acceptance report did not pass")
        if hashlib.sha1(roms[version].read_bytes()).hexdigest() != hashes[version]:
            raise RuntimeError(f"{version}: source ROM changed during test")
        result["games"][version] = report
        print(f"{version}: PASS ({report['checks']} checks)", flush=True)
    (run / "private-run.json").write_text(json.dumps(private, indent=2) + "\n")
    (run / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"PASS: {run / 'result.json'}", flush=True)


if __name__ == "__main__":
    main()
