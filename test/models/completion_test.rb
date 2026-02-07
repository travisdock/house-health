require "test_helper"
require "turbo/broadcastable/test_helper"

class CompletionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include Turbo::Broadcastable::TestHelper

  # Phase 1A: Model Validations & Associations

  test "completion belongs to a task" do
    completion = completions(:recent_wipe)
    assert_respond_to completion, :task
    assert_kind_of Task, completion.task
  end

  # Phase 5A: Broadcast Configuration

  test "Completion broadcasts_refreshes is configured" do
    assert_turbo_stream_broadcasts(:house_scores) do
      perform_enqueued_jobs do
        Completion.create!(task: tasks(:wipe_counters))
      end
    end
  end
end
