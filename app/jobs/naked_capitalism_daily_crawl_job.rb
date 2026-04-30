# frozen_string_literal: true

# Sidekiq-scheduled daily crawl. Pulls posts published since the most-recent
# archived post, idempotent on wp_id so partial-day re-runs are safe.
#
# Wired into a cron-style schedule via config/sidekiq.yml.
class NakedCapitalismDailyCrawlJob
  include Sidekiq::Job
  sidekiq_options queue: "default", retry: 3

  def perform
    logger      = Sidekiq.logger
    most_recent = Post.maximum(:published_at) || 7.days.ago
    logger.info "Daily crawl: fetching posts since #{most_recent}"

    backfill = NakedCapitalism::Backfill.new(
      api_client: NakedCapitalism::ApiClient.new(logger: logger),
      normalizer: NakedCapitalism::PostNormalizer.new,
      persistor:  NakedCapitalism::PostPersistor.new,
      logger:     logger
    )
    summary = backfill.run(until_time: most_recent)
    logger.info "Daily crawl done. Summary: #{summary.inspect}"
  end
end
