class CreateSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :submissions do |t|
      t.string :title, null: false
      t.text :content, null: false
      t.integer :status, null: false, default: 0
      t.integer :visibility, null: false, default: 0
      t.references :account, null: false, foreign_key: true

      t.timestamps
    end

    add_index :submissions, [:account_id, :created_at]
  end
end
