# Naked Capitalism Archiver — Rails 8 app

Crawls nakedcapitalism.com via the WordPress REST API, classifies each post as
either long-form or links-roundup, and stores it in SQLite for later reading
(with a deliberate ~4-month lag) and statistical analysis.

## Quick start

You need **Ruby 3.2+** on your Mac. Then:

```sh
cd "naked capitalism archiver"
./setup_rails_app.sh
```

The setup script:

1. installs `bundler` and `rails ~> 8.0` if missing,
2. runs `rails new .` with sensible flags (sqlite3, no test/jbuilder/cable/
   action-text/active-storage/solid, no kamal/docker — it's a personal tool),
3. preserves the crawler classes already in this folder,
4. appends `nokogiri`, `sidekiq`, `redis`, `sidekiq-scheduler` to the Gemfile,
5. runs `bundle install` and `bin/rails db:prepare`,
6. drops in the Sidekiq job + `config/sidekiq.yml` schedule.

When it finishes, try:

```sh
bin/rails nc_archive:healthcheck         # confirms WP REST API is reachable
bin/rails 'nc_archive:backfill[6]'       # backfill last 6 months
bin/rails nc_archive:daily               # daily incremental crawl

# In a separate terminal, to run the scheduler:
bundle exec sidekiq -C config/sidekiq.yml
```

## Layout (after setup)

```
lib/naked_capitalism/                # plain-Ruby crawler classes (Zeitwerk-autoloaded)
  api_client.rb                      # WP REST client (Net::HTTP, retries, before-cursor pagination)
  post_classifier.rb                 # Title-pattern based: long_form vs links_roundup
  link_extractor.rb                  # Outbound URLs via Nokogiri
  post_normalizer.rb                 # Raw API payload -> plain hash for persistence
  backfill.rb                        # Walks API backwards using a `before` cursor

app/models/post.rb                                  # ActiveRecord
app/services/naked_capitalism/post_persistor.rb     # AR-backed persistor (idempotent on wp_id)
app/jobs/naked_capitalism_daily_crawl_job.rb        # Sidekiq job (created by setup script)

db/migrate/20260426000001_create_posts.rb           # SQLite-friendly schema
config/sidekiq.yml                                  # sidekiq-scheduler cron entry (created by setup)
lib/tasks/nc_archive.rake                           # rake nc_archive:{healthcheck,backfill,daily}

bin/crawl_smoke_test.rb                             # standalone runner, no Rails needed
setup_rails_app.sh                                  # one-shot Rails 8 bootstrapper
```

## Pre-flight smoke test (optional, no Rails)

If you want to confirm API access and classifier behaviour *before* setting up
Rails, you can run the standalone script:

```sh
gem install nokogiri --no-document
ruby bin/crawl_smoke_test.rb 7        # last 7 days
ruby bin/crawl_smoke_test.rb 30       # last 30 days
```

Expected output: HTTP request logs, then a summary like

```
=== Counts by type ===
  long_form: 18
  links_roundup: 14

=== Samples ===
-- links_roundup --
  2026-04-25 | Links 4/25/2026 (87 links, 412 words)
  2026-04-24 | 2:00PM Water Cooler 4/24/2026 (53 links, 1284 words)
  ...
```

Note: I couldn't independently verify `wp-json/wp/v2/posts` from my sandbox
(outbound was firewalled). The smoke test (or `nc_archive:healthcheck`) is
your first real check of the endpoint.

## Reading with a 4-month lag

The `Post.ready_to_read` scope encapsulates the lag:

```ruby
Post.ready_to_read(lag: 4.months).order(:published_at)   # default
Post.ready_to_read(lag: 6.weeks).long_form               # tighter window
Post.ready_to_read.links_roundup.where("link_count > ?", 50)
```

For statistical analysis, all posts are stored with `word_count`, `link_count`,
`post_type`, `published_at`, `author_name`, plus JSON arrays for `categories`,
`tags`, and `links` (each link: `{url, anchor_text, internal}`).

## Classifier patterns

Live in `NakedCapitalism::PostClassifier::DEFAULT_LINKS_ROUNDUP_PATTERNS`:

- `/\ALinks\b/i` — matches "Links 4/26/2026"
- `/\d{1,2}:\d{2}\s*[AP]M\s+Water\s+Cooler/i` — matches "2:00PM Water Cooler"
- `/\bWater\s+Cooler\b/i` — catch-all
- `/\AAntidote\s+du\s+jour\b/i`

Override via the constructor if you find titles that should/shouldn't match.

## What this does NOT do (yet)

- Doesn't fetch the targets of outbound links (by design — that's the whole
  point of choosing "store URLs only" for roundups).
- Doesn't store images locally — keeps remote URLs only, per your choice.
- No viewer UI — read via `bin/rails console` or any SQLite client; the raw
  archive is statistics-friendly.

## Re-running setup

`setup_rails_app.sh` refuses to clobber an existing Rails app. If you want to
nuke and redo, delete `config/application.rb` (and probably most of the
Rails-generated tree) before re-running.
