class HomeController < ApplicationController
  def index
    @rooms = Room.includes(tasks: :completions).sort_by { |r| r.score || -1 }
    @house_score = Room.house_score
  end

  def dashboard
    @rooms = Room.includes(tasks: :completions).sort_by { |r| r.score || -1 }
    @house_score = Room.house_score
  end
end
