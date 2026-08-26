# frozen_string_literal: true

namespace :utilities do
  desc <<~DESC
    Attach a local image file as an account's profile avatar.
      rake 'utilities:attach_avatar[/path/to/file.png,42]'         # uses whatever service the env is configured for (local disk in development)
      rake 'utilities:attach_avatar[/path/to/file.png,42,amazon]'  # force a specific service, e.g. to test S3 from development
  DESC
  task :attach_avatar, [:file_path, :account_id, :service_name] => :environment do |_, args|
    if args[:file_path].blank? || args[:account_id].blank?
      abort "Usage: rake 'utilities:attach_avatar[/path/to/file.png,42]'"
    end

    profile = Utilities::AvatarAttacher.call(
      file_path: args[:file_path],
      account_id: args[:account_id],
      service_name: args[:service_name].presence
    )
    puts "Attached #{args[:file_path]} as avatar for account #{args[:account_id]} (profile##{profile.id})"
    puts "Service: #{profile.avatar.blob.service_name}, blob key: #{profile.avatar.blob.key}, byte size: #{profile.avatar.blob.byte_size}"
  end
end
