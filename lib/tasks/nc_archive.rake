# frozen_string_literal: true

# Under Rails 8 with `config.autoload_lib`, classes under
# lib/naked_capitalism/ are autoloaded by Zeitwerk -- no explicit `require`
# needed. The :environment dependency below ensures Rails has booted.

require "logger"

namespace :nc_archive do
  desc "Healthcheck: confirm the WP REST API is reachable and returning posts."
  task healthcheck: :environment do
    logger = Logger.new($stdout)
    client = NakedCapitalism::ApiClient.new(logger: logger)
    if client.healthy?
      logger.info "OK -- API reachable, posts returned."
    else
      logger.error "FAIL -- API not returning posts. See log above."
      exit(1)
    end
  end

  desc "Backfill nakedcapitalism.com posts going back N months. Usage: rake nc_archive:backfill[6]"
  task :backfill, [:months] => :environment do |_, args|
    months = (args[:months] || 6).to_i
    until_time = months.months.ago
    logger = Logger.new($stdout)
    logger.info "Backfilling nakedcapitalism.com posts back to #{until_time}"

    backfill = NakedCapitalism::Backfill.new(
      api_client: NakedCapitalism::ApiClient.new(logger: logger),
      normalizer: NakedCapitalism::PostNormalizer.new,
      persistor:  NakedCapitalism::PostPersistor.new,
      logger:     logger
    )
    summary = backfill.run(until_time: until_time)
    logger.info "Done. Summary: #{summary.inspect}"
  end

  desc "Daily incremental crawl: fetch posts published since the most-recent archived post."
  task daily: :environment do
    logger = Logger.new($stdout)
    most_recent = Post.maximum(:published_at) || 7.days.ago
    logger.info "Daily crawl: fetching posts since #{most_recent}"

    backfill = NakedCapitalism::Backfill.new(
      api_client: NakedCapitalism::ApiClient.new(logger: logger),
      normalizer: NakedCapitalism::PostNormalizer.new,
      persistor:  NakedCapitalism::PostPersistor.new,
      logger:     logger
    )
    summary = backfill.run(until_time: most_recent)
    logger.info "Done. Summary: #{summary.inspect}"
  end
end
