#!/usr/bin/env python3
"""Refuse incomplete or mismatched preview builds before creating release files."""
import argparse
import json
import shutil
import subprocess
import zipfile
from pathlib import Path

from package_native_port import digest, verify_embedded
from build_native_preview import verify_payload, verify_mac_archive

ROOT = Path(__file__).resolve().parents[1]
REQUIRED_PLATFORMS = ("windows", "macos", "ios", "android", "switch")


def assemble(inputs, out, source, release_id, engine_version, require_macos_notarization=False):
    inputs, out = Path(inputs), Path(out)
    desktop = inputs / "native-preview-desktop"
    manifest = json.loads((desktop / "build-manifest.json").read_text())
    if (manifest["sourceCommit"], manifest["releaseId"], manifest["engineVersion"]) != (source, release_id, engine_version):
        raise ValueError("desktop release identity mismatch")
    payload = desktop / "Gen2Recomped-NativePreview.love"
    verify_payload(payload, engine_version)
    with zipfile.ZipFile(payload) as archive:
        release = json.loads(archive.read("src/preview/release.json"))
    identity = "Gen2Recomp-NativePreview-" + release_id.replace(".", "-")
    if release != dict(sourceCommit=source, releaseId=release_id, engineVersion=engine_version, previewIdentity=identity):
        raise ValueError("embedded payload identity mismatch")
    builds = list(manifest["builds"])
    for platform in ("ios", "android", "switch"):
        builds.append(json.loads((inputs / ("native-preview-" + platform) / "build.json").read_text()))
    if len(builds) != len(REQUIRED_PLATFORMS) or {b["platform"] for b in builds} != set(REQUIRED_PLATFORMS):
        raise ValueError("all five platforms must succeed before publication")
    payload_hash = digest(payload)
    packages = []
    for build in builds:
        platform = build["platform"]
        if (build["sourceCommit"], build["engineVersion"], build["payloadSha256"], build["previewIdentity"]) != (source, engine_version, payload_hash, identity):
            raise ValueError("source/payload/profile mismatch: " + platform)
        if build.get("buildVerified") is not True:
            raise ValueError("unverified platform build: " + platform)
        name = build["archive"]
        extension = dict(ios="ipa", android="apk").get(platform, "zip")
        if name != f"Gen2Recomped-NativePreview-{release_id}-{platform}.{extension}":
            raise ValueError("unexpected platform archive name")
        folder = desktop if platform in ("windows", "macos") else inputs / ("native-preview-" + platform)
        package = folder / name
        if digest(package) != build["archiveSha256"]:
            raise ValueError("archive checksum mismatch: " + platform)
        verify_embedded(package, platform, payload)
        if platform == 'macos':
            distribution = build.get('macosDistribution', {})
            if require_macos_notarization and (distribution.get('signing') != 'developer-id' or
                    any(distribution.get(key) is not True for key in
                        ('notarized', 'ticketStapled', 'gatekeeperVerified'))):
                raise ValueError('verified macOS notarization is required for publication')
            if distribution:
                if not distribution.get('iconSha256'):
                    raise ValueError('macOS application icon receipt missing')
                verify_mac_archive(package, distribution['iconSha256'])
        packages.append(package)
    # Validate every platform before writing a publishable output directory.
    out.mkdir(parents=True, exist_ok=False)
    for package in [payload, *packages]:
        shutil.copyfile(package, out / package.name)
    manifest.update(builds=builds, requiredPlatforms=list(REQUIRED_PLATFORMS))
    (out / "build-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    notes = (desktop / "README-Testrelease.txt").read_text()
    notes += """
Mobile and console test packages:
- Android APK: separately identified preview app; signed with the committed test key.
- iPhone/iPad IPA: unsigned device build; sign with a sideload tool or your Apple team before installing.
- Nintendo Switch ZIP: extract at the SD root; use the separate preview NRO in hbmenu with full application memory.
All five packages embed exactly the same engine payload and preview data identity.
Android uses vendored LOVE 11.5a, Switch uses pinned LOVE NX 11.5-nx1,
and iOS uses the pinned LOVE 12 source recorded in the build manifest.
The Switch preview does not include the stable channel's OTA updater.

Build verification is recorded separately from launch and physical-device evidence.
This publication does not claim a successful game session on a phone or console.
Mobile/console mod networking and extended-upvalue runtime qualification remain open.
"""
    (out / "README-Testrelease.txt").write_text(notes)
    files = sorted(out.iterdir())
    (out / "SHA256SUMS.txt").write_text("".join(digest(path) + "  " + path.name + "\n" for path in files))
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inputs", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--release-id", required=True)
    parser.add_argument("--engine-version", required=True)
    parser.add_argument("--require-macos-notarization", action="store_true")
    args = parser.parse_args()
    source = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    print(json.dumps(assemble(args.inputs, args.out, source, args.release_id, args.engine_version,
                              args.require_macos_notarization), indent=2))


if __name__ == "__main__":
    main()
