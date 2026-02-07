class HomeController < ApplicationController
  before_action :load_rooms_and_score

  def index; end
  def dashboard; end

  private

  def load_rooms_and_score
    # Rooms with no tasks (nil score) sort first via -1 so they stay visible
    @rooms = Room.includes(tasks: :completions).sort_by { |r| r.score || -1 }
    @house_score = Room.house_score(@rooms)
    @room = Room.new
  end
end
