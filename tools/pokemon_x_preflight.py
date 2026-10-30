#!/usr/bin/env python3
"""Read-only Pokémon X / Zakuro preflight; never decrypt or extract game data.

This is a feasibility tool, not another supported GameVersion. Header checks
are necessary conditions for a boot test, not proof that a game is playable.
"""
import argparse
import atexit
import hashlib
import json
import os
import platform
from pathlib import Path
import shutil
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
POKEMON_X_USA = "0004000000055D00"
POKEMON_Y_USA = "0004000000055E00"
TITLES = {POKEMON_X_USA: "x", POKEMON_Y_USA: "y"}
UPSTREAM = {
    "zakuro": "e174910de5e7285581b153cbce05543efb135cd5",
    "3dsrecomp": "cec1270db38411f9c02d3f356fc3ed6c3f007424",
}


class InvalidDump(ValueError):
    pass


class Reader:
    def __init__(self, file):
        self.file = file
        self.size = file.seek(0, 2)

    def read(self, offset, size):
        if offset < 0 or size < 0 or offset + size > self.size:
            raise InvalidDump("Declared section extends beyond the file")
        self.file.seek(offset)
        data = self.file.read(size)
        if len(data) != size:
            raise InvalidDump("File changed or was truncated during inspection")
        return data

    def digest(self, offset, size):
        digest = hashlib.sha256()
        end = offset + size
        while offset < end:
            data = self.read(offset, min(1024 * 1024, end - offset))
            digest.update(data)
            offset += len(data)
        return digest.hexdigest()


def align64(value):
    return (value + 63) & ~63


def cia_executable(reader, header, verify_contents):
    # CIA layout: aligned header / certificates / ticket / TMD / contents.
    cert, ticket, tmd_size = struct.unpack_from("<III", header, 8)
    if not 0x200 <= tmd_size <= 8 * 1024 * 1024:
        raise InvalidDump("Invalid TMD size")
    bitmap = reader.read(0x20, 0x2000)
    tmd_offset = align64(align64(align64(0x2020) + cert) + ticket)
    tmd = reader.read(tmd_offset, tmd_size)
    signature = struct.unpack_from(">I", tmd)[0]
    body = {0x10000: 0x240, 0x10001: 0x140, 0x10002: 0x80,
            0x10003: 0x240, 0x10004: 0x140, 0x10005: 0x80}.get(signature)
    if body is None or len(tmd) < body + 0xA0:
        raise InvalidDump("Invalid TMD signature or truncated metadata")
    title = tmd[body + 0x4C:body + 0x54].hex().upper()
    if not title.startswith("00040000"):
        raise InvalidDump("CIA is not a base game")
    count = int.from_bytes(tmd[body + 0x9E:body + 0xA0], "big")
    records = body + 0x9C4
    if len(tmd) < records + count * 0x30:
        raise InvalidDump("Truncated TMD content records")
    offset = align64(tmd_offset + tmd_size)
    content_end = offset + struct.unpack_from("<Q", header, 0x18)[0]
    if content_end > reader.size:
        raise InvalidDump("Truncated CIA content area")
    contents, executable, seen = [], None, set()
    for i in range(count):
        record = tmd[records + i * 0x30:records + (i + 1) * 0x30]
        content_id, index, flags, size = struct.unpack_from(">IHHQ", record)
        if index in seen:
            raise InvalidDump("Duplicate CIA content index")
        seen.add(index)
        present = bool(bitmap[index // 8] & (0x80 >> (index % 8)))
        entry = {"index": index, "id": content_id, "present": present,
                 "size": size, "encrypted": bool(flags & 1)}
        if present:
            if offset + size > content_end:
                raise InvalidDump("CIA content exceeds declared content area")
            entry["offset"] = offset
            if verify_contents:
                actual = reader.digest(offset, size)
                entry["tmd_sha256_matches"] = actual == record[16:48].hex()
            if index == 0:
                executable = (offset, size, bool(flags & 1))
            offset = align64(offset + size)
        contents.append(entry)
    if executable is None:
        raise InvalidDump("CIA has no executable content")
    return executable, {"title_id": title, "contents": contents,
                        "title_version": int.from_bytes(tmd[body + 0x9C:body + 0x9E], "big")}


def inspect(path, verify_contents=False):
    path = Path(path)
    before = path.stat()
    with path.open("rb") as file:
        r = Reader(file)
        first = r.read(0, 0x200)
        cia = None
        if first[0x100:0x104] == b"NCSD":
            fmt = "NCSD"
            start, units = struct.unpack_from("<II", first, 0x120)
            base, available, outer_encrypted = start * 512, units * 512, False
            if base < 0x200:
                raise InvalidDump("Invalid executable partition offset")
        elif first[0x100:0x104] == b"NCCH":
            fmt = "NCCH"
            base, available, outer_encrypted = 0, r.size, False
        elif struct.unpack_from("<I", first)[0] == 0x2020:
            fmt = "CIA"
            (base, available, outer_encrypted), cia = cia_executable(r, first, verify_contents)
        else:
            raise InvalidDump("Not a CIA, NCSD cartridge or NCCH executable")
        result = {"format": fmt, "bytes": r.size, "cia": cia,
                  "outer_content_encrypted": outer_encrypted}
        if outer_encrypted:
            result.update(status="blocked", blockers=["cia_content_encrypted"])
        else:
            if base + available > r.size or available < 0x200:
                raise InvalidDump("Executable partition extends beyond file")
            h = r.read(base, 0x200)
            if h[0x100:0x104] != b"NCCH":
                raise InvalidDump("Executable content has no NCCH header")
            partition_size = int.from_bytes(h[0x104:0x108], "little") * 512
            if not 0x200 <= partition_size <= available:
                raise InvalidDump("Invalid NCCH partition size")
            flags = h[0x188:0x190]
            title = h[0x118:0x120][::-1].hex().upper()
            blockers, hashes = [], {}
            if title not in TITLES:
                blockers.append("not_pokemon_xy_usa")
            if cia and title != cia["title_id"]:
                blockers.append("cia_ncch_title_mismatch")
            no_crypto = bool(flags[7] & 4)
            for name, off, size, expected in [
                ("extended_header", 0x200, int.from_bytes(h[0x180:0x184], "little"), h[0x160:0x180]),
                ("exefs_superblock", int.from_bytes(h[0x1A0:0x1A4], "little") * 512,
                 int.from_bytes(h[0x1A8:0x1AC], "little") * 512, h[0x1C0:0x1E0]),
                ("romfs_superblock", int.from_bytes(h[0x1B0:0x1B4], "little") * 512,
                 int.from_bytes(h[0x1B8:0x1BC], "little") * 512, h[0x1E0:0x200]),
            ]:
                if size == 0:
                    hashes[name] = None
                elif size > 16 * 1024 * 1024 or off < 0x200 or off + size > partition_size:
                    raise InvalidDump("Invalid NCCH hash region: " + name)
                else:
                    hashes[name] = r.digest(base + off, size) == expected.hex()
            # Do not trust a cleared/set flag alone: verify the bytes that a
            # loader would need. Some tools leave misleading crypto flags.
            if not no_crypto and any(value is False for value in hashes.values()):
                blockers.append("ncch_encrypted_or_damaged")
            elif any(value is not True for value in hashes.values()):
                blockers.append("ncch_plaintext_integrity_failed")
            if cia and any(c.get("tmd_sha256_matches") is False for c in cia["contents"]):
                blockers.append("cia_content_integrity_failed")
            result.update(title_id=title, executable_offset=base,
                          product_code=h[0x150:0x160].rstrip(b"\0").decode("ascii", "replace"),
                          ncch_no_crypto=no_crypto, ncch_crypto_method=flags[3],
                          plaintext_hashes=hashes, blockers=blockers,
                          status="blocked" if blockers else "headers_verified_boot_untested")
        result["sha256"] = r.digest(0, r.size) if verify_contents else None
    after = path.stat()
    if (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns) != (
            after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns):
        raise InvalidDump("Input changed during inspection")
    return result


def host_status():
    return {"system": platform.system(), "architecture": platform.machine(),
            "cargo_available": bool(shutil.which("cargo")),
            "rustc_available": bool(shutil.which("rustc")),
            "clang_available": bool(shutil.which("clang")),
            "zakuro_available": bool(shutil.which("zakuro")),
            "3dsrecomp_available": bool(shutil.which("3dsrecomp")),
            "free_GiB": round(shutil.disk_usage(ROOT).free / 2**30, 3)}


def qa_manager(*, collect=True, bundled=False):
    if os.name == 'nt':
        from native_workspace import manager
        return manager(ROOT,collect=collect)
    installed = Path.home() / ".local/lib/origami-qa-storage/active-tools"
    sys.path.insert(0, str(installed if not bundled and installed.is_dir() else ROOT / "tools"))
    import qa_storage as qa
    qa._storage = qa.Storage(ROOT)
    atexit.register(qa._storage.close, collect=collect)
    return qa


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path)
    parser.add_argument("--verify-contents", action="store_true", help="Stream SHA-256 checks; no ROM copies")
    parser.add_argument("--report", type=Path, help="New JSON report file (must not exist)")
    args = parser.parse_args()
    # Reject source/output aliasing before any output file is opened.
    if args.report and (args.report.resolve() == args.rom.resolve() or args.report.exists()):
        parser.error("Report must be a new file, separate from the input")
    qa = qa_manager()
    qa.qa_source(args.rom)
    qa.qa_source(ROOT)
    report = {"upstream_revisions": UPSTREAM, "boot_test": "not_run",
              "recompilation": "not_run", "host": host_status()}
    try:
        report["input"] = inspect(args.rom, args.verify_contents)
    except (OSError, ValueError, struct.error) as error:
        report["input"] = {"status": "invalid", "error": str(error)}
    encoded = json.dumps(report, indent=2) + "\n"
    if args.report:
        qa.qa_cache(args.report)
        qa._storage.check_space()
        args.report.parent.mkdir(parents=True, exist_ok=True)
        with args.report.open("x") as file:
            file.write(encoded)
    print(encoded, end="")
    return 0 if report["input"]["status"] == "headers_verified_boot_untested" else 2


if __name__ == "__main__":
    sys.exit(main())
