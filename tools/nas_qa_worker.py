"""Serial, ROM-free QA inside the isolated NAS container. Roxas2712 contribution."""
import atexit
import fcntl
import json
import os
import resource
from pathlib import Path
import sys
import time

import qa_storage as qa

ROOT = Path(__file__).resolve().parents[1]


def tail(path, size=6000):
    with path.open('rb') as stream:
        stream.seek(max(0, path.stat().st_size - size))
        return stream.read(size).decode(errors='replace')


def isolation():
    cpus = sorted(os.sched_getaffinity(0))
    memory_file = next((p for p in (Path('/sys/fs/cgroup/memory.max'),
                                   Path('/sys/fs/cgroup/memory/memory.limit_in_bytes')) if p.is_file()), None)
    memory = int(memory_file.read_text()) if memory_file else 0
    swap_file = next((p for p in (Path('/sys/fs/cgroup/memory.swap.max'),
                                 Path('/sys/fs/cgroup/memory/memory.memsw.limit_in_bytes')) if p.is_file()), None)
    swap_limit = int(swap_file.read_text()) if swap_file else -1
    no_swap = swap_limit == (0 if swap_file and swap_file.name == 'memory.swap.max' else memory)
    limits = resource.getrlimit(resource.RLIMIT_NPROC)
    priority = os.getpriority(os.PRIO_PROCESS, 0)
    if len(cpus) != 1 or memory != 2 * 1024**3 or not no_swap or limits != (128, 128) or priority < 15:
        raise RuntimeError('NAS isolation limits were not enforced')
    return {'cpuAffinity': cpus, 'memoryBytes': memory, 'nproc': limits,
            'nice': priority, 'extraSwapBytes': 0, 'network': 'none'}


def main():
    os.chdir(ROOT)
    bounded = isolation()
    qa._storage = qa.Storage(ROOT)
    atexit.register(qa._storage.close)
    qa.qa_source(ROOT)
    lock = Path.home() / "serial.lock"
    lock.parent.mkdir(parents=True, exist_ok=True)
    with lock.open("a+") as lease:
        fcntl.flock(lease, fcntl.LOCK_EX | fcntl.LOCK_NB)
        paths = []
        for arg in sys.argv[1:]:
            path = Path(arg)
            if (path.is_absolute() or ".." in path.parts or path.suffix != ".lua"
                    or not path.parts or path.parts[0] != "tests" or not path.is_file()):
                raise ValueError("Expected an existing tests/*.lua suite: " + arg)
            paths.append(path)
        if not paths:
            raise ValueError("Specify at least one Lua test suite")
        out = qa.qa_cache(ROOT / ".local/qa" / ("nas-serial-" + str(time.time_ns())))
        out.mkdir(parents=True)
        (out / 'isolation.json').write_text(json.dumps(bounded, indent=2) + '\n')
        print('Isolation: ' + json.dumps(bounded), flush=True)
        results = []
        for index, path in enumerate(paths):
            if os.getloadavg()[0] >= 6:
                raise RuntimeError('NAS busy; remaining suites were not started')
            start = time.monotonic()
            with (out / (str(index) + ".log")).open("w") as log:
                result = qa.qa_run(["luajit", str(path)], cwd=ROOT,
                                   stdout=log, stderr=log, timeout=1800)
            row = {"suite": str(path), "exit": result.returncode,
                   "seconds": round(time.monotonic() - start, 3)}
            results.append(row)
            print(json.dumps(row), flush=True)
            print(tail(out / (str(index) + ".log")), flush=True)
            (out / "results.json").write_text(json.dumps(results, indent=2) + "\n")
            if result.returncode:
                return result.returncode
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
