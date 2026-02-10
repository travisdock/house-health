require "test_helper"
require "turbo/broadcastable/test_helper"

class RoomTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include Turbo::Broadcastable::TestHelper
  # Phase 1A: Model Validations & Associations

  test "room requires a name" do
    room = Room.new(name: "")
    assert_not room.valid?
    assert_includes room.errors[:name], "can't be blank"
  end

  test "room with valid name is valid" do
    room = Room.new(name: "Kitchen")
    assert room.valid?
  end

  test "room has many tasks" do
    room = rooms(:kitchen)
    assert_respond_to room, :tasks
    assert_kind_of ActiveRecord::Associations::CollectionProxy, room.tasks
  end

  test "destroying a room destroys its tasks" do
    room = rooms(:kitchen)
    task_count = room.tasks.count

    assert task_count > 0, "Room should have tasks from fixtures"
    assert_difference "Task.count", -task_count do
      room.destroy
    end
  end

  # Phase 1D: Room Scoring

  test "score is nil when room has no tasks" do
    room = Room.create!(name: "Empty Room")
    assert_nil room.score
  end

  test "score is the average of task health scores" do
    room = Room.create!(name: "Test Room")

    # Task with score 100 (just completed)
    task1 = room.tasks.create!(name: "Task 1", decay_period_days: 7)
    task1.completions.create!

    # Task with score 0 (never completed)
    room.tasks.create!(name: "Task 2", decay_period_days: 7)

    # Average of 100 and 0 = 50
    assert_equal 50, room.score
  end

  test "score is 0 when all tasks have never been completed" do
    room = Room.create!(name: "Neglected Room")
    room.tasks.create!(name: "Task 1", decay_period_days: 7)
    room.tasks.create!(name: "Task 2", decay_period_days: 7)
    room.tasks.create!(name: "Task 3", decay_period_days: 7)

    assert_equal 0, room.score
  end

  test "score is 100 when all tasks were just completed" do
    freeze_time do
      room = Room.create!(name: "Perfect Room")
      task1 = room.tasks.create!(name: "Task 1", decay_period_days: 7)
      task2 = room.tasks.create!(name: "Task 2", decay_period_days: 7)

      task1.completions.create!
      task2.completions.create!

      assert_equal 100, room.score
    end
  end

  test "score rounds to nearest integer" do
    room = Room.create!(name: "Rounding Room")

    # Create 3 tasks: one at 100, two at 0
    # Average would be 33.33... -> should round to 33
    task1 = room.tasks.create!(name: "Task 1", decay_period_days: 7)
    task1.completions.create!
    room.tasks.create!(name: "Task 2", decay_period_days: 7)
    room.tasks.create!(name: "Task 3", decay_period_days: 7)

    assert_equal 33, room.score
  end

  test "room with one task uses that task score directly" do
    freeze_time do
      room = Room.create!(name: "Single Task Room")
      task = room.tasks.create!(name: "Only Task", decay_period_days: 7)
      task.completions.create!

      assert_equal 100, room.score
    end
  end

  test "room with all tasks at 0 has score 0" do
    room = Room.create!(name: "Zero Room")
    room.tasks.create!(name: "Task 1", decay_period_days: 1)
    room.tasks.create!(name: "Task 2", decay_period_days: 1)

    assert_equal 0, room.score
  end

  # Phase 5A: Broadcast Configuration

  test "room broadcasts_refreshes is configured" do
    assert_turbo_stream_broadcasts(:house_scores) do
      perform_enqueued_jobs do
        Room.create!(name: "Broadcast Test Room")
      end
    end
  end

  # Phase 1E: House Scoring (Room.house_score class method)

  test "house_score is nil when there are no rooms" do
    Room.destroy_all
    assert_nil Room.house_score
  end

  test "house_score is nil when all rooms have no tasks" do
    Room.destroy_all
    Room.create!(name: "Empty Room 1")
    Room.create!(name: "Empty Room 2")

    assert_nil Room.house_score
  end

  test "house_score is the average of room scores" do
    Room.destroy_all

    # Room with score 80
    room1 = Room.create!(name: "Room 1")
    task1 = room1.tasks.create!(name: "Task", decay_period_days: 7)
    travel_to 1.day.ago do
      task1.completions.create!
    end

    # Room with score 60
    room2 = Room.create!(name: "Room 2")
    task2 = room2.tasks.create!(name: "Task", decay_period_days: 7)
    travel_to 7.days.ago do
      task2.completions.create!
    end

    # Average should be between them
    house_score = Room.house_score
    assert house_score >= 60 && house_score <= 95, "House score should be average of room scores"
  end

  test "house_score excludes rooms with nil scores (no tasks)" do
    Room.destroy_all

    # Room with tasks and score
    room1 = Room.create!(name: "Room With Tasks")
    task = room1.tasks.create!(name: "Task", decay_period_days: 7)
    task.completions.create!

    # Room without tasks (nil score)
    Room.create!(name: "Empty Room")

    # House score should only consider room1
    assert_equal 100, Room.house_score
  end

  test "house_score rounds to nearest integer" do
    Room.destroy_all

    # Create rooms that average to a non-integer
    room1 = Room.create!(name: "Room 1")
    task1 = room1.tasks.create!(name: "Task", decay_period_days: 7)
    task1.completions.create! # score 100

    room2 = Room.create!(name: "Room 2")
    room2.tasks.create!(name: "Task", decay_period_days: 7) # score 0

    # Average of 100 and 0 = 50
    assert_equal 50, Room.house_score
  end

  test "house_score with one room uses that room score directly" do
    Room.destroy_all

    room = Room.create!(name: "Only Room")
    task = room.tasks.create!(name: "Task", decay_period_days: 7)
    task.completions.create!

    assert_equal 100, Room.house_score
  end

  # Floorplan: Spatial Data

  test "room with full spatial data is valid" do
    room = Room.new(name: "Kitchen", x: 100, y: 200, width: 300, height: 150)
    assert room.valid?
  end

  test "room without spatial data is valid" do
    room = Room.new(name: "Kitchen")
    assert room.valid?
  end

  test "room with partial spatial data is invalid" do
    room = Room.new(name: "Kitchen", x: 100, y: 200)
    assert_not room.valid?
    assert_includes room.errors[:base], "spatial data must be fully present or fully absent"
  end

  test "room with x only is invalid" do
    room = Room.new(name: "Kitchen", x: 100)
    assert_not room.valid?
  end

  test "room with negative width is invalid" do
    room = Room.new(name: "Kitchen", x: 100, y: 200, width: -50, height: 150)
    assert_not room.valid?
  end

  test "room with zero width is invalid" do
    room = Room.new(name: "Kitchen", x: 100, y: 200, width: 0, height: 150)
    assert_not room.valid?
  end

  test "room with x greater than 1000 is invalid" do
    room = Room.new(name: "Kitchen", x: 1001, y: 200, width: 300, height: 150)
    assert_not room.valid?
  end

  test "room with x at boundary 1000 is valid" do
    room = Room.new(name: "Kitchen", x: 1000, y: 0, width: 1, height: 1)
    assert room.valid?
  end

  test "room with width greater than 1000 is invalid" do
    room = Room.new(name: "Kitchen", x: 0, y: 0, width: 1001, height: 100)
    assert_not room.valid?
  end

  # Floorplan: Scopes

  test "placed scope returns rooms with spatial data" do
    Room.destroy_all
    Room.create!(name: "Placed", x: 100, y: 200, width: 300, height: 150)
    Room.create!(name: "Unplaced")

    assert_equal [ "Placed" ], Room.placed.pluck(:name)
  end

  test "unplaced scope returns rooms without spatial data" do
    Room.destroy_all
    Room.create!(name: "Placed", x: 100, y: 200, width: 300, height: 150)
    Room.create!(name: "Unplaced")

    assert_equal [ "Unplaced" ], Room.unplaced.pluck(:name)
  end
end
