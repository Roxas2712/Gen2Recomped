#!/bin/sh
# On-demand isolated Linux QA; contributions by Roxas2712, see NOTICE.md.
set -eu
base="$HOME/recomp-qa"
job=${1:?Specify snapshot id, then test suites}
shift
case "$job" in ''|*[!a-zA-Z0-9_-]*) echo 'Invalid snapshot id' >&2; exit 2;; esac
[ "$#" -gt 0 ] || { echo 'Specify Lua suites' >&2; exit 2; }
[ -f "$base/jobs/$job/project/tools/nas_qa_worker.py" ]
mkdir -p "$base/state" "$base/jobs/$job/home"
# One run across all snapshots. flock is supplied by the existing verifier image.
image=$(cat "$base/image-id")
case "$image" in sha256:*) ;; *) echo 'Invalid pinned image' >&2; exit 2;; esac
load=$(cut -d ' ' -f 1 /proc/loadavg)
available=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
awk -v load_value="$load" -v available="$available" 'BEGIN {exit !(load_value < 6 && available > 6291456)}' || {
  echo 'NAS busy: retry when load < 6 and available RAM > 6 GiB' >&2; exit 75;
}
exec /usr/local/bin/docker run --rm --name gen2-serial-qa --init \
  --network none --read-only --cap-drop ALL --security-opt no-new-privileges \
  --user 1044:100 --cpuset-cpus 7 --cpu-shares 128 --memory 2g --memory-swap 2g \
  --ulimit nproc=128:128 --ulimit nofile=256:256 \
  --log-driver local --log-opt max-size=4m --log-opt max-file=2 \
  --tmpfs /tmp:rw,noexec,nosuid,size=64m \
  --mount "type=bind,src=$base/jobs/$job,dst=/qa" \
  --mount "type=bind,src=$base/state,dst=/state" \
  --env HOME=/qa --env PYTHONDONTWRITEBYTECODE=1 \
  --workdir /qa/project --entrypoint /bin/nice "$image" \
  -n 15 /usr/bin/flock -n /state/serial.lock python3 tools/nas_qa_worker.py "$@"
