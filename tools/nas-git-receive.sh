#!/bin/sh
# Private SSH backup target; contributions by Roxas2712. See NOTICE.md.
set -eu
# DSM lacks CPU quotas. Restrict the receive process to the same one thread
# used for serial QA, lower its priority, and cap its virtual address space.
ulimit -v 2097152
exec /usr/bin/taskset -c 7 /usr/bin/nice -n 15 /usr/bin/git-receive-pack \
  "$HOME/recomp-qa/git/Gen2Recomped.git"
