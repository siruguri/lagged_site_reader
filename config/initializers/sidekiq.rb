# frozen_string_literal: true

# Wire Sidekiq to the Redis URL from the environment. In Docker, this points
# at the redis service via REDIS_URL=redis://redis:6379/0; locally it falls
# back to a Redis on the host.
redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end
