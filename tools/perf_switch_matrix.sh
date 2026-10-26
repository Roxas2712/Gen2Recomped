#!/usr/bin/env sh
# LUA and CHECKS override the runtime and checks. The shared storage guard
# owns each run's logs. Include defaults, all on, each off, and all off.
set -eu
exec python3 "$(dirname "$0")/performance_qualification.py" --matrix "$@"
