# syntax=docker/dockerfile:1
#
# Two-stage Dockerfile:
#   1. `build` — installs build deps, runs bundle install + asset precompile
#   2. `runtime` — slim image with just the runtime libs, copies artifacts
#
# Pinned to the Ruby version in .ruby-version. Override at build time with:
#   docker build --build-arg RUBY_VERSION=3.3.5 .

ARG RUBY_VERSION=3.2.10
FROM ruby:${RUBY_VERSION}-slim AS base

WORKDIR /rails

# Production-friendly bundler config baked into the image.
ENV BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    RAILS_ENV="production"


# === build stage ============================================================
FROM base AS build

# Build deps for nokogiri (libxml2/libxslt), sqlite3, native gem compilation.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      pkg-config \
      libsqlite3-dev \
      libyaml-dev \
      libxml2-dev \
      libxslt-dev \
      libssl-dev \
      zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

# Install gems first (good Docker layer caching: gems rarely change relative
# to app code).
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Now the app source.
COPY . .

# Pre-load bootsnap caches for app/ and lib/, and precompile assets.
# SECRET_KEY_BASE_DUMMY=1 lets Rails 7+ run asset:precompile without needing
# the real master key during the build.
RUN bundle exec bootsnap precompile app/ lib/ && \
    SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile


# === runtime stage ==========================================================
FROM base AS runtime

# Runtime libs only (no -dev packages).
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      libsqlite3-0 \
      libxml2 \
      libxslt1.1 \
      tzdata && \
    rm -rf /var/lib/apt/lists/*

# Copy gems and the prepared app from the build stage.
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Non-root user. Pre-creating writable mount points before the chown means
# Docker named volumes mounted onto these paths inherit UID 1000 ownership
# on first use (volumes copy the directory's permissions on initialization).
RUN groupadd --system --gid 1000 rails && \
    useradd  --create-home --shell /bin/bash --uid 1000 --gid 1000 rails && \
    mkdir -p db log storage tmp/cache tmp/pids tmp/sockets public/assets && \
    chown -R rails:rails db log storage tmp public/assets

USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
