# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_14_000001) do
  create_table "crawled_urls", force: :cascade do |t|
    t.integer "crawl_attempts", default: 0, null: false
    t.datetime "created_at", null: false
    t.text "error_message"
    t.integer "http_status"
    t.datetime "last_crawled_at"
    t.text "metadata_json"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["status"], name: "index_crawled_urls_on_status"
    t.index ["url"], name: "index_crawled_urls_on_url", unique: true
  end

  create_table "posts", force: :cascade do |t|
    t.string "author_name"
    t.text "categories_json"
    t.string "classification_pattern"
    t.text "content_html"
    t.text "content_text"
    t.datetime "created_at", null: false
    t.text "excerpt_html"
    t.integer "link_count", default: 0
    t.text "links_json"
    t.datetime "modified_at"
    t.string "post_type", null: false
    t.datetime "published_at", null: false
    t.datetime "read_at"
    t.string "slug", null: false
    t.text "tags_json"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.integer "word_count", default: 0
    t.bigint "wp_id", null: false
    t.index ["post_type"], name: "index_posts_on_post_type"
    t.index ["published_at"], name: "index_posts_on_published_at"
    t.index ["read_at"], name: "index_posts_on_read_at"
    t.index ["slug"], name: "index_posts_on_slug", unique: true
    t.index ["wp_id"], name: "index_posts_on_wp_id", unique: true
  end
end
