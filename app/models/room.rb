class Room < ApplicationRecord
  has_many :tasks, dependent: :destroy

  validates :name, presence: true
  validates :x, :y, numericality: { in: 0..1000 }, allow_nil: true
  validates :width, :height, numericality: { greater_than: 0, less_than_or_equal_to: 1000 }, allow_nil: true
  validate :spatial_data_complete_or_absent

  scope :placed, -> { where.not(x: nil) }
  scope :unplaced, -> { where(x: nil) }

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

  private

  def spatial_data_complete_or_absent
    fields = [ x, y, width, height ]
    unless fields.all? { |f| !f.nil? } || fields.all?(&:nil?)
      errors.add(:base, "spatial data must be fully present or fully absent")
    end
  end
end
