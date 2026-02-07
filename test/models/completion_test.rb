require "test_helper"

class CompletionTest < ActiveSupport::TestCase
  # Phase 1A: Model Validations & Associations

  test "completion belongs to a task" do
    completion = completions(:recent_wipe)
    assert_respond_to completion, :task
    assert_kind_of Task, completion.task
  end
end
