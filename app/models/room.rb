class Room < ApplicationRecord
  has_many :tasks, dependent: :destroy

  validates :name, presence: true

  def self.house_score
    scores = includes(tasks: :completions).filter_map(&:score)
    return nil if scores.empty?

    (scores.sum.to_f / scores.size).round
  end

  def reload(*)
    @score = nil
    super
  end

  def score
    @score ||= begin
      return nil if tasks.empty?

      (tasks.sum(&:health_score).to_f / tasks.size).round
    end
  end
end
