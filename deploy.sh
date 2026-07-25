#!/usr/bin/env bash

set -euo pipefail
export HOME=/home/deploy

cd /srv/everything_app

# Log everything with timestamps to a file deploy can write to
exec >> /srv/everything_app/deploy.log 2>&1
echo "===== $(date -Iseconds): deploy starting ====="

# Pull the latest main, discarding any local drift
git remote remove origin 2>/dev/null || true
git remote remove github_remote 2>/dev/null || true
git remote add github_remote https://github.com/siruguri/lagged_site_reader.git
git fetch --prune github_remote
git reset --hard github_remote/main

# Rebuild and restart
docker compose pull redis
docker compose up -d --build --remove-orphans

# Optional: prune dangling images so disk doesn't fill over time
docker image prune -f

echo "===== $(date -Iseconds): deploy finished ====="
