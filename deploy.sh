#!/usr/bin/env bash

set -euo pipefail
export HOME=/home/deploy

cd /srv/lagged_newsreader

# Log everything with timestamps to a file deploy can write to
exec >> /srv/lagged_newsreader/deploy.log 2>&1
echo "===== $(date -Iseconds): deploy starting ====="

# Pull the latest main, discarding any local drift
git fetch --prune origin
git reset --hard origin/main

# Rebuild and restart
docker compose pull --ignore-buildable
docker compose up -d --build --remove-orphans

# Optional: prune dangling images so disk doesn't fill over time
docker image prune -f

echo "===== $(date -Iseconds): deploy finished ====="
