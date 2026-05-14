# frozen_string_literal: true

class CreateCrawledUrls < ActiveRecord::Migration[8.1]
  def change
    create_table :crawled_urls do |t|
      t.string   :url,            null: false
      t.string   :status,         null: false, default: "pending"
      t.datetime :last_crawled_at
      t.integer  :crawl_attempts, null: false, default: 0
      t.integer  :http_status
      t.text     :error_message
      t.text     :metadata_json

      t.timestamps
    end

    add_index :crawled_urls, :url,    unique: true
    add_index :crawled_urls, :status
  end
end
