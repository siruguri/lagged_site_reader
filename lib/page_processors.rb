# frozen_string_literal: true

require "uri"

module PageProcessors
  @registry = {}

  # Register a processor class for a domain.
  #   PageProcessors.register("example.com", PageProcessors::MyProcessor)
  def self.register(domain, processor_class)
    @registry[canonical(domain)] = processor_class
  end

  # Return a new processor instance for the given URL, falling back to Null.
  def self.for(url)
    host = URI.parse(url).host
    klass = (host && @registry[canonical(host)]) || Null
    klass.new
  rescue URI::InvalidURIError
    Null.new
  end

  def self.registry
    @registry.dup
  end

  def self.canonical(domain)
    domain.to_s.delete_prefix("www.").downcase
  end
  private_class_method :canonical
end
