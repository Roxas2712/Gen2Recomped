"""Upload a source-only snapshot and run serial headless NAS QA on demand.

Contributions by Roxas2712; see NOTICE.md. No GitHub credentials are used.
"""
import argparse
import atexit
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tarfile
import time

import qa_storage as qa

ROOT = Path(__file__).resolve().parents[1]


def main():
    if sys.platform == 'darwin':
        os.environ.setdefault('DEVELOPER_DIR', '/Library/Developer/CommandLineTools')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="synology-codexdocker")
    parser.add_argument("--setup", action="store_true")
    parser.add_argument("suites", nargs="+")
    args = parser.parse_args()
    for suite in args.suites:
        path = Path(suite)
        if (path.is_absolute() or ".." in path.parts or path.suffix != ".lua"
                or not path.parts or path.parts[0] != "tests" or not (ROOT / path).is_file()):
            parser.error("Expected an existing tests/*.lua suite")
    qa._storage = qa.Storage(ROOT)
    atexit.register(qa._storage.close)
    qa.qa_source(ROOT)
    lease = (Path.home() / '.cache/origami-qa-storage/nas-qa-launch.lock').open('a+')
    fcntl.flock(lease, fcntl.LOCK_EX | fcntl.LOCK_NB)
    atexit.register(lease.close)
    job = "source-" + str(time.time_ns())
    out = qa.qa_cache(ROOT / ".local/qa" / ("nas-" + job))
    out.mkdir(parents=True)
    ssh = ["ssh", "-T", "-o", "BatchMode=yes", "-o", "ConnectTimeout=8", args.host]
    if args.setup:
        qa.qa_run(ssh + ["umask 077; mkdir -p ~/recomp-qa/jobs ~/recomp-qa/state; "
                         "/usr/local/bin/docker image inspect --format '{{.Id}}' "
                         "retrorecomped-verifier:20261027 > ~/recomp-qa/image-id"], check=True)
        qa.qa_run(ssh + ["cat > ~/recomp-qa/run-qa; chmod 700 ~/recomp-qa/run-qa"],
                  input=(ROOT / "tools/nas-qa-run.sh").read_bytes(), check=True)
    names = subprocess.check_output(["git", "ls-files", "-z", "src", "tests", "tools", "compat", "data/scripts", "examples", "assets/launcher/intro_score.json"],
                                    cwd=ROOT).decode().split("\0")
    names.extend(["tools/nas_qa_worker.py", "src/import/StreamFiles.lua",
                  "tests/engine/installer_streaming.lua"])
    # Include new source files from the requested feature branch as well.
    names.extend(subprocess.check_output(
        ["git", "ls-files", "--others", "--exclude-standard", "-z", "src", "tests", "tools"],
        cwd=ROOT).decode().split("\0"))
    allowed = {".lua", ".py", ".json", ".txt", ".md", ".sh", ".csv", ".tsv"}
    frozen = qa.qa_copy(out / 'source', ephemeral=True)
    frozen.mkdir()
    archive = frozen / "source.tar.gz"
    manifest = {}
    with tarfile.open(archive, "w:gz") as tar:
        for name in sorted(set(names)):
            path = ROOT / name
            if (not name or path.is_symlink() or not path.is_file()
                    or path.suffix.lower() not in allowed or path.stat().st_size > 8 * 1024**2):
                continue
            if any(part in {".local", ".git", "__pycache__", "generated"} for part in Path(name).parts):
                continue
            snapshot = frozen / name
            snapshot.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, snapshot)
            manifest[name] = hashlib.sha256(snapshot.read_bytes()).hexdigest()
            tar.add(snapshot, arcname="project/" + name, recursive=False)
    (out / "source-sha256.json").write_text(json.dumps(manifest, indent=2) + "\n")
    # The source archive contains only selected regular files from this checkout.
    remote = "~/recomp-qa/jobs/" + job
    usage = qa.qa_run(ssh + ["du -sk ~/recomp-qa/jobs"], capture_output=True, check=True)
    if int(usage.stdout.split()[0]) * 1024 + sum((ROOT / n).stat().st_size for n in manifest) > 4 * 1024**3:
        raise RuntimeError('NAS source snapshots reached their shared 4 GiB budget; retain evidence and use QA preservation before cleanup')
    with archive.open("rb") as stream:
        qa.qa_run(ssh + ["umask 077; mkdir -p " + remote + "; tar -xzf - -C " + remote],
                  stdin=stream, check=True)
    command = "~/recomp-qa/run-qa " + shlex.join([job, *args.suites])
    with (out / "run.log").open("w") as log:
        result = qa.qa_run(ssh + [command], stdout=log, stderr=subprocess.STDOUT, timeout=3600)
    with (out / "remote-evidence.tar.gz").open("wb") as evidence:
        fetched = qa.qa_run(ssh + ["tar -czf - -C " + remote + "/project .local/qa"],
                            stdout=evidence, stderr=subprocess.PIPE)
    print((out / "run.log").read_text()[-12000:])
    report = {"snapshot": job, "exit": result.returncode,
              "evidenceFetched": fetched.returncode == 0, "suites": args.suites,
              "files": len(manifest), "sourceArchiveSha256": hashlib.sha256(archive.read_bytes()).hexdigest()}
    (out / "deployment.json").write_text(json.dumps(report, indent=2) + "\n")
    print("Evidence:", out, flush=True)
    return result.returncode or fetched.returncode


if __name__ == "__main__":
    raise SystemExit(main())
