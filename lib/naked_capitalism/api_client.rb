# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module NakedCapitalism
  # Thin client for the WordPress REST API exposed by nakedcapitalism.com.
  # Intentionally minimal -- only the endpoints we need for archiving posts.
  #
  # The site is a standard WordPress install, so /wp-json/wp/v2/posts is the
  # canonical endpoint. Pagination uses a `before` cursor (rather than ?page=N)
  # to bypass WordPress's default 10-page hard limit on deep pagination.
  class ApiClient
    DEFAULT_BASE_URL   = "https://www.nakedcapitalism.com/wp-json/wp/v2"
    DEFAULT_USER_AGENT = "naked-capitalism-archiver/0.1 (personal archive)"
    MAX_PER_PAGE       = 100

    class Error < StandardError; end

    class HttpError < Error
      attr_reader :status, :body
      def initialize(status, body)
        @status = status.to_i
        @body   = body
        super("HTTP #{status}: #{body.to_s[0, 200]}")
      end
    end

    def initialize(base_url: DEFAULT_BASE_URL,
                   user_agent: DEFAULT_USER_AGENT,
                   request_delay_seconds: 1.0,
                   max_retries: 4,
                   logger: nil)
      @base_url              = base_url
      @user_agent            = user_agent
      @request_delay_seconds = request_delay_seconds
      @max_retries           = max_retries
      @logger                = logger
    end

    # Fetch a page of posts.
    #
    # @param per_page [Integer] 1..100
    # @param page    [Integer] 1-indexed; ignored when using `before` cursor pagination
    # @param before  [Time, String, nil] ISO8601 (or Time) cutoff -- returns posts published before this
    # @param after   [Time, String, nil] ISO8601 (or Time) cutoff -- returns posts published after this
    # @param order   ["asc","desc"]
    # @param orderby ["date","modified",...]
    # @param embed   [Boolean] include _embedded taxonomy & author info
    # @return [Hash] { posts: Array<Hash>, total_pages: Integer, total: Integer }
    def fetch_posts(per_page: MAX_PER_PAGE,
                    page: 1,
                    before: nil,
                    after: nil,
                    order: "desc",
                    orderby: "date",
                    embed: true)
      params = {
        "per_page" => per_page.clamp(1, MAX_PER_PAGE),
        "page"     => page,
        "order"    => order,
        "orderby"  => orderby
      }
      params["before"] = format_time(before) if before
      params["after"]  = format_time(after)  if after
      params["_embed"] = "true"              if embed

      response = http_get("/posts", params)
      {
        posts:       response[:body],
        total:       response[:headers]["x-wp-total"].to_i,
        total_pages: response[:headers]["x-wp-totalpages"].to_i
      }
    end

    # Quick liveness check -- fetches 1 post and returns true on HTTP 200 with a parseable body.
    # Useful as a first step before kicking off a long backfill.
    def healthy?
      result = fetch_posts(per_page: 1, embed: false)
      result[:posts].is_a?(Array) && !result[:posts].empty?
    rescue StandardError => e
      log("Healthcheck failed: #{e.class}: #{e.message}")
      false
    end

    private

    def format_time(t)
      t = Time.parse(t) if t.is_a?(String)
      t.utc.strftime("%Y-%m-%dT%H:%M:%S")
    end

    def http_get(path, params)
      uri       = URI.parse(@base_url + path)
      uri.query = URI.encode_www_form(params)

      attempts = 0
      first_attempt = true
      begin
        attempts += 1
        sleep(@request_delay_seconds) if first_attempt && @request_delay_seconds.to_f > 0
        first_attempt = false

        log("GET #{uri}")
        req = Net::HTTP::Get.new(uri)
        req["User-Agent"] = @user_agent
        req["Accept"]     = "application/json"

        res = Net::HTTP.start(uri.hostname, uri.port,
                              use_ssl: uri.scheme == "https",
                              open_timeout: 15,
                              read_timeout: 60) do |http|
          http.request(req)
        end

        status = res.code.to_i
        raise HttpError.new(status, res.body) if status >= 400

        {
          headers: res.each_header.to_h,
          body:    JSON.parse(res.body)
        }
      rescue HttpError => e
        if [429, 500, 502, 503, 504].include?(e.status) && attempts <= @max_retries
          backoff = 2**attempts
          log("Retryable HTTP #{e.status}; sleeping #{backoff}s (attempt #{attempts})")
          sleep(backoff)
          retry
        end
        raise
      rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, EOFError, SocketError => e
        if attempts <= @max_retries
          backoff = 2**attempts
          log("Network error #{e.class}: #{e.message}; retrying in #{backoff}s")
          sleep(backoff)
          retry
        end
        raise Error, "Network error after #{attempts} attempts: #{e.class}: #{e.message}"
      end
    end

    def log(msg)
      return unless @logger
      @logger.respond_to?(:info) ? @logger.info(msg) : @logger.call(msg)
    end
  end
end
