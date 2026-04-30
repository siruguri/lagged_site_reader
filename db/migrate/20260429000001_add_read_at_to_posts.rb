# frozen_string_literal: true

class AddReadAtToPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :posts, :read_at, :datetime
    add_index  :posts, :read_at
  end
end
