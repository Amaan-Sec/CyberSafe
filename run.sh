#!/usr/bin/env bash
# Loads .env then starts the prototype backend.
set -e
cd "$(dirname "$0")"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

exec python3 server.py "$@"
