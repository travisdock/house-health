class Completion < ApplicationRecord
  belongs_to :task

  broadcasts_refreshes_to ->(_completion) { :house_scores }
end
