#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Standalone smoke test: crawls the last N days from nakedcapitalism.com and
# prints classified post titles. Does NOT persist anything.
#
# Use this BEFORE wiring into your Rails app to verify:
#   1. The WP REST API is reachable from your machine.
#   2. The classifier is correctly tagging "Links ..." / "Water Cooler" posts.
#   3. The link extractor sees a sensible number of outbound links per roundup.
#
# Usage:
#   bundle install   # picks up nokogiri (see Gemfile)
#   ruby bin/crawl_smoke_test.rb            # default: 7 days
#   ruby bin/crawl_smoke_test.rb 30         # 30 days
#
# Requires: ruby >= 3.0, nokogiri.

require "logger"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "naked_capitalism/api_client"
require "naked_capitalism/post_classifier"
require "naked_capitalism/link_extractor"
require "naked_capitalism/post_normalizer"
require "naked_capitalism/backfill"

days       = (ARGV[0] || "7").to_i
until_time = Time.now.utc - (days * 24 * 60 * 60)
logger     = Logger.new($stdout)

logger.info("Smoke test: crawling posts back to #{until_time}")
client = NakedCapitalism::ApiClient.new(logger: logger)

unless client.healthy?
  logger.error "API healthcheck failed. Aborting."
  exit(1)
end

counts = Hash.new(0)
samples = Hash.new { |h, k| h[k] = [] }

persistor = lambda do |p|
  counts[p[:post_type]] += 1
  if samples[p[:post_type]].size < 5
    samples[p[:post_type]] << "#{p[:published_at].strftime('%Y-%m-%d')} | #{p[:title]} (#{p[:link_count]} links, #{p[:word_count]} words)"
  end
end

backfill = NakedCapitalism::Backfill.new(
  api_client: client,
  normalizer: NakedCapitalism::PostNormalizer.new,
  persistor:  persistor,
  logger:     logger
)

summary = backfill.run(until_time: until_time)

puts
puts "=== Summary ==="
puts summary.inspect
puts
puts "=== Counts by type ==="
counts.each { |t, c| puts "  #{t}: #{c}" }
puts
puts "=== Samples ==="
samples.each do |type, lines|
  puts "-- #{type} --"
  lines.each { |l| puts "  #{l}" }
end
