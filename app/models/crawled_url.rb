# frozen_string_literal: true

require "json"

class CrawledUrl < ApplicationRecord
  STATUSES = %w[pending in_progress success error disabled].freeze

  enum :status, STATUSES.index_by(&:itself), default: "pending"

  validates :url,    presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }

  scope :due_for_crawl, -> { where(status: %w[pending error]) }

  def metadata;       parse_json(metadata_json) || {}; end
  def metadata=(hash) self.metadata_json = (hash || {}).to_json; end

  private

  def parse_json(s)
    return nil if s.nil? || s.to_s.empty?
    JSON.parse(s)
  rescue JSON::ParserError
    nil
  end
end
