# Deploying to a Ubuntu VPS via Docker

These notes target Ubuntu 24.04 LTS or 26.04 LTS, a single-user personal-tool
threat model, and a small VPS (1 vCPU / 1 GB RAM is enough). The app binds to
`127.0.0.1:3000` inside Docker; put Caddy or another reverse proxy in front
for HTTPS.

## Topology

```
                         +------------------+
   browser ---HTTPS-->   |  Caddy on :443   |
                         +--------+---------+
                                  |
                          reverse_proxy
                                  |
                         +--------v---------+         +-----------------+
                         |  web container   |  -----> |  redis (broker) |
                         |  (Puma :3000)    |         +-----------------+
                         +--------+---------+                  ^
                                  |                            |
                                  | reads/writes               |
                                  v                            |
                         +------------------+                  |
                         |  sqlite volume   |   <-- reads/writes
                         +------------------+                  |
                                                               |
                         +------------------+                  |
                         | sidekiq container| ------------------
                         +------------------+
```

## 1. Provision the VPS

Spin up Ubuntu 24.04 or 26.04 with SSH. Add an SSH key, disable password auth.

## 2. Bootstrap a non-root user (skip if you already have one)

```sh
ssh root@<vps>
adduser --disabled-password --gecos '' deploy
usermod -aG sudo deploy
mkdir -p /home/deploy/.ssh && cp /root/.ssh/authorized_keys /home/deploy/.ssh/
chown -R deploy:deploy /home/deploy/.ssh
exit
```

From here on, work as `deploy@<vps>`.

## 3. Update + install Docker

```sh
ssh deploy@<vps>
sudo apt update && sudo apt -y full-upgrade
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker deploy
exit          # re-login so the new group sticks

ssh deploy@<vps>
docker --version
docker compose version
```

## 4. Firewall

```sh
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status
```

The Rails app is exposed only on `127.0.0.1:3000`, so the public ports are
just for the reverse proxy. **Do not** open 3000 publicly.

## 5. Copy the project from your Mac

From your Mac, in the parent of the project folder:

```sh
rsync -av \
  --exclude '.git' \
  --exclude 'log/*'  --exclude 'tmp/*'  --exclude 'storage/*' \
  --exclude '.env'   --exclude 'config/master.key' \
  --exclude 'db/*.sqlite3*' \
  "naked capitalism archiver/" deploy@<vps>:/srv/nc-archiver/
```

`config/master.key` is excluded on purpose — you'll set it via `.env` so it's
not pinned to disk on the VPS.

## 6. Configure secrets, build, run

On your Mac:

```sh
cat "naked capitalism archiver/config/master.key"   # copy this value
```

On the VPS:

```sh
cd /srv/nc-archiver
cp .env.example .env
chmod 600 .env
nano .env                  # paste: RAILS_MASTER_KEY=<value>

docker compose build
docker compose up -d
docker compose ps
docker compose logs -f web    # Ctrl-C when you see "Listening on tcp://..."
```

The `web` service runs `bin/rails db:prepare` automatically on first start
via `bin/docker-entrypoint`, so the SQLite schema is created/migrated for you.

## 7. First backfill

```sh
docker compose exec web bin/rails 'nc_archive:backfill[6]'
```

After that, `sidekiq-scheduler` runs `nc_archive:daily` once a day at 04:15
UTC (configured in `config/sidekiq.yml`). Re-runs are idempotent on `wp_id`.

Quick sanity check via the dashboard:

```sh
curl -s http://127.0.0.1:3000/ | head
```

## 8. (Recommended) HTTPS with Caddy

Caddy auto-provisions Let's Encrypt certs on first request. Pointing your
domain's A/AAAA records at the VPS first.

```sh
sudo apt install -y caddy
sudo tee /etc/caddy/Caddyfile >/dev/null <<'EOF'
your.domain.com {
  reverse_proxy 127.0.0.1:3000
}
EOF
sudo systemctl reload caddy
sudo systemctl status caddy
```

Once HTTPS works end-to-end, enable SSL enforcement in
`config/environments/production.rb`:

```ruby
config.assume_ssl = true   # tell Rails the proxy already terminated TLS
config.force_ssl  = true   # 301 any plain-HTTP hits to HTTPS
```

Then on the VPS:

```sh
docker compose up -d --build
```

## 9. Backups

The whole archive is the SQLite file in the `sqlite_data` named volume.
Snapshot it periodically:

```sh
# project name = directory name unless you set COMPOSE_PROJECT_NAME.
# `docker volume ls` shows the actual prefixed name.
VOL=$(docker volume ls -q | grep sqlite_data)

docker run --rm -v "$VOL":/db -v /srv/backups:/out ubuntu:24.04 \
  tar czf "/out/nc-archiver-$(date +%F).tgz" -C /db .
```

Stash that tarball off-host (rclone, restic, scp to home, whatever you use).

## 10. Updating

```sh
# from your Mac, sync changed files:
rsync -av --delete \
  --exclude '.git' --exclude 'log/*' --exclude 'tmp/*' --exclude 'storage/*' \
  --exclude '.env' --exclude 'config/master.key' --exclude 'db/*.sqlite3*' \
  "naked capitalism archiver/" deploy@<vps>:/srv/nc-archiver/

# on the VPS:
cd /srv/nc-archiver
docker compose up -d --build
```

The web container's entrypoint will run any pending migrations on restart.

## Operations cheat sheet

```sh
# Logs (follow)
docker compose logs -f web
docker compose logs -f sidekiq
docker compose logs -f redis

# Shell into the web container
docker compose exec web bash
docker compose exec web bin/rails console

# Run a backfill task ad-hoc
docker compose exec web bin/rails 'nc_archive:backfill[10,2]'

# Force a daily crawl right now
docker compose exec web bin/rails nc_archive:daily

# Restart just one service
docker compose restart web
docker compose restart sidekiq

# Tear everything down (keeps volumes)
docker compose down

# Tear everything down INCLUDING volumes (nukes the archive!)
docker compose down -v
```

## Troubleshooting

**`web` keeps restarting / "couldn't decrypt config/credentials.yml.enc"**
→ `RAILS_MASTER_KEY` is missing or wrong. Copy `config/master.key` exactly
   from your Mac into `.env` on the VPS, then `docker compose up -d`.

**`web` boots but `/` shows nothing / 502 from Caddy**
→ Check `docker compose logs web`. Likely a missing migration; run
   `docker compose exec web bin/rails db:migrate`.

**Sidekiq logs show "Connection refused" against Redis**
→ The redis service didn't come up healthy in time. Run
   `docker compose ps redis` and `docker compose logs redis`.

**SQLite "database is locked"**
→ Should be rare given low write volume, but if it happens, lower Sidekiq
   concurrency in `config/sidekiq.yml` or migrate to Postgres.

**Volume permissions errors after switching VPS / restoring a backup**
→ `docker compose exec web sh -c 'ls -la db log storage'` — files should be
   owned by UID 1000. If not, restore as: `chown -R 1000:1000 <path>` from
   the host.
