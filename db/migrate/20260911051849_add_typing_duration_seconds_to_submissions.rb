class AddTypingDurationSecondsToSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :submissions, :typing_duration_seconds, :integer, null: false, default: 0
  end
end
