class AddSpatialConstraintsAndIndexToRooms < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :rooms, "x >= 0 AND x <= 1000", name: "rooms_x_range"
    add_check_constraint :rooms, "y >= 0 AND y <= 1000", name: "rooms_y_range"
    add_check_constraint :rooms, "width > 0 AND width <= 1000", name: "rooms_width_range"
    add_check_constraint :rooms, "height > 0 AND height <= 1000", name: "rooms_height_range"

    add_index :rooms, :x, name: "index_rooms_on_x"
  end
end
