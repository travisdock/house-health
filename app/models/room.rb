class Room < ApplicationRecord
  has_many :tasks, dependent: :destroy

  validates :name, presence: true

  broadcasts_refreshes_to ->(_room) { :house_scores }

  def self.house_score(rooms = nil)
    rooms ||= includes(tasks: :completions)
    scores = rooms.filter_map(&:score)
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
