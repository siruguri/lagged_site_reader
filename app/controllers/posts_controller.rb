# frozen_string_literal: true

class PostsController < ApplicationController
  def index
    @total               = Post.count
    @oldest_published_at = Post.minimum(:published_at)
    @newest_published_at = Post.maximum(:published_at)
    @counts_by_type      = Post.group(:post_type).count
  end
end
