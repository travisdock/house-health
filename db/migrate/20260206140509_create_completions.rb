class CreateCompletions < ActiveRecord::Migration[8.1]
  def change
    create_table :completions do |t|
      t.references :task, null: false, foreign_key: true

      t.timestamps
    end

    add_index :completions, [ :task_id, :created_at ]
  end
end
