#!/usr/bin/env bash

# Kill simulator if running
if pgrep -x simulator >/dev/null 2>&1; then
  pkill -x simulator
fi

# Kill any running deploy.py (treat "not found" as success)
pkill -f 'bin/deploy/deploy.py'
code=$?
if [ $code -gt 1 ]; then
  exit $code   # real pkill error
else
  exit 0       # 0=killed, 1=none matched -> success
fi
