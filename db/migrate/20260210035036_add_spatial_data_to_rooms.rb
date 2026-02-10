class AddSpatialDataToRooms < ActiveRecord::Migration[8.1]
  def change
    add_column :rooms, :x, :integer
    add_column :rooms, :y, :integer
    add_column :rooms, :width, :integer
    add_column :rooms, :height, :integer
  end
end
