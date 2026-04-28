# frozen_string_literal: true

require "cgi"
require "nokogiri"
require "time"

# Note: PostClassifier and LinkExtractor are referenced lazily (in default-arg
# constructors), so we don't `require` them here. Under Rails, Zeitwerk
# autoloads them. For the standalone smoke test, bin/crawl_smoke_test.rb
# requires all five files in dependency order before instantiation.

module NakedCapitalism
  # Converts a raw WP REST API post payload into a plain hash suitable for
  # persistence. Keeps the persistence layer (ActiveRecord, sqlite3, etc.)
  # decoupled from API specifics.
  #
  # Per the project requirement:
  #   - long-form posts: store the full HTML + plain-text body
  #   - links roundups : store the body too (it IS the curation), plus an
  #                      explicit list of extracted outbound links. We never
  #                      fetch the linked targets themselves.
  class PostNormalizer
    def initialize(classifier: PostClassifier.new,
                   link_extractor: LinkExtractor.new)
      @classifier     = classifier
      @link_extractor = link_extractor
    end

    # @param payload [Hash] one item from /wp/v2/posts response
    # @return [Hash] normalized post
    def normalize(payload)
      title_html   = payload.dig("title", "rendered").to_s
      title_text   = decode_and_strip(title_html)
      content_html = payload.dig("content", "rendered").to_s
      excerpt_html = payload.dig("excerpt", "rendered").to_s
      content_text = strip_html(content_html)

      classification = @classifier.classify(title_text)
      links          = @link_extractor.extract(content_html)
      categories, tags = embedded_taxonomy_names(payload)

      {
        wp_id:                  payload["id"],
        slug:                   payload["slug"],
        url:                    payload["link"],
        title:                  title_text,
        post_type:              classification[:type].to_s,
        classification_pattern: classification[:matched_pattern],
        published_at:           parse_time(payload["date_gmt"] || payload["date"]),
        modified_at:            parse_time(payload["modified_gmt"] || payload["modified"]),
        content_html:           content_html,
        content_text:           content_text,
        excerpt_html:           excerpt_html,
        author_name:            embedded_author_name(payload),
        categories:             categories,
        tags:                   tags,
        links:                  links,
        word_count:             content_text.split(/\s+/).reject(&:empty?).size,
        link_count:             links.size
      }
    end

    private

    def parse_time(t)
      return nil if t.nil? || t.to_s.empty?
      Time.parse(t.to_s)
    rescue ArgumentError
      nil
    end

    def decode_and_strip(s)
      CGI.unescapeHTML(strip_html(s)).strip
    end

    def strip_html(s)
      return "" if s.nil?
      Nokogiri::HTML.fragment(s).text
    end

    def embedded_taxonomy_names(payload)
      embedded_terms = payload.dig("_embedded", "wp:term") || []
      categories = []
      tags = []
      embedded_terms.each do |group|
        Array(group).each do |term|
          case term["taxonomy"]
          when "category" then categories << term["name"]
          when "post_tag" then tags << term["name"]
          end
        end
      end
      [categories.uniq, tags.uniq]
    end

    def embedded_author_name(payload)
      authors = payload.dig("_embedded", "author") || []
      first = Array(authors).first
      first && first["name"]
    end
  end
end
