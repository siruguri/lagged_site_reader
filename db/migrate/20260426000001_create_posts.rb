# frozen_string_literal: true

class CreatePosts < ActiveRecord::Migration[7.2]
  def change
    create_table :posts do |t|
      t.bigint   :wp_id,                   null: false
      t.string   :slug,                    null: false
      t.string   :url,                     null: false
      t.string   :title,                   null: false
      t.string   :post_type,               null: false
      t.string   :classification_pattern
      t.datetime :published_at,            null: false
      t.datetime :modified_at
      t.text     :content_html
      t.text     :content_text
      t.text     :excerpt_html
      t.string   :author_name
      # SQLite does not have a native JSON type; store as TEXT and (de)serialize
      # in the model. Names end in _json so callers can access via the
      # convenience accessors `categories`, `tags`, `links`.
      t.text     :categories_json
      t.text     :tags_json
      t.text     :links_json
      t.integer  :word_count, default: 0
      t.integer  :link_count, default: 0
      t.timestamps
    end

    add_index :posts, :wp_id,        unique: true
    add_index :posts, :slug,         unique: true
    add_index :posts, :published_at
    add_index :posts, :post_type
  end
end
