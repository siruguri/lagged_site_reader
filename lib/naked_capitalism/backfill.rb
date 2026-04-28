# frozen_string_literal: true

require "time"

# Note: ApiClient and PostNormalizer are referenced lazily, so we don't
# `require` them here. Zeitwerk handles loading under Rails; the standalone
# smoke test requires all files in dependency order.

module NakedCapitalism
  # Walks the WP REST API backwards in time using a "before" cursor, calling
  # `persistor.call(normalized_post)` for each post, until reaching `until_time`.
  #
  # WordPress's default deep-pagination is capped at 10 pages; using a moving
  # `before` cursor instead of ?page=N keeps every request on page 1 and lets
  # us walk arbitrarily far back.
  #
  # The persistor is any object responding to `call(normalized_hash)`. Make it
  # idempotent on `wp_id` so re-runs are safe.
  class Backfill
    def initialize(api_client: ApiClient.new,
                   normalizer: PostNormalizer.new,
                   persistor:,
                   logger: nil)
      @api_client = api_client
      @normalizer = normalizer
      @persistor  = persistor
      @logger     = logger
    end

    # @param until_time [Time] stop once we encounter posts published at/before this
    # @param starting_before [Time, nil] start cursor (defaults to "now")
    # @return [Hash] summary stats
    def run(until_time:, starting_before: nil)
      cursor = (starting_before || Time.now.utc).utc
      until_time = until_time.utc
      total_seen = 0
      total_persisted = 0
      total_errors = 0

      loop do
        log("Fetching batch with before=#{cursor.iso8601}")
        result = @api_client.fetch_posts(before: cursor, per_page: ApiClient::MAX_PER_PAGE)
        posts  = result[:posts]
        break if posts.nil? || posts.empty?

        reached_cutoff = false
        posts.each do |raw|
          total_seen += 1
          begin
            normalized = @normalizer.normalize(raw)
            if normalized[:published_at] && normalized[:published_at] <= until_time
              log("Reached cutoff at #{normalized[:published_at].iso8601}; stopping.")
              reached_cutoff = true
              break
            end
            @persistor.call(normalized)
            total_persisted += 1
          rescue StandardError => e
            total_errors += 1
            log("Error on wp_id=#{raw['id']}: #{e.class}: #{e.message}")
          end
        end
        break if reached_cutoff

        # Advance cursor to (oldest post in this batch).date - 1s so we don't
        # re-fetch what we just saw and don't risk infinite loops.
        oldest_time = posts
          .map { |p| safe_parse(p["date_gmt"] || p["date"]) }
          .compact
          .min
        if oldest_time.nil?
          log("Could not determine oldest post date in batch; stopping.")
          break
        end

        new_cursor = oldest_time - 1
        if new_cursor >= cursor
          log("Cursor failed to advance (#{new_cursor} >= #{cursor}); stopping.")
          break
        end
        cursor = new_cursor

        break if cursor <= until_time
      end

      summary(total_seen, total_persisted, total_errors)
    end

    private

    def safe_parse(t)
      Time.parse(t.to_s).utc
    rescue ArgumentError, TypeError
      nil
    end

    def summary(seen, persisted, errors)
      { seen: seen, persisted: persisted, errors: errors }
    end

    def log(msg)
      return unless @logger
      @logger.respond_to?(:info) ? @logger.info(msg) : @logger.call(msg)
    end
  end
end
