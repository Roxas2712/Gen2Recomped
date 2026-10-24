#!/usr/bin/env python3
"""Read-only retail-ROM palette import/pixel check; never writes game caches.

Usage: python3 tools/check_gen3_palette_programs.py --lua /path/to/luajit ROM.gba [ROM.gba ...]
Only BPEE/BPRE rev 0 profiles are accepted. Requires the source test fixtures,
not LÖVE, a running game, a player save or GPU access. JSON results go to stdout.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

from gen3_palette_profiles import profile_for_sha1

ROOT = Path(__file__).resolve().parents[1]


def check(path, lua):
    data = path.read_bytes()
    digest = hashlib.sha1(data).hexdigest()
    profile = profile_for_sha1(digest)
    if profile is None:
        raise ValueError(f"unsupported palette-program ROM digest: {digest}")
    # Pass the exact bytes we hashed, not a filename for a second file read.
    result = subprocess.run(
        [lua, "tools/gen3_palette_program_check.lua", profile["game"], digest],
        cwd=ROOT, input=data, capture_output=True, check=False,
    )
    output = result.stdout.decode("utf-8", errors="replace")
    lines = [s.removeprefix("PALETTE_ROM_RESULT ") for s in output.splitlines()
             if s.startswith("PALETTE_ROM_RESULT ")]
    if result.returncode or not lines:
        sys.stderr.write(output + result.stderr.decode("utf-8", errors="replace"))
        raise RuntimeError(f"palette import check failed for {profile['game']}")
    return json.loads(lines[-1])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("roms", type=Path, nargs="+")
    parser.add_argument("--lua", default="luajit")
    args = parser.parse_args()
    try:
        print(json.dumps([check(path, args.lua) for path in args.roms], indent=2))
    except (OSError, ValueError, RuntimeError) as exc:
        parser.exit(1, str(exc) + "\n")


if __name__ == "__main__":
    main()
