"""Open the standalone launcher preview without the game's save identity."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--love', default='love', help='Path to the LOVE executable')
args = parser.parse_args()
here = Path(__file__).resolve().parent
root = here.parent.parent
with tempfile.TemporaryDirectory(prefix='gen2-library-preview-') as folder:
    source = Path(folder)
    for name in ('main.lua', 'conf.lua'):
        shutil.copy2(here / name, source / name)
    for name in ('src', 'data', 'assets', 'mods'):
        if (root / name).exists():
            (source / name).symlink_to(root / name, target_is_directory=True)
    env = dict(os.environ, LIBRARY_PREVIEW_ROOT=str(root))
    raise SystemExit(subprocess.call([args.love, str(source)], cwd=root, env=env))
