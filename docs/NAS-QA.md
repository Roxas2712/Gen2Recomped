# Serial NAS QA

Contributions by Roxas2712; existing project licences remain applicable.

The private NAS runs trusted source snapshots on demand. Git and pull requests
can stay on GitHub; no Actions runner, incoming port, account token, scheduled job or
paid runner is needed. The existing verifier image provides Python and LuaJIT.
Its image ID is pinned under the operator's private `~/recomp-qa/image-id`.

Install `tools/nas-qa-run.sh` as `~/recomp-qa/run-qa` on the NAS. A dedicated
snapshot lives at `~/recomp-qa/jobs/<id>/project`; upload only selected source and
test fixtures, never the checkout's `.git`, `.local`, credentials, imported ROMs,
models or saves. No existing service container is used to run suites.

Run over the existing SSH alias:

```sh
python3 tools/nas_qa.py --setup tests/engine/installer_streaming.lua
python3 tools/nas_qa.py tests/engine/gen3_event_link.lua tests/engine/unified_content.lua
ssh synology-codexdocker '~/recomp-qa/run-qa SNAPSHOT tests/engine/installer_streaming.lua'
```

The Python launcher freezes the selected source into a registered ephemeral QA
copy before uploading it. The preservation helper retains its exact bytes when
the local copy is removed. A shared 4 GiB bound limits retained NAS snapshots;
the launcher refuses more uploads at that limit, without deleting inputs.

The single temporary container is pinned to CPU thread 7 and limited to 2 GiB RAM,
including swap, with reduced CPU scheduling priority and an `nproc` limit of
128 for its UID. It also limits open file descriptors to 256.
Its root filesystem is read-only, network is disabled, privileges are dropped,
and only its dedicated snapshot and QA lock directory are mounted. There is no
Docker socket or personal NAS share inside. No container remains running after
the command exits. New starts refuse NAS load >= 6 or available RAM <= 6 GiB.
These bounds reduce interference; they cannot promise zero effect on disk I/O.
The DS1621+ kernel lacks CFS CPU quotas, so CPU affinity supplies the one-thread
bound instead of Docker's unsupported `--cpus` option.
The NAS also lacks Docker's PID cgroup and block-I/O controls; the process
limit uses `ulimit` instead, and no disk-throughput limit is claimed.

Both the container name and shared lock prevent concurrent runs. Suites run
sequentially through `qa_storage`, keeping the 20 GiB free-space reserve and QA
output budgets. Logs and exit results are in the snapshot's `.local/qa` folder.
Fetch them for review; do not delete source snapshots or evidence with broad
age-based cleanup. Stop only this QA container with `docker stop gen2-serial-qa`.

Linux headless suites do not replace native macOS/Windows, audio-device or GPU
checks. Do not run a local test at the same time. Public pull-request code must
be reviewed before copying it here; this is deliberately not an automatic
public-PR runner.

## Private Git target

An additional bare repository is available through the existing SSH account at
`recomp-qa/git/Gen2Recomped.git`. The local `nas` remote points to it; `origin`
continues to point to GitHub. `tools/nas-git-receive.sh` restricts receive-pack
to CPU thread 7, low priority and a 2 GiB virtual-memory limit. The repository
uses one compression thread, disables automatic GC, rejects non-fast-forward
updates and limits incoming packs to 1 GiB. No Git daemon or new port is opened.

After committing reviewed work, a backup push can use:

```sh
git -c gc.auto=0 -c pack.threads=1 -c pack.windowMemory=64m push nas HEAD
```

Pushes to this private NAS target do not trigger GitHub workflows. Do not run a
push during a QA measurement. The initial repository is empty until a push
succeeds; its existence alone does not mean GitHub history has been mirrored.
