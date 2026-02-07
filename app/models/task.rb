class Task < ApplicationRecord
  # Tuning constant: score at exactly 1 decay period (0.6 = 60%)
  SCORE_AT_ONE_PERIOD = 0.6

  belongs_to :room
  has_many :completions, dependent: :destroy

  validates :name, presence: true
  validates :decay_period_days, presence: true, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 730 }

  def last_completed_at
    if completions.loaded?
      completions.map(&:created_at).max
    else
      completions.maximum(:created_at)
    end
  end

  def health_score
    completed_at = last_completed_at
    return 0 if completed_at.nil?

    hours_elapsed = (Time.current - completed_at) / 1.hour
    decay_period_hours = decay_period_days * 24.0
    k = -Math.log(SCORE_AT_ONE_PERIOD) / decay_period_hours

    (100.0 * Math.exp(-k * hours_elapsed)).round.clamp(0, 100)
  end
end
