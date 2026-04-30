# frozen_string_literal: true

class PostsController < ApplicationController
  # The reading lag: posts younger than this aren't shown in the by_type
  # listing. Default 6 months; overridable per-request via ?lag=N.
  DEFAULT_LAG_MONTHS = 6

  TYPE_LABELS = {
    "long_form"     => "Long-form posts",
    "links_roundup" => "Links roundups"
  }.freeze

  def index
    @total               = Post.count
    @oldest_published_at = Post.minimum(:published_at)
    @newest_published_at = Post.maximum(:published_at)
    @counts_by_type      = Post.group(:post_type).count
  end

  def by_type
    @post_type   = params[:post_type]
    @type_label  = TYPE_LABELS.fetch(@post_type, @post_type.to_s.humanize)
    @lag_months  = lag_months_param
    @cutoff      = @lag_months.months.ago
    @posts       = Post.where(post_type: @post_type)
                       .where("published_at <= ?", @cutoff)
                       .order(published_at: :asc)
    @hidden_count = Post.where(post_type: @post_type)
                        .where("published_at > ?", @cutoff)
                        .count
  end

  # Click-tracking endpoint. Used two ways:
  #   - Browser navigation (Accept: text/html): mark + 302 to source URL.
  #     This is the no-JS fallback path.
  #   - AJAX (Accept: application/json): mark + return JSON. The view's
  #     fetch() calls this so it can update row styling inline while
  #     target=_blank handles the new-tab navigation in parallel.
  # mark_as_read! is idempotent (preserves first read_at), so concurrent
  # paths are safe.
  def open
    post = Post.find(params[:id])
    post.mark_as_read!
    respond_to do |format|
      format.html { redirect_to post.url, allow_other_host: true }
      format.json { render json: { id: post.id, read_at: post.read_at&.iso8601 } }
    end
  end

  private

  def lag_months_param
    n = params[:lag].to_i
    n.positive? ? n : DEFAULT_LAG_MONTHS
  end
end
