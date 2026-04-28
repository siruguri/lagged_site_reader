# frozen_string_literal: true

require "nokogiri"
require "uri"

module NakedCapitalism
  # Extracts outbound links from rendered post HTML.
  #
  # Used heavily for "links roundup" posts where the body is mostly anchors,
  # but also useful on long-form posts as a citation/reference list.
  #
  # We do NOT follow these links -- per the project goal, we store URLs only,
  # not the content of the linked sites.
  class LinkExtractor
    INTERNAL_HOST_SUFFIX = "nakedcapitalism.com"

    def initialize(internal_host_suffix: INTERNAL_HOST_SUFFIX)
      @internal_host_suffix = internal_host_suffix.to_s.downcase
    end

    # @param html [String]
    # @return [Array<Hash>] each: { url:, anchor_text:, internal: }
    def extract(html)
      return [] if html.nil? || html.strip.empty?

      doc = Nokogiri::HTML.fragment(html)
      links = []
      doc.css("a[href]").each do |a|
        href = a["href"].to_s.strip
        next if href.empty?
        next if href.start_with?("#", "mailto:", "javascript:", "tel:")

        normalized = normalize_href(href)
        next unless normalized

        links << {
          url: normalized,
          anchor_text: a.text.to_s.strip,
          internal: internal?(normalized)
        }
      end
      links
    end

    private

    def normalize_href(href)
      uri = URI.parse(href)
      return nil unless uri.scheme.nil? || %w[http https].include?(uri.scheme)
      uri.to_s
    rescue URI::InvalidURIError
      nil
    end

    def internal?(url)
      uri = URI.parse(url)
      return false unless uri.host
      uri.host.downcase.end_with?(@internal_host_suffix)
    rescue URI::InvalidURIError
      false
    end
  end
end
