# frozen_string_literal: true

require "json"

# An archived nakedcapitalism.com post.
#
# `categories`, `tags`, and `links` are stored as JSON-encoded TEXT for SQLite
# portability. The accessors below handle (de)serialization transparently.
class Post < ApplicationRecord
  POST_TYPES = %w[long_form links_roundup].freeze

  validates :wp_id,        presence: true, uniqueness: true
  validates :slug,         presence: true, uniqueness: true
  validates :title,        presence: true
  validates :url,          presence: true
  validates :post_type,    inclusion: { in: POST_TYPES }
  validates :published_at, presence: true

  scope :long_form,         -> { where(post_type: "long_form") }
  scope :links_roundup,     -> { where(post_type: "links_roundup") }
  scope :published_between, ->(from, to) { where(published_at: from..to) }

  # Reading-with-lag scope: matches posts old enough to surface, given a lag
  # window (default 4 months, per project goal of waiting before reading).
  scope :ready_to_read, ->(lag: 4.months) { where("published_at <= ?", Time.current - lag) }

  def categories;        parse_json(categories_json) || []; end
  def tags;              parse_json(tags_json) || [];       end
  def links;             parse_json(links_json) || [];      end

  def categories=(arr); self.categories_json = (arr || []).to_json; end
  def tags=(arr);       self.tags_json       = (arr || []).to_json; end
  def links=(arr);      self.links_json      = (arr || []).to_json; end

  private

  def parse_json(s)
    return nil if s.nil? || s.to_s.empty?
    JSON.parse(s)
  rescue JSON::ParserError
    nil
  end
end
