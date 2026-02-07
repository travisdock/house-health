class AddDatabaseConstraints < ActiveRecord::Migration[8.1]
  def change
    change_column_null :rooms, :name, false
    change_column_null :tasks, :name, false
    change_column_null :tasks, :decay_period_days, false

    add_check_constraint :tasks, "decay_period_days >= 1", name: "tasks_decay_period_days_positive"

    remove_index :completions, :task_id
  end
end
