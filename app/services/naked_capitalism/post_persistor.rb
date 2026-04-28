# frozen_string_literal: true

module NakedCapitalism
  # Bridges a normalized-post hash (from PostNormalizer) to ActiveRecord.
  # Idempotent on `wp_id`: re-importing the same post updates the row in place,
  # which is exactly what we want for the daily incremental crawl + occasional
  # backfill overlap.
  class PostPersistor
    def call(normalized)
      post = Post.find_or_initialize_by(wp_id: normalized[:wp_id])
      post.assign_attributes(
        slug:                   normalized[:slug],
        url:                    normalized[:url],
        title:                  normalized[:title],
        post_type:              normalized[:post_type],
        classification_pattern: normalized[:classification_pattern],
        published_at:           normalized[:published_at],
        modified_at:            normalized[:modified_at],
        content_html:           normalized[:content_html],
        content_text:           normalized[:content_text],
        excerpt_html:           normalized[:excerpt_html],
        author_name:            normalized[:author_name],
        word_count:             normalized[:word_count],
        link_count:             normalized[:link_count]
      )
      post.categories = normalized[:categories]
      post.tags       = normalized[:tags]
      post.links      = normalized[:links]
      post.save!
      post
    end
  end
end
