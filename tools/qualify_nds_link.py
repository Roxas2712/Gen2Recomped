#!/usr/bin/env python3
"""Exercise DS party reconstruction and link turns using caller-owned ROM data."""
import argparse
import os
from pathlib import Path
import sys
import time
from qa_storage import qa_source, qa_cache, qa_run

ROOT = Path(__file__).resolve().parents[1]

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--rom', type=Path, required=True)
    p.add_argument('--edition', choices=['platinum', 'black', 'white'], required=True)
    a = p.parse_args(); rom = a.rom.resolve(strict=True)
    for x in (ROOT, rom, Path(sys.executable), Path(os.environ['RETRO_QA_LUA_LIBRARY'])):
        qa_source(x)
    output = ROOT / '.local/qa' / ('retro-nds-link-' + str(time.time_ns()))
    qa_cache(output); output.mkdir(parents=True, mode=0o700)
    with (output / 'native.log').open('wb') as log:
        result = qa_run([sys.executable, str(ROOT / 'tools/run_lua_check.py'), str(ROOT / 'tests/drivers/nds_link_native.lua'), str(rom), a.edition], cwd=ROOT, stdout=log, stderr=log)
    assert result.returncode == 0, 'Native DS link qualification failed; inspect ' + str(output / 'native.log')
    print('NDS_LINK_PASS', a.edition, output, flush=True)

if __name__ == '__main__':
    main()
