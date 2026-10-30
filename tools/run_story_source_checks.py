"""Run the ROM-free interrupted-checkpoint regression with QA storage guards."""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
from pathlib import Path
import argparse
import atexit
from datetime import datetime, timezone
import os
import sys

ROOT=Path(__file__).resolve().parents[1]
helper=Path.home()/'.local/lib/origami-qa-storage/active-tools'
sys.path.insert(0,str(helper if (helper/'qa_storage.py').is_file()else ROOT/'tools'))
import qa_storage


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--deadline-utc',type=datetime.fromisoformat)
    args=parser.parse_args()
    remaining=60
    if args.deadline_utc:
        assert args.deadline_utc.utcoffset().total_seconds()==0, 'Explicit UTC deadline required'
        remaining=min(remaining,(args.deadline_utc-datetime.now(timezone.utc)).total_seconds())
    assert remaining>0, 'Resource slot expired'
    qa_storage._storage=qa_storage.Storage(ROOT)
    atexit.register(qa_storage._storage.close)
    for source in (ROOT,Path(__file__),Path(sys.executable),ROOT/'tests/test_story_frozen_sources.py',ROOT/'tools/story_frozen_sources.py',
                   ROOT/'tests/test_story_save_operator.py',ROOT/'tools/story_save_operator.py'):
        qa_storage.qa_source(source)
    out=ROOT/'.local/qa'/('story-source-checks-'+datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S%f'))
    qa_storage.qa_cache(out);out.mkdir(parents=True)
    env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1',STORY_QA_TEST_TEMP=str(out))
    if args.deadline_utc:
        remaining=min(remaining,(args.deadline_utc-datetime.now(timezone.utc)).total_seconds())
        assert remaining>0, 'Resource slot expired during preparation'
    with (out/'tests.log').open('wb')as log:
        result=qa_storage.qa_run([sys.executable,'-m','unittest','discover','-s','tests',
            '-p','test_story_*.py','-v'],cwd=ROOT,env=env,stdout=log,stderr=log,timeout=remaining)
    print((out/'tests.log').read_text(),flush=True)
    return result.returncode


if __name__=='__main__':raise SystemExit(main())
