#!/usr/bin/env bash
#
# One-shot setup: turns this folder into a Rails 8 app while preserving the
# crawler classes already present here.
#
# What it does:
#   1. Sanity-checks ruby / bundler / rails
#   2. Stashes overlay files (Gemfile, README) that `rails new` would clobber
#   3. Runs `rails new .` with Rails 8 flags (sqlite3, no test/jbuilder/cable/
#      action-text/active-storage/solid)
#   4. Restores overlay; appends our gems (nokogiri, sidekiq, redis,
#      sidekiq-scheduler) to the new Gemfile
#   5. bundle install + db:create + db:migrate
#   6. Drops in the Sidekiq job and config/sidekiq.yml
#
# Idempotent-ish: if config/application.rb already exists, the script
# refuses to re-run rails new (you'd lose changes). Just delete the Rails
# files first if you really want to redo it.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_ROOT"

echo ">>> Setting up Rails 8 app in: $PROJECT_ROOT"
echo

# ---- 1. sanity checks ------------------------------------------------------
command -v ruby >/dev/null 2>&1 || { echo "ERROR: ruby not found. Install Ruby 3.2+ (rbenv/asdf)."; exit 1; }

ruby_version="$(ruby -e 'puts RUBY_VERSION')"
case "$ruby_version" in
  3.2.*|3.3.*|3.4.*|3.5.*|3.6.*) ;;
  *)
    echo "ERROR: Rails 8 needs Ruby >= 3.2. You have $ruby_version."
    echo "       Install a newer Ruby and retry (e.g. \`rbenv install 3.3.5\`)."
    exit 1
    ;;
esac
echo "    ruby:    $ruby_version"

if ! command -v bundle >/dev/null 2>&1; then
  echo "    bundler: not installed; running \`gem install bundler\`"
  gem install bundler --no-document
fi
echo "    bundler: $(bundle -v)"

if ! command -v rails >/dev/null 2>&1; then
  echo "    rails:   not installed; running \`gem install rails -v '~> 8.0'\`"
  gem install rails -v '~> 8.0' --no-document
fi
rails_version="$(rails -v | awk '{print $2}')"
echo "    rails:   $rails_version"
case "$rails_version" in
  8.*) ;;
  *)   echo "WARNING: this script targets Rails 8.x but found $rails_version. Continuing anyway." ;;
esac
echo

# ---- 2. refuse if the app already exists -----------------------------------
if [ -f config/application.rb ]; then
  echo "It looks like a Rails app already exists in $PROJECT_ROOT (config/application.rb is present)."
  echo "Refusing to clobber. To redo from scratch, remove the Rails-generated files first."
  exit 0
fi

# ---- 3. stash overlay files that `rails new` would overwrite ---------------
STASH_DIR="$PROJECT_ROOT/.archiver_stash"
rm -rf "$STASH_DIR"
mkdir -p "$STASH_DIR"
[ -f Gemfile ]   && mv Gemfile   "$STASH_DIR/Gemfile.archiver"
[ -f README.md ] && mv README.md "$STASH_DIR/README.archiver.md"
echo ">>> Stashed Gemfile + README into $STASH_DIR"
echo

# ---- 4. rails new ----------------------------------------------------------
# Skip flags chosen to keep the app focused on archiving:
#   --skip-test, --skip-jbuilder       -- no test framework / json builder
#   --skip-action-mailbox/text/cable   -- features we don't use
#   --skip-active-storage              -- we keep image URLs only, no uploads
#   --skip-solid                       -- we use Sidekiq instead of solid_queue
#   --skip-bundle                      -- we'll bundle install ourselves after
#                                          appending gems
#   --skip-kamal --skip-docker         -- no deploy plumbing for a personal tool
echo ">>> Running \`rails new\` ..."
rails new . \
  --force \
  --database=sqlite3 \
  --skip-test \
  --skip-jbuilder \
  --skip-action-mailbox \
  --skip-action-text \
  --skip-action-cable \
  --skip-active-storage \
  --skip-solid \
  --skip-kamal \
  --skip-docker \
  --skip-bundle
echo

# ---- 5. append our gems to the freshly generated Gemfile -------------------
cat >> Gemfile <<'GEMS'

# --- Naked Capitalism Archiver -----------------------------------
gem "nokogiri",          "~> 1.16"
gem "sidekiq",           "~> 7.0"
gem "redis",             "~> 5.0"
gem "sidekiq-scheduler", "~> 5.0"
# -----------------------------------------------------------------
GEMS
echo ">>> Appended archiver gems to Gemfile"

# ---- 6. restore the project README (Rails generated one of its own) -------
if [ -f "$STASH_DIR/README.archiver.md" ]; then
  if [ -f README.md ]; then
    mv README.md README.rails_default.md
  fi
  mv "$STASH_DIR/README.archiver.md" README.md
  echo ">>> Restored project README (Rails default kept as README.rails_default.md)"
fi
rm -rf "$STASH_DIR"
echo

# ---- 7. bundle install + migrations ---------------------------------------
echo ">>> bundle install"
bundle install
echo

echo ">>> bin/rails db:prepare"
bin/rails db:prepare
echo

# ---- 8. Sidekiq job + scheduler config ------------------------------------
mkdir -p app/jobs config

cat > app/jobs/naked_capitalism_daily_crawl_job.rb <<'JOB'
# frozen_string_literal: true

# Sidekiq job that runs the daily incremental crawl. Wired into a cron-style
# schedule via config/sidekiq.yml (sidekiq-scheduler).
class NakedCapitalismDailyCrawlJob
  include Sidekiq::Job
  sidekiq_options queue: "default", retry: 3

  def perform
    task = Rake::Task["nc_archive:daily"]
    task.reenable
    task.invoke
  end
end
JOB
echo ">>> Wrote app/jobs/naked_capitalism_daily_crawl_job.rb"

cat > config/sidekiq.yml <<'YML'
# Sidekiq config + sidekiq-scheduler entries. Run with:
#   bundle exec sidekiq -C config/sidekiq.yml
:concurrency: 5
:queues:
  - default

:scheduler:
  :schedule:
    naked_capitalism_daily_crawl:
      cron: "15 4 * * *"        # 04:15 UTC every day
      class: NakedCapitalismDailyCrawlJob
      description: "Daily incremental crawl of nakedcapitalism.com"
YML
echo ">>> Wrote config/sidekiq.yml"

# Make sure Rails loads the rake task and uses Sidekiq for ActiveJob (in case
# you Active-Job-ify things later).
if ! grep -q "config.active_job.queue_adapter" config/application.rb; then
  ruby -i -pe 'BEGIN { found = false }; if !found && $_ =~ /^(\s*)class Application < Rails::Application/; found = true; print; $_ = "    config.active_job.queue_adapter = :sidekiq\n"; end' config/application.rb || true
  echo ">>> Set ActiveJob adapter to :sidekiq in config/application.rb"
fi

echo
echo "============================================================"
echo "  Rails 8 app set up. Try these next:"
echo "============================================================"
echo "  bin/rails nc_archive:healthcheck         # confirm WP REST API is reachable"
echo "  bin/rails 'nc_archive:backfill[6]'       # backfill last 6 months"
echo "  bin/rails nc_archive:daily               # daily incremental"
echo
echo "To run the scheduler in the background:"
echo "  bundle exec sidekiq -C config/sidekiq.yml"
echo
echo "Standalone (no Rails) smoke-test of just the API + classifier:"
echo "  ruby bin/crawl_smoke_test.rb 7"
echo "============================================================"
