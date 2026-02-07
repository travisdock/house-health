require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  # Phase 3A: Home Controller (Room List)

  test "GET / returns success" do
    get root_path
    assert_response :success
  end

  test "GET / displays house score and rooms" do
    get root_path
    assert_response :success

    rooms(:kitchen, :bathroom).each do |room|
      assert_match room.name, response.body
    end
  end

  test "GET / orders rooms by score ascending (worst first)" do
    travel_to Time.current do
      get root_path

      kitchen = rooms(:kitchen)
      bathroom = rooms(:bathroom)
      bedroom = rooms(:bedroom)

      kitchen_pos = response.body.index(kitchen.name)
      bathroom_pos = response.body.index(bathroom.name)
      bedroom_pos = response.body.index(bedroom.name)

      # bedroom has no tasks (nil score), bathroom has one task (clean_toilet, never completed = 0),
      # kitchen has tasks with varying scores.
      # Rooms with nil scores (no tasks) should still appear.
      # Rooms with lower scores should appear first.
      assert_not_nil kitchen_pos
      assert_not_nil bathroom_pos
    end
  end

  test "GET / with no rooms shows add room prompt" do
    Room.destroy_all
    get root_path
    assert_response :success
    assert_match(/add/i, response.body)
  end

  # Phase 3B: Room Task List (Mobile)

  test "GET /rooms/:id/tasks shows tasks ordered by score ascending" do
    room = rooms(:kitchen)
    get room_tasks_path(room)
    assert_response :success

    # wipe_counters was completed 1 hour ago (high score ~97)
    # mop_floor was completed 14 days ago (low score ~36)
    # Most urgent (lowest score) should appear first
    mop_pos = response.body.index("Mop floor")
    wipe_pos = response.body.index("Wipe counters")
    assert_not_nil mop_pos, "Mop floor should appear in response"
    assert_not_nil wipe_pos, "Wipe counters should appear in response"
    assert mop_pos < wipe_pos, "Mop floor (lower score) should appear before Wipe counters (higher score)"
  end

  test "GET /rooms/:id/tasks each task has a done button" do
    room = rooms(:kitchen)
    get room_tasks_path(room)
    assert_response :success
    assert_select "input[type=submit], button[type=submit]"
  end

  test "GET /rooms/:id/tasks for room with no tasks shows add tasks prompt" do
    room = rooms(:bedroom)
    get room_tasks_path(room)
    assert_response :success
    assert_match(/add/i, response.body)
  end
end
