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

  desc <<~DESC
    Backfill nakedcapitalism.com posts. Two modes depending on how many args you pass.

      rake 'nc_archive:backfill[6]'       # one arg N: posts from NOW back to N months ago
      rake 'nc_archive:backfill[10,2]'    # two args [start, span]: a SPAN-month window
                                          # starting at START months ago and going
                                          # further back. [10,2] -> posts from 10
                                          # months ago to 12 months ago.

    For "posts from now back to whatever is already stored locally", use
    `nc_archive:daily` -- it uses Post.maximum(:published_at) as the cutoff.
  DESC
  task :backfill, [:start_months, :span_months] => :environment do |_, args|
    start_months = (args[:start_months] || 6).to_i
    span_months  = args[:span_months].to_i # 0 if absent

    abort "ERROR: start_months must be >= 0 (got #{start_months})" if start_months.negative?
    abort "ERROR: span_months must be >= 0 (got #{span_months})"   if span_months.negative?

    if span_months.positive?
      # Windowed mode: [start_months .. start_months + span_months] months ago.
      # Newer edge (where pagination starts) = start_months.months.ago
      # Older edge (where pagination stops)  = (start_months + span_months).months.ago
      starting_before = start_months.positive? ? start_months.months.ago : nil
      until_time      = (start_months + span_months).months.ago
      newer_edge_label = starting_before || Time.current
      mode_msg = "Windowed backfill: posts from #{newer_edge_label} (newer edge) " \
                 "back to #{until_time} (older edge)."
    else
      # Single-arg mode: from NOW back to start_months ago.
      if start_months.zero?
        abort "ERROR: with one arg, start_months must be > 0 (got 0). " \
              "If you want a window, pass a span as the second arg, e.g. " \
              "'nc_archive:backfill[0,2]'."
      end
      starting_before = nil
      until_time      = start_months.months.ago
      mode_msg = "Backfill: posts from now back to #{until_time}."
    end

    logger = Logger.new($stdout)
    logger.info mode_msg

    backfill = NakedCapitalism::Backfill.new(
      api_client: NakedCapitalism::ApiClient.new(logger: logger),
      normalizer: NakedCapitalism::PostNormalizer.new,
      persistor:  NakedCapitalism::PostPersistor.new,
      logger:     logger
    )
    summary = backfill.run(until_time: until_time, starting_before: starting_before)
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
