#!/usr/bin/env python3
"""Build a mobile/console preview around the exact desktop engine payload."""
import argparse
import hashlib
import importlib.util
import json
import os
import plistlib
import re
import shutil
import struct
import subprocess
import tempfile
import zipfile
from pathlib import Path

from build_native_preview import RUNTIME_COMMIT, verify_payload
from stage_game_payload import stage

ROOT = Path(__file__).resolve().parents[1]
TOOLS_ROOT = ROOT
APP_ID = "de.roxas2712.gen2recomp.nativepreview"
APPLE_DEPENDENCIES_COMMIT = "a5522634f1e581a1ebab73bf3ab4bd7a853b7a3e"
ANDROID_CERT = "91ff1bad5d97a2cafd3da7ecf04a6b084792073dcd28df63db812a787cfb24ea"


def mobile_component(path, platform, destination=None):
    spec = importlib.util.spec_from_file_location('mobile_runtime_component', TOOLS_ROOT/'tools/mobile-runtime-check/component.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.install(path, platform, ROOT, destination)


def runtime_receipts(component, destination):
    """Preserve public proofs and notices alongside the linked runtime."""
    source = component.parent
    destination.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(component, destination/'component.json')
    shutil.copytree(source/'reports', destination/'reports', dirs_exist_ok=True)
    notices = list((source/'libraries').rglob('COPYRIGHT'))
    if not notices:
        raise ValueError('LuaJIT copyright notice missing from mobile component')
    shutil.copyfile(notices[0], destination/'COPYRIGHT-LuaJIT')


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def run(*args, **kwargs):
    return subprocess.run(args, cwd=ROOT, check=True, **kwargs)


def one(paths):
    paths = list(paths)
    if len(paths) != 1:
        raise ValueError("expected exactly one build product, found " + str(paths))
    return paths[0]


def verify_embedded(package, platform, payload):
    """Check delivered bytes, including the fused NRO's bounded RomFS region."""
    expected = Path(payload).read_bytes()
    with zipfile.ZipFile(package) as archive:
        if platform == "android":
            actual = archive.read("assets/game.love")
        elif platform == "ios":
            name = one(name for name in archive.namelist()
                       if re.fullmatch(r"Payload/[^/]+\.app/game\.love", name))
            info = plistlib.loads(archive.read(name.rsplit("/", 1)[0] + "/Info.plist"))
            if info.get("CFBundleIdentifier") != APP_ID:
                raise ValueError("iOS preview app identifier mismatch")
            actual = archive.read(name)
        elif platform == "windows":
            name = one(name for name in archive.namelist() if name.endswith("/Gen2Recomped-NativePreview.exe"))
            if not archive.read(name).endswith(expected):
                raise ValueError("Windows executable does not contain the frozen engine payload")
            actual = expected
        elif platform == "macos":
            name = one(name for name in archive.namelist() if name.endswith(".app/Contents/Resources/game.love"))
            actual = archive.read(name)
        else:
            name = one(name for name in archive.namelist() if name.endswith(".nro"))
            if name != "switch/gen2recomp-native-preview/Gen2Recomped-NativePreview.nro":
                raise ValueError("Switch preview must use its separate SD installation folder")
            nro = archive.read(name)
            if len(nro) < 0x80 or nro[0x10:0x14] != b"NRO0":
                raise ValueError("invalid fused Switch NRO")
            size = struct.unpack_from("<I", nro, 0x18)[0]
            if size < 0x80 or size + 56 > len(nro) or nro[size:size + 4] != b"ASET":
                raise ValueError("missing Switch asset header")
            offset, length = struct.unpack_from("<QQ", nro, size + 40)
            start, end = size + offset, size + offset + length
            if offset < 56 or length == 0 or start > len(nro) or end > len(nro):
                raise ValueError("invalid Switch RomFS bounds")
            if expected not in nro[start:end]:
                raise ValueError("Switch RomFS does not contain the frozen payload")
            actual = expected
    if actual != expected:
        raise ValueError("platform package changed the frozen engine payload")


def android(payload, target, version, component=None):
    env = {**os.environ, "GEN2_APPLICATION_ID": APP_ID, "GEN2_APP_NAME": "RetroRecomped Preview"}
    qualified = mobile_component(component, 'android') if component else None
    if component:
        runtime_receipts(component, ROOT/'mobile/android/app/src/embed/assets/runtime-qualification')
    run("bash", "scripts/build_android.sh", "--game-love", str(payload), "--version", version, env=env)
    apk = one((ROOT / "dist/android/debug").glob("*.apk"))
    sdk = Path(os.environ.get("ANDROID_HOME") or os.environ["ANDROID_SDK_ROOT"])
    tools = sorted((sdk / "build-tools").glob("*/apksigner"), key=lambda p: [int(x) for x in re.findall(r"\d+", p.parent.name)])
    signer = tools[-1]
    cert = run(str(signer), "verify", "--print-certs", str(apk), capture_output=True, text=True).stdout
    match = re.search(r"certificate SHA-256 digest:\s*([0-9a-fA-F]+)", cert)
    if not match or match.group(1).lower() != ANDROID_CERT:
        raise ValueError("APK signature does not match the committed test key")
    manifest = run(str(signer.parent / "aapt2"), "dump", "badging", str(apk), capture_output=True, text=True).stdout
    if not re.search(r"package: name='" + re.escape(APP_ID) + r"'", manifest):
        raise ValueError("APK preview application identifier mismatch")
    shutil.copyfile(apk, target)
    metadata = dict(runtime="vendored LÖVE Android 11.5a", runtimeCommit=None, signing="committed debug key", signingCertificate=ANDROID_CERT)
    if qualified:
        metadata['qualifiedRuntime'] = qualified
    return metadata


def ios(payload, target, version, release_id, component=None):
    env = {**os.environ, "GEN2_BUNDLE_ID": APP_ID, "LOVE_SOURCE_REF": RUNTIME_COMMIT,
           "APPLE_DEPENDENCIES_REF": APPLE_DEPENDENCIES_COMMIT}
    run("bash", "scripts/build_ios.sh", "--fetch", "--package-only", "--game-love", str(payload), "--version", version, env=env)
    source = ROOT / "mobile/ios/love-src"
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=source, text=True).strip()
    if commit != RUNTIME_COMMIT:
        raise ValueError("existing iOS sources do not match the pinned runtime; use a fresh build checkout")
    qualified = mobile_component(component, 'ios', source/'platform/xcode/ios/libraries/Lua.xcframework') if component else None
    with tempfile.TemporaryDirectory(prefix="preview-ios-") as temp:
        work = Path(temp)
        run("xcodebuild", "-project", str(source / "platform/xcode/love.xcodeproj"), "-target", "love-ios",
            "-configuration", "Release", "-sdk", "iphoneos", "-destination", "generic/platform=iOS",
            "SYMROOT=" + str(work / "Products"), "OBJROOT=" + str(work / "Intermediates"),
            "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO", "CODE_SIGN_IDENTITY=",
            "ONLY_ACTIVE_ARCH=NO", "PRODUCT_BUNDLE_IDENTIFIER=" + APP_ID,
            "MARKETING_VERSION=" + version, "CURRENT_PROJECT_VERSION=" + release_id,
            *(['OTHER_LDFLAGS=$(inherited) -Wl,-export_dynamic'] if component else []))
        app = one((work / "Products").rglob("*.app"))
        stage(payload, app / "game.love", version)
        if component:
            runtime_receipts(component, app/'runtime-qualification')
        info_path = app / "Info.plist"
        info = plistlib.loads(info_path.read_bytes())
        binary = app / info["CFBundleExecutable"]
        symbols = run("strings", "-a", str(binary), capture_output=True, text=True).stdout.splitlines()
        if not {"pickFile", "createFile"}.issubset(symbols):
            raise ValueError("iOS app is missing its native import/export bridge")
        info["CFBundleDisplayName"] = "RetroRecomped Preview"
        info["CFBundleName"] = "RetroRecomped Preview"
        for key in ("CFBundleURLTypes", "CFBundleDocumentTypes", "UTExportedTypeDeclarations", "UTImportedTypeDeclarations"):
            info.pop(key, None)
        info_path.write_bytes(plistlib.dumps(info))
        bundle = work / "Payload" / "Gen2Recomped-NativePreview.app"
        bundle.parent.mkdir()
        shutil.move(app, bundle)
        subprocess.run(["zip", "-qry", str(target), "Payload"], cwd=work, check=True)
    metadata = dict(runtime="LÖVE 12 iOS", runtimeCommit=RUNTIME_COMMIT,
                appleDependenciesCommit=APPLE_DEPENDENCIES_COMMIT, signing="unsigned; sideload signing required")
    if qualified:
        metadata['qualifiedRuntime'] = qualified
    return metadata


def switch(payload, target, version):
    run("bash", "scripts/switch/fetch_love_nx.sh")
    nro = ROOT / ".bazinga/work/Gen2Recomped-NativePreview.nro"
    run("bash", "scripts/switch/build_fused.sh", str(payload), version, str(nro))
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        prefix = "switch/gen2recomp-native-preview/"
        archive.write(nro, prefix + "Gen2Recomped-NativePreview.nro")
        archive.writestr(prefix + "INSTALL.txt", "Extract at the microSD root and launch the preview NRO from hbmenu.\n"
                         "Use full application memory via title takeover. This preview uses its own data profile.\n"
                         "Device acceptance, mod compatibility and extended-upvalue support are not yet established.\n")
    pins = {}
    for line in (ROOT / "scripts/switch/love-nx-11.5-nx1.sha256").read_text().splitlines():
        if line.strip() and not line.lstrip().startswith("#"):
            name, checksum = line.split()
            pins[name] = checksum
    return dict(runtime="LÖVE NX 11.5-nx1", runtimeCommit=None, runtimeSha256=pins, signing="homebrew NRO")


def main():
    global ROOT
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=("ios", "android", "switch"), required=True)
    parser.add_argument("--payload", type=Path, required=True)
    parser.add_argument("--release-id", required=True)
    parser.add_argument("--engine-version", required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--engine-root", type=Path, default=ROOT,
                        help="Committed engine checkout matching the frozen payload; build tools may be newer")
    parser.add_argument("--runtime-component", type=Path,
                        help="Qualified mobile component with passing matching stock/extended app-host gates")
    args = parser.parse_args()
    ROOT = args.engine_root.resolve(strict=True)
    component = args.runtime_component.resolve(strict=True) if args.runtime_component else None
    if component and args.platform == 'switch':
        parser.error('mobile Lua components support Android and iOS only')
    if not re.fullmatch(r"[0-9]{8}\.[0-9]+", args.release_id) or not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", args.engine_version):
        parser.error("expected YYYYMMDD.N release ID and X.Y.Z engine version")
    payload = args.payload.resolve()
    verify_payload(payload, args.engine_version)
    stage(payload, payload, args.engine_version)
    source = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    dirty = subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=no', '--',
                                    'main.lua', 'conf.lua', 'src', 'assets', 'data', 'mobile/android',
                                    'mobile/ios', 'scripts/build_android.sh', 'scripts/build_ios.sh'], cwd=ROOT, text=True)
    if dirty:
        raise ValueError('mobile host inputs must be committed before selecting a runtime')
    with zipfile.ZipFile(payload) as archive:
        release = json.loads(archive.read("src/preview/release.json"))
    identity = "Gen2Recomp-NativePreview-" + args.release_id.replace(".", "-")
    if release != dict(sourceCommit=source, releaseId=args.release_id, engineVersion=args.engine_version, previewIdentity=identity):
        raise ValueError("payload and platform build must use the same source, release and profile")
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    extension = dict(ios="ipa", android="apk", switch="zip")[args.platform]
    target = out / f"Gen2Recomped-NativePreview-{args.release_id}-{args.platform}.{extension}"
    if args.platform == "ios":
        runtime = ios(payload, target, args.engine_version, args.release_id, component)
    elif args.platform == "android":
        runtime = android(payload, target, args.engine_version, component)
    else:
        runtime = switch(payload, target, args.engine_version)
    verify_embedded(target, args.platform, payload)
    metadata = dict(**runtime, platform=args.platform, engineVersion=args.engine_version, sourceCommit=source,
                    buildToolsCommit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=TOOLS_ROOT,text=True).strip(),
                    previewIdentity=identity, payloadSha256=digest(payload), archiveSha256=digest(target),
                    archive=target.name, buildVerified=True, launchVerified=False, realDeviceVerified=False,
                    extendedUpvaluesQualified=bool(runtime.get('qualifiedRuntime')), modsIncluded=False, automaticInstallation=False)
    (out / "build.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(json.dumps(metadata, indent=2))


if __name__ == "__main__":
    main()
