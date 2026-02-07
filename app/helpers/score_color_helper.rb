module ScoreColorHelper
  def score_color(score)
    return "hsl(0, 70%, 45%)" if score.nil? || score <= 0

    hue = (score * 1.2).round.clamp(0, 120)
    "hsl(#{hue}, 70%, 45%)"
  end

  def score_color_light(score)
    return "hsl(20, 80%, 55%)" if score.nil? || score <= 0

    hue = (score * 1.2).round.clamp(0, 120) + 20
    "hsl(#{hue}, 80%, 55%)"
  end
end
