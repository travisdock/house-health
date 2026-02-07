require "test_helper"
require "turbo/broadcastable/test_helper"

class TaskTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include Turbo::Broadcastable::TestHelper
  # Phase 1A: Model Validations & Associations

  test "task requires a name" do
    task = Task.new(name: "", decay_period_days: 7, room: rooms(:kitchen))
    assert_not task.valid?
    assert_includes task.errors[:name], "can't be blank"
  end

  test "task requires decay_period_days" do
    task = Task.new(name: "Clean", decay_period_days: nil, room: rooms(:kitchen))
    assert_not task.valid?
    assert_includes task.errors[:decay_period_days], "can't be blank"
  end

  test "task decay_period_days must be at least 1" do
    task_zero = Task.new(name: "Clean", decay_period_days: 0, room: rooms(:kitchen))
    assert_not task_zero.valid?
    assert_includes task_zero.errors[:decay_period_days], "must be greater than or equal to 1"

    task_one = Task.new(name: "Clean", decay_period_days: 1, room: rooms(:kitchen))
    assert task_one.valid?
  end

  test "task belongs to a room" do
    task = tasks(:wipe_counters)
    assert_respond_to task, :room
    assert_kind_of Room, task.room
  end

  test "task has many completions" do
    task = tasks(:wipe_counters)
    assert_respond_to task, :completions
    assert_kind_of ActiveRecord::Associations::CollectionProxy, task.completions
  end

  test "destroying a task destroys its completions" do
    task = tasks(:wipe_counters)
    task.completions.create!
    completion_count = task.completions.count

    assert completion_count > 0, "Task should have completions"
    assert_difference "Completion.count", -completion_count do
      task.destroy
    end
  end

  # Phase 1B: Task Scoring (Decay Formula)

  test "SCORE_AT_ONE_PERIOD constant is defined" do
    assert_equal 0.6, Task::SCORE_AT_ONE_PERIOD
  end

  test "health_score is 0 when task has never been completed" do
    task = Task.create!(name: "Never done", decay_period_days: 7, room: rooms(:kitchen))
    assert_equal 0, task.health_score
  end

  test "health_score is 100 immediately after completion" do
    freeze_time do
      task = Task.create!(name: "Just done", decay_period_days: 7, room: rooms(:kitchen))
      task.completions.create!
      assert_equal 100, task.health_score
    end
  end

  test "health_score decays over time for a daily task" do
    task = Task.create!(name: "Daily task", decay_period_days: 1, room: rooms(:kitchen))

    travel_to 1.day.ago do
      task.completions.create!
    end

    # At exactly 1 decay period, score should be ~60 (SCORE_AT_ONE_PERIOD * 100)
    assert_in_delta 60, task.health_score, 1
  end

  test "health_score decays over time for a weekly task" do
    task = Task.create!(name: "Weekly task", decay_period_days: 7, room: rooms(:kitchen))

    travel_to 7.days.ago do
      task.completions.create!
    end

    # At exactly 1 decay period (7 days), score should be ~60
    assert_in_delta 60, task.health_score, 1
  end

  test "health_score at half decay period is roughly 77" do
    task = Task.create!(name: "Weekly task", decay_period_days: 7, room: rooms(:kitchen))

    travel_to 3.5.days.ago do
      task.completions.create!
    end

    # At half decay period, score should be ~77
    assert_in_delta 77, task.health_score, 2
  end

  test "health_score approaches 22 at 3x decay period" do
    task = Task.create!(name: "Weekly task", decay_period_days: 7, room: rooms(:kitchen))

    travel_to 21.days.ago do
      task.completions.create!
    end

    # At 3x decay period, score should be ~22
    assert_in_delta 22, task.health_score, 2
  end

  test "health_score never goes below 0" do
    task = Task.create!(name: "Old task", decay_period_days: 1, room: rooms(:kitchen))

    travel_to 365.days.ago do
      task.completions.create!
    end

    assert_equal 0, task.health_score
  end

  test "health_score never exceeds 100" do
    freeze_time do
      task = Task.create!(name: "Just done", decay_period_days: 7, room: rooms(:kitchen))
      task.completions.create!
      assert_equal 100, task.health_score
    end
  end

  test "health_score uses the most recent completion" do
    task = Task.create!(name: "Multi complete", decay_period_days: 7, room: rooms(:kitchen))

    # Old completion
    travel_to 14.days.ago do
      task.completions.create!
    end

    # Recent completion
    freeze_time do
      task.completions.create!
      assert_equal 100, task.health_score
    end
  end

  test "health_score is an integer" do
    task = Task.create!(name: "Test task", decay_period_days: 7, room: rooms(:kitchen))

    travel_to 3.days.ago do
      task.completions.create!
    end

    assert_instance_of Integer, task.health_score
  end

  test "score at exactly one decay period matches calibration constant" do
    task = Task.create!(name: "Calibration test", decay_period_days: 1, room: rooms(:kitchen))

    travel_to 24.hours.ago do
      task.completions.create!
    end

    expected = (100 * Task::SCORE_AT_ONE_PERIOD).round
    assert_in_delta expected, task.health_score, 1
  end

  # Phase 5A: Broadcast Configuration

  test "task broadcasts_refreshes is configured" do
    assert_turbo_stream_broadcasts(:house_scores) do
      perform_enqueued_jobs do
        Task.create!(name: "Broadcast Test", decay_period_days: 7, room: rooms(:kitchen))
      end
    end
  end

  test "last_completed_at returns nil when no completions" do
    task = Task.create!(name: "Never done", decay_period_days: 7, room: rooms(:kitchen))
    assert_nil task.last_completed_at
  end

  test "last_completed_at returns most recent completion time" do
    task = Task.create!(name: "Test", decay_period_days: 7, room: rooms(:kitchen))

    old_time = 2.days.ago
    new_time = 1.day.ago

    travel_to old_time do
      task.completions.create!
    end

    travel_to new_time do
      task.completions.create!
    end

    assert_in_delta new_time.to_i, task.last_completed_at.to_i, 1
  end
end
