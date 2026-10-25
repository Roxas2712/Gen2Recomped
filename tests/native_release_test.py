"""ROM-free release assembly tests, using explicitly synthetic platform fixtures."""
import io
import json
import plistlib
import struct
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from qa_storage import qa_source
from assemble_native_release import assemble, REQUIRED_PLATFORMS
from package_native_port import APP_ID, digest, verify_embedded

qa_source(ROOT)


def zipped(entries):
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, data in entries.items():
            archive.writestr(name, data)
    return stream.getvalue()


def synthetic_nro(payload, include_payload_in_romfs=True):
    # Only a packaging fixture; this deliberately is not executable code.
    data = bytearray(0x80)
    data[0x10:0x14] = b"NRO0"
    struct.pack_into("<I", data, 0x18, len(data))
    assets = bytearray(56)
    assets[:4] = b"ASET"
    romfs = b"synthetic romfs\0" + (payload if include_payload_in_romfs else b"empty")
    struct.pack_into("<QQ", assets, 40, len(assets), len(romfs))
    return bytes(data + assets) + romfs


class CompleteRelease(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="release-contract-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        qa_source(self.root)
        self.inputs = self.root / "inputs"
        self.out = self.root / "release"
        self.source = "a" * 40
        self.release_id, self.version = "20261025.99", "1.2.3"
        self.identity = "Gen2Recomp-NativePreview-20261025-99"
        desktop = self.inputs / "native-preview-desktop"
        desktop.mkdir(parents=True)
        self.payload = desktop / "Gen2Recomped-NativePreview.love"
        entries = {name: b"return true" for name in (
            "main.lua", "conf.lua", "src/preview/main.lua", "src/preview/conf.lua", "src/core/NativePreview.lua")}
        entries["src/core/Version.lua"] = b'return {engine="1.2.3"}'
        entries["src/preview/release.json"] = json.dumps(dict(
            sourceCommit=self.source, releaseId=self.release_id, engineVersion=self.version,
            previewIdentity=self.identity)).encode()
        self.payload.write_bytes(zipped(entries))
        self.packages = {}
        self.builds = {}
        for platform in REQUIRED_PLATFORMS:
            folder = desktop if platform in ("windows", "macos") else self.inputs / ("native-preview-" + platform)
            folder.mkdir(exist_ok=True)
            extension = dict(ios="ipa", android="apk").get(platform, "zip")
            package = folder / f"Gen2Recomped-NativePreview-{self.release_id}-{platform}.{extension}"
            raw = self.payload.read_bytes()
            if platform == "android":
                data = {"assets/game.love": raw}
            elif platform == "ios":
                data = {"Payload/Preview.app/game.love": raw,
                        "Payload/Preview.app/Info.plist": plistlib.dumps({"CFBundleIdentifier": APP_ID})}
            elif platform == "windows":
                data = {"Preview/Gen2Recomped-NativePreview.exe": b"synthetic exe" + raw}
            elif platform == "macos":
                data = {"Preview.app/Contents/Resources/game.love": raw}
            else:
                data = {"switch/gen2recomp-native-preview/Gen2Recomped-NativePreview.nro": synthetic_nro(raw)}
            package.write_bytes(zipped(data))
            self.packages[platform] = package
            self.builds[platform] = dict(
                platform=platform, sourceCommit=self.source, engineVersion=self.version,
                previewIdentity=self.identity, payloadSha256=digest(self.payload), archiveSha256=digest(package),
                archive=package.name, buildVerified=True, launchVerified=False, realDeviceVerified=False)
            if platform not in ("windows", "macos"):
                (folder / "build.json").write_text(json.dumps(self.builds[platform]))
        self.desktop_manifest = desktop / "build-manifest.json"
        self.desktop_manifest.write_text(json.dumps(dict(
            sourceCommit=self.source, releaseId=self.release_id, engineVersion=self.version,
            builds=[self.builds["windows"], self.builds["macos"]])))
        (desktop / "README-Testrelease.txt").write_text("Synthetic fixture only.\n")

    def assemble(self):
        return assemble(self.inputs, self.out, self.source, self.release_id, self.version)

    def update_port(self, platform, **changes):
        self.builds[platform].update(changes)
        (self.packages[platform].parent / "build.json").write_text(json.dumps(self.builds[platform]))

    def test_all_platforms_required_and_device_claims_preserved(self):
        manifest = self.assemble()
        self.assertEqual(set(manifest["requiredPlatforms"]), set(REQUIRED_PLATFORMS))
        self.assertEqual(len(list(self.out.iterdir())), 9)
        for build in manifest["builds"]:
            self.assertFalse(build["launchVerified"])
            self.assertFalse(build["realDeviceVerified"])
        for line in (self.out / "SHA256SUMS.txt").read_text().splitlines():
            checksum, name = line.split("  ")
            self.assertEqual(digest(self.out / name), checksum)

    def test_missing_mobile_build_does_not_create_release_directory(self):
        (self.packages["ios"].parent / "build.json").unlink()
        with self.assertRaises(FileNotFoundError):
            self.assemble()
        self.assertFalse(self.out.exists())

    def test_platform_from_another_source_or_profile_is_rejected(self):
        for field in ("sourceCommit", "payloadSha256", "previewIdentity", "engineVersion"):
            with self.subTest(field=field):
                original = self.builds["android"][field]
                self.update_port("android", **{field: "different"})
                with self.assertRaisesRegex(ValueError, "mismatch"):
                    self.assemble()
                self.assertFalse(self.out.exists())
                self.update_port("android", **{field: original})

    def test_hash_and_success_flag_cannot_mask_a_changed_embedded_payload(self):
        self.packages["android"].write_bytes(zipped({"assets/game.love": b"different payload"}))
        self.update_port("android", archiveSha256=digest(self.packages["android"]))
        with self.assertRaisesRegex(ValueError, "changed"):
            self.assemble()
        self.assertFalse(self.out.exists())

    def test_damaged_package_and_archive_path_escape_are_rejected(self):
        self.update_port("ios", archiveSha256="0" * 64)
        with self.assertRaisesRegex(ValueError, "checksum"):
            self.assemble()
        self.update_port("ios", archive="../outside.ipa")
        with self.assertRaisesRegex(ValueError, "archive name"):
            self.assemble()
        self.assertFalse(self.out.exists())

    def test_payload_outside_switch_romfs_is_not_a_fused_game(self):
        path = self.root / "unfused.zip"
        path.write_bytes(zipped({"switch/gen2recomp-native-preview/Gen2Recomped-NativePreview.nro":
                                 synthetic_nro(self.payload.read_bytes(), False) + self.payload.read_bytes()}))
        with self.assertRaisesRegex(ValueError, "RomFS"):
            verify_embedded(path, "switch", self.payload)

    def test_switch_cannot_overwrite_stable_sd_installation(self):
        path = self.root / "stable.zip"
        path.write_bytes(zipped({"switch/gen2recomp/gen2recomp.nro": synthetic_nro(self.payload.read_bytes())}))
        with self.assertRaisesRegex(ValueError, "separate SD"):
            verify_embedded(path, "switch", self.payload)


if __name__ == "__main__":
    unittest.main()
