# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_10_231120) do
  create_table "completions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "task_id", null: false
    t.datetime "updated_at", null: false
    t.index ["task_id", "created_at"], name: "index_completions_on_task_id_and_created_at"
  end

  create_table "rooms", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "height"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "width"
    t.integer "x"
    t.integer "y"
    t.index ["x"], name: "index_rooms_on_x"
    t.check_constraint "height > 0 AND height <= 1000", name: "rooms_height_range"
    t.check_constraint "width > 0 AND width <= 1000", name: "rooms_width_range"
    t.check_constraint "x >= 0 AND x <= 1000", name: "rooms_x_range"
    t.check_constraint "y >= 0 AND y <= 1000", name: "rooms_y_range"
  end

  create_table "tasks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "decay_period_days", null: false
    t.string "name", null: false
    t.integer "room_id", null: false
    t.datetime "updated_at", null: false
    t.index ["room_id"], name: "index_tasks_on_room_id"
    t.check_constraint "decay_period_days >= 1", name: "tasks_decay_period_days_positive"
  end

  add_foreign_key "completions", "tasks"
  add_foreign_key "tasks", "rooms"
end
