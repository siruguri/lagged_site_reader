class CreateWritingPrompts < ActiveRecord::Migration[8.0]
  def change
    create_table :writing_prompts do |t|
      t.string :prompt, null: false
      t.date :prompt_on, null: false

      t.timestamps
    end

    add_index :writing_prompts, :prompt_on
  end
end
