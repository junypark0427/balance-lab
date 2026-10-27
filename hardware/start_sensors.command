#!/bin/sh
set -eu
cd "$(dirname "$0")"
if [ ! -x .venv/bin/python ]; then
  python3 -m venv .venv
fi
if ! .venv/bin/python -c 'import serial' >/dev/null 2>&1; then
  .venv/bin/python -m pip install -r bridge/requirements.txt
fi
exec .venv/bin/python bridge/bridge.py "$@"
