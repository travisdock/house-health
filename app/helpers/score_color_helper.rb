module ScoreColorHelper
  def score_color(score)
    hue = score_hue(score)
    "hsl(#{hue}, 70%, 45%)"
  end

  def score_color_light(score)
    hue = score_hue(score) + 20
    "hsl(#{hue}, 80%, 55%)"
  end

  def score_gradient(score)
    "background: linear-gradient(135deg, #{score_color(score)}, #{score_color_light(score)})"
  end

  def floorplan_gradient(room)
    room.score.nil? ? "background: hsl(0, 0%, 80%)" : score_gradient(room.score)
  end

  private

  def score_hue(score)
    return 0 if score.nil? || score <= 0

    (score * 1.2).round.clamp(0, 120)
  end
end
