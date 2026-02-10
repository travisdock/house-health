class HomeController < ApplicationController
  before_action :load_rooms_and_score, only: %i[index dashboard]
  before_action :load_floorplan_data, only: %i[floorplan floorplan_edit]

  def index; end
  def dashboard; end

  def floorplan
    @editable = false
  end

  def floorplan_edit
    @editable = true
    render :floorplan
  end

  private

  def load_floorplan_data
    rooms = Room.includes(tasks: :completions)
    @placed_rooms = rooms.placed
    @unplaced_rooms = rooms.unplaced.order(:name)
    @house_score = Room.house_score(rooms)
  end

  def load_rooms_and_score
    # Rooms with no tasks (nil score) sort first via -1 so they stay visible
    @rooms = Room.includes(tasks: :completions).sort_by { |r| r.score || -1 }
    @house_score = Room.house_score(@rooms)
    @room = Room.new
  end
end
