# frozen_string_literal: true

module Utilities
  # Attaches a local image file as the avatar on an account's profile.
  # Meant for manually testing the Active Storage / S3 wiring end-to-end,
  # e.g. via `rake 'utilities:attach_avatar[/path/to/file.png,42]'`.
  class AvatarAttacher
    class Error < StandardError; end

    def self.call(file_path:, account_id:, service_name: nil)
      new(file_path: file_path, account_id: account_id, service_name: service_name).call
    end

    def initialize(file_path:, account_id:, service_name: nil)
      @file_path = file_path
      @account_id = account_id
      @service_name = service_name
    end

    def call
      raise Error, "No file at #{@file_path}" unless File.exist?(@file_path)

      account = Account.find(@account_id)
      profile = account.profile || account.create_profile!

      File.open(@file_path, "rb") do |file|
        attach_options = { io: file, filename: File.basename(@file_path) }
        attach_options[:service_name] = @service_name if @service_name.present?

        profile.avatar.attach(**attach_options)
      end

      profile
    end
  end
end
