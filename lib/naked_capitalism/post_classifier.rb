# frozen_string_literal: true

module NakedCapitalism
  # Classifies a post as :links_roundup or :long_form based on its title.
  #
  # nakedcapitalism.com's recurring roundup posts have very stable title prefixes:
  #   - "Links 4/26/2026"            -- daily morning links
  #   - "2:00PM Water Cooler"        -- afternoon links
  #   - "Antidote du jour ..."       -- standalone animal pic post
  #
  # Anything else is treated as long-form. Patterns are configurable so you
  # can tighten or loosen the heuristic without touching call sites.
  class PostClassifier
    DEFAULT_LINKS_ROUNDUP_PATTERNS = [
      /\ALinks\b/i,
      /\d{1,2}:\d{2}\s*[AP]M\s+Water\s+Cooler/i,
      /\bWater\s+Cooler\b/i,
      /\AAntidote\s+du\s+jour\b/i
    ].freeze

    LONG_FORM = :long_form
    LINKS_ROUNDUP = :links_roundup

    def initialize(patterns: DEFAULT_LINKS_ROUNDUP_PATTERNS)
      @patterns = patterns
    end

    # @param title [String] the decoded (HTML-entity-unescaped) post title
    # @return [Hash] { type: Symbol, matched_pattern: String|nil }
    def classify(title)
      title = title.to_s
      matched = @patterns.find { |re| title.match?(re) }
      if matched
        { type: LINKS_ROUNDUP, matched_pattern: matched.source }
      else
        { type: LONG_FORM, matched_pattern: nil }
      end
    end
  end
end
