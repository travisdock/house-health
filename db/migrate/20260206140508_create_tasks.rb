class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.string :name
      t.integer :decay_period_days
      t.references :room, null: false, foreign_key: true

      t.timestamps
    end
  end
end
