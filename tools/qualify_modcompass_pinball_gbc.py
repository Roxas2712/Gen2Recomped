#!/usr/bin/env python3
"""ROM/account-free public GBC edition and live-fixture checks. By Roxas2712."""
import argparse
import atexit
from pathlib import Path
import shutil
import sys
ROOT=Path(__file__).resolve().parents[1]
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--php',default='php');p.add_argument('--php-runtime',type=Path,help='Pin a separately cached PHP/WASM runtime used by a wrapper');args=p.parse_args()
    executable=shutil.which(args.php)
    if not executable:p.error('Supply --php /path/to/php for the edition-contract test.')
    sys.path.insert(0,str(Path.home()/'.local/lib/origami-qa-storage/active-tools'))
    import qa_storage as q
    q._storage=q.Storage(ROOT);atexit.register(q._storage.close,collect=False)
    for source in(ROOT,Path(executable),Path(sys.executable)):q.qa_source(source)
    if args.php_runtime:q.qa_source(args.php_runtime)
    out=ROOT/'.local/qa/modcompass-pinball-gbc';q.qa_cache(out);out.mkdir(parents=True,exist_ok=True)
    for label,command in [('edition',[executable,str(ROOT/'tests/modcompass_pinball_gbc_test.php')]),
        ('fixture',[sys.executable,'-m','unittest','discover','-s','tests','-p','pinball_public_fixture_test.py'])]:
        with(out/(label+'.log')).open('w')as log:result=q.qa_run(command,cwd=ROOT,stdout=log,stderr=log,timeout=90)
        print((out/(label+'.log')).read_text(),flush=True)
        if result.returncode:return result.returncode
    return 0
if __name__=='__main__':raise SystemExit(main())
