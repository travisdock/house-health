class Room < ApplicationRecord
  has_many :tasks, dependent: :destroy

  validates :name, presence: true

  def self.house_score
    scored_rooms = Room.includes(tasks: :completions).select { |r| r.score.present? }
    return nil if scored_rooms.empty?

    (scored_rooms.sum(&:score).to_f / scored_rooms.size).round
  end

  def score
    return nil if tasks.empty?

    (tasks.sum(&:health_score).to_f / tasks.size).round
  end
end
