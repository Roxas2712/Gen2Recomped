#!/usr/bin/env python3
"""Experimental external 3DS backend entry point for the Gen2Recomp fork.

Game data, generated code and player saves stay in ignored local directories.
This does not register Pokémon X as a native Lua-engine GameVersion.
"""
import argparse
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import pokemon_xy_library as library

import pokemon_x_preflight as preflight
import pokemon_xy_runtime as runtime_bundle

ROOT = preflight.ROOT
WORK = ROOT / ".local/pokemon-x"
CACHE = ROOT / ".local/qa/pokemon-x-feasibility"
RUNTIME = None
RUNTIME_ID = None
RUNTIME_RELEASE = None


def runtime_path():
    app = WORK / "Pokemon X Backend.app/Contents/MacOS/zakuro"
    return app if platform.system() == "Darwin" and app.is_file() else WORK / "bin/zakuro"


def backend_environment():
    if RUNTIME is not None:
        return runtime_bundle.environment(RUNTIME, WORK)
    env = dict(os.environ)
    # Cranelift's info log dumps whole generated shader IRs.
    env.setdefault("RUST_LOG", "info,cranelift_jit=warn")
    config = WORK / "vulkan/environment.json"
    if platform.system() == "Darwin" and config.is_file():
        settings = json.loads(config.read_text())
        loader = Path(settings["loader_directory"])
        manifest = Path(settings["driver_manifest"])
        if not loader.is_dir() or not manifest.is_file():
            raise ValueError("Lokale Vulkan-Dateien fehlen; Backend-Einrichtung prüfen.")
        previous = env.get("DYLD_FALLBACK_LIBRARY_PATH", "")
        env["DYLD_FALLBACK_LIBRARY_PATH"] = str(loader) + (os.pathsep + previous if previous else "")
        env.setdefault("VK_ICD_FILENAMES", str(manifest))
    return env


def library_name(title=preflight.POKEMON_X_USA):
    extension = {"Darwin": "dylib", "Windows": "dll"}.get(platform.system(), "so")
    return title + "." + extension


def smoke_passed(output):
    interpreted = re.search(r"\| interpreted ([0-9.]+)%", output)
    return ("Completed after 300 frames in " in output
            and "fatal errors:" not in output
            and interpreted is not None and float(interpreted[1]) < 100)


def commands(action, rom, fingerprint, recompiler, runtime, title=preflight.POKEMON_X_USA):
    """Return argv arrays; never interpolate filenames into shell commands."""
    output = WORK / "recompiled" / fingerprint
    library = output / library_name(title)
    if action == "analyze":
        return [[str(recompiler), "analyze", str(rom)]]
    result = []
    if action == "build" or not library.is_file():
        result.append([str(recompiler), "build", str(rom), str(output)])
    if action in ("smoke", "play"):
        profile = CACHE / "smoke-profile" if action == "smoke" else WORK / "player"
        command = [str(runtime), str(rom), "--recompiled", str(library), "--data", str(profile)]
        if action == "smoke":
            command.extend(["--headless", "300", "--mute"])
        result.append(command)
    return result


def main(argv=None):
    global ROOT, WORK, CACHE, RUNTIME, RUNTIME_ID, RUNTIME_RELEASE
    RUNTIME = RUNTIME_ID = RUNTIME_RELEASE = library.RUNTIME_ID = None
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["import", "analyze", "build", "smoke", "play", "prepare", "status", "configure", "toggle-mods", "install-mod", "reset-language"])
    parser.add_argument("rom", type=Path, nargs="?")
    parser.add_argument("--edition", choices=["x", "y"], default="x")
    parser.add_argument("--root", type=Path, help="Host-selected writable backend workspace")
    parser.add_argument("--runtime-root", type=Path, help="Bundled native 3DS runtime")
    parser.add_argument("--play-after-import", action='store_true', help="Prepare and enter the normal device gate after importing")
    parser.add_argument("--worker-protocol", action='store_true', help=argparse.SUPPRESS)
    parser.add_argument("--detect-edition", action="store_true", help="Detect X/Y for a dropped game file")
    parser.add_argument("--set", action="append", default=[])
    parser.add_argument("--mod-source", type=Path)
    parser.add_argument("--skip-intro", action="store_true")
    parser.add_argument("--qa-profile", type=Path, help="Explicit isolated profile for interactive QA")
    parser.add_argument("--recompiler", type=Path, default=WORK / "bin/3dsrecomp")
    parser.add_argument("--runtime", type=Path, default=runtime_path())
    args = parser.parse_intermixed_args(argv)
    if args.root is not None:
        ROOT = args.root.resolve()
        WORK = ROOT / '.local/pokemon-x'
        CACHE = ROOT / '.local/qa/pokemon-x-feasibility'
        library.ROOT, library.WORK = ROOT, WORK
        preflight.ROOT = ROOT
        # Defaults were created before the host workspace was selected.
        if '--recompiler' not in (argv if argv is not None else sys.argv[1:]):
            args.recompiler = WORK / 'bin/3dsrecomp'
        if '--runtime' not in (argv if argv is not None else sys.argv[1:]):
            args.runtime = runtime_path()
    if args.runtime_root:
        try:
            RUNTIME, metadata = runtime_bundle.load(args.runtime_root)
            RUNTIME_RELEASE = metadata['id']
            RUNTIME_ID = library.RUNTIME_ID = metadata.get('compilation_id',metadata['id'])
            args.recompiler = RUNTIME/runtime_bundle.FILES['compiler']
        except (OSError, ValueError, KeyError) as error:
            print(str(error), file=sys.stderr)
            return 3
    if args.action == 'import':
        try:
            if args.rom is None:
                raise ValueError('Choose your own decrypted 3DS game file.')
            # Read-only verification does not create a second multi-GB ROM.
            edition = library.import_rom(args.rom, None if args.detect_edition else args.edition)
            print(json.dumps({'imported_edition': edition, 'library': library.status()}, ensure_ascii=False), flush=True)
            if not args.play_after_import:
                return 0
            if RUNTIME is None:
                raise ValueError('The native 3DS runtime is required to play after importing.')
            args.edition = edition
            args.action = 'build'
        except (OSError, ValueError) as error:
            print(str(error), file=sys.stderr)
            return 2
    if args.action == "status":
        print(json.dumps(library.status(), ensure_ascii=False))
        return 0
    if args.action == 'build' and not args.recompiler.is_file():
        print('The game file is imported, but the native 3DS compiler is not installed on this device.', file=sys.stderr)
        return 3
    qa = preflight.qa_manager(collect=args.action not in ("configure", "toggle-mods", "install-mod", "reset-language", "prepare"), bundled=RUNTIME is not None)
    entry = library.manifest().get(args.edition, {})
    rom = (args.rom or Path(entry.get("rom", WORK / "decrypted/pokemon-x-usa.cxi"))).resolve()
    for source in [ROOT, WORK, rom, args.recompiler, args.runtime]:
        qa.qa_source(source)
    # Even an existing library must not make an unreadable or wrong game
    # appear ready. Full hashes distinguish updates/modifications of a title.
    try:
        # A running game owns this lock too: changes take effect on the next
        # launch, never race an upstream settings save or move live mod files.
        import fcntl
        WORK.mkdir(parents=True, exist_ok=True)
        lock_path = (args.qa_profile / "prepare.lock") if args.action=="prepare" and args.qa_profile else WORK / "session.lock"
        lock_path.parent.mkdir(parents=True, exist_ok=True)
        with lock_path.open("a") as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                raise ValueError("Ein 3DS-Spiel oder ein anderer Bibliotheksvorgang läuft bereits.")
            result = execute(args, rom, qa)
            if result == 0 and args.play_after_import:
                args.action = 'prepare'
                return execute(args, rom, qa)
            return result
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(str(error), file=sys.stderr)
        return 2


def execute(args, rom, qa):
    try:
        if args.action in ("configure", "toggle-mods", "install-mod", "reset-language"):
            qa._storage.check_space()
            if args.action == "reset-language":
                library.reset_language(args.edition)
            elif args.action == "configure":
                changes = dict(item.split("=", 1) for item in args.set)
                library.configure(args.edition, {k: json.loads(v) for k, v in changes.items()})
            elif args.action == "toggle-mods":
                library.toggle_mods(args.edition)
            else:
                if not args.mod_source: raise ValueError("Mod-Quelle fehlt.")
                qa.qa_source(args.mod_source.resolve())
                print("Mod-Dateien importiert:", library.install_mod(args.edition, args.mod_source))
            print(json.dumps(library.status(), ensure_ascii=False))
            return 0
        result = preflight.inspect(rom, verify_contents=True)
        if result["status"] != "headers_verified_boot_untested":
            print("Pokémon X/Y kann mit dieser Datei noch nicht gestartet werden: " +
                  ", ".join(result["blockers"]) +
                  ". Benötigt wird ein vollständig entschlüsselter, intakter Dump.", file=sys.stderr)
            return 2
        title = result["title_id"]
        edition = preflight.TITLES[title]
        if edition != args.edition:
            raise ValueError("Dump und ausgewählte Edition stimmen nicht überein.")
        build_key = runtime_bundle.fingerprint(result['sha256'], RUNTIME_ID)
        if args.action == "prepare":
            binary = WORK / "recompiled" / build_key / library_name(title)
            bridge = RUNTIME/runtime_bundle.FILES['bridge'] if RUNTIME else WORK / "bin/libascendant_3ds_bridge.dylib"
            if not binary.is_file() or not bridge.is_file():
                raise ValueError("Eingebettetes 3DS-Backend wird noch vorbereitet.")
            if RUNTIME and not runtime_bundle.completed(binary, result['sha256'], RUNTIME_ID):
                raise ValueError('The native game library is incomplete or incompatible. Prepare this import again.')
            settings = library.settings(edition)
            data = args.qa_profile.resolve() if args.qa_profile else WORK / "player"
            if args.qa_profile:
                qa.qa_source(data)
                qa.qa_profile(data)
            qa._storage.check_space()
            language = {"japanese":0,"english":1,"french":2,"german":3,"italian":4,"spanish":5,"korean":7}
            report_dir=(data.parent / "device-tests") if args.qa_profile else WORK / "device-tests"
            report_dir.mkdir(parents=True, exist_ok=True)
            session = dict(rom=str(rom), library=str(binary), bridge=str(bridge), data=str(data),
                           session_lock=str((data / "session.lock") if args.qa_profile else WORK / "session.lock"),
                           resolution=settings["resolution"], language=language.get(settings["language"],1),
                           depth_3d=settings["depth_3d"], stereo=settings["stereo"], texture_packs=settings["texture_packs"],
                           settings=settings, edition=edition, root=str(ROOT), report_dir=str(report_dir))
            if RUNTIME:
                session.update(vulkan_loader=str(RUNTIME/runtime_bundle.FILES['loader']),
                               driver_manifest=str(RUNTIME/runtime_bundle.FILES['icd']))
            import hashlib
            with bridge.open("rb") as stream:
                bridge_hash=hashlib.file_digest(stream,"sha256").hexdigest()
            mod_signature=hashlib.sha256()
            mod_folder=library.disabled_dir(edition) if library.disabled_dir(edition).exists() else library.mod_dir(edition)
            for mod_file in sorted(mod_folder.rglob("*")):
                if mod_file.is_file():
                    info=mod_file.stat()
                    mod_signature.update(str((str(mod_file.relative_to(mod_folder)),info.st_size,info.st_mtime_ns)).encode())
            session["profile_key"]=json.dumps([platform.machine(),bridge_hash,RUNTIME_RELEASE,result["sha256"],settings["resolution"],settings["stereo"],settings["texture_packs"],mod_signature.hexdigest(),not library.disabled_dir(edition).exists()])
            print(json.dumps({"native_session":session,"library":library.status()}, ensure_ascii=False))
            return 0
        plan = commands(args.action, rom, build_key, args.recompiler.resolve(), args.runtime.resolve(), title)
        binary = WORK/'recompiled'/build_key/library_name(title)
        cached = bool(RUNTIME and runtime_bundle.completed(binary, result['sha256'], RUNTIME_ID))
        if args.play_after_import and cached:
            plan = []
        if args.qa_profile and args.action == "play":
            qa.qa_source(args.qa_profile)
            qa.qa_profile(args.qa_profile)
            command = plan[-1]
            command[command.index("--data") + 1] = str(args.qa_profile.resolve())
        from qa_build_storage import prepare as prepare_build, clean_linked_objects
        if args.action != 'analyze':prepare_build(qa._storage, WORK, build_key)
        if RUNTIME:
            qa._storage.limit_output(WORK/'compiler-cache',512*1024**2)
        if RUNTIME and plan:
            print(json.dumps({'progress':'Preparing your game. The first import can take several minutes.'}), flush=True)
        for command in plan:
            if not Path(command[0]).is_file() or not os.access(command[0], os.X_OK):
                print("Backend-Werkzeug fehlt: " + command[0], file=sys.stderr)
                return 3
        if args.action == "smoke":
            qa.qa_cache(CACHE)
        qa._storage.check_space()
        # Actual private build/player data is an input to later runs, not
        # disposable QA data. The smoke profile alone lives under QA control.
        if args.action != "analyze":
            (WORK / "recompiled" / build_key).mkdir(parents=True, exist_ok=True)
        for command in plan:
            env = backend_environment()
            config_dir = (CACHE / "settings" / edition) if args.action == "smoke" or args.qa_profile else (WORK / "settings" / edition)
            env["ZAKURO_CONFIG_DIR"] = str(config_dir)
            if args.action == "play" and command[0] == str(args.runtime.resolve()) and not args.skip_intro:
                intro = WORK / "Recompiled Ascendant.app/Contents/MacOS/love"
                if not intro.is_file(): raise ValueError("Ascendant-Intro-Laufzeit fehlt.")
                intro_env = dict(os.environ, ASCENDANT_ASSETS=str(WORK / "intro-assets"))
                intro_run = qa.qa_run([str(intro), str(ROOT / "tools/ascendant-intro")], cwd=ROOT, env=intro_env)
                if intro_run.returncode: return intro_run.returncode
            if args.action == "smoke" and command[0] == str(args.runtime.resolve()):
                # Upstream may exit 0 even when a title failed to load. Require
                # frame output and actual use of the recompiled library.
                process = qa.qa_run(command, cwd=ROOT, capture_output=True, text=True,
                                    timeout=180, env=dict(env, RUST_LOG="info,cranelift_jit=warn"))
                output = process.stdout + process.stderr
                print(output)
                CACHE.mkdir(parents=True, exist_ok=True)
                (CACHE / "backend-smoke.log").write_text(output)
                if process.returncode == 0 and not smoke_passed(output):
                    print("Kein erfolgreicher Recompile-Probelauf nachgewiesen.", file=sys.stderr)
                    return 4
            else:
                process = qa.qa_run(command, cwd=ROOT, env=env)
            if process.returncode:
                return process.returncode
            clean_linked_objects(WORK)
        if args.action in ("build", "smoke", "play"):
            if not binary.is_file() or binary.stat().st_size == 0:
                raise ValueError('The native 3DS build did not produce a game library.')
            if RUNTIME and not cached:
                runtime_bundle.finish(binary, result['sha256'], RUNTIME_ID)
            library.register(edition, rom, result["sha256"], binary)
            if args.play_after_import:
                print(json.dumps({'progress':'Native game prepared. Testing this device …'}), flush=True)
        if args.action == "smoke":
            print("Headless-Lauf beendet; Grafik, Eingaben und Story sind dadurch noch nicht abgenommen.")
        return 0
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(str(error), file=sys.stderr)
        return 2


if __name__ == "__main__":
    exit_code = main()
    if '--worker-protocol' in sys.argv:
        print(json.dumps({'backend_result':exit_code}), flush=True)
    sys.exit(exit_code)
