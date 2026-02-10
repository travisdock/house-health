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

      kitchen_pos = response.body.index(rooms(:kitchen).name)
      bathroom_pos = response.body.index(rooms(:bathroom).name)
      bedroom_pos = response.body.index(rooms(:bedroom).name)

      # bedroom: no tasks (nil score, sorts as -1) → first
      # bathroom: clean_toilet never completed (score 0) → second
      # kitchen: average of wipe_counters (~97) and mop_floor (~36) → last
      assert_not_nil bedroom_pos, "Bedroom should appear in response"
      assert_not_nil bathroom_pos, "Bathroom should appear in response"
      assert_not_nil kitchen_pos, "Kitchen should appear in response"
      assert bedroom_pos < bathroom_pos, "Bedroom (nil score) should appear before Bathroom (score 0)"
      assert bathroom_pos < kitchen_pos, "Bathroom (score 0) should appear before Kitchen (score ~66)"
    end
  end

  test "GET / with no rooms shows add room prompt" do
    Room.destroy_all
    get root_path
    assert_response :success
    assert_match(/add/i, response.body)
  end

  # Phase 4A: Dashboard Action

  test "GET /dashboard returns success" do
    get dashboard_path
    assert_response :success
  end

  test "GET /dashboard renders the nav bar with auto-hide controller" do
    get dashboard_path
    assert_response :success
    assert_select "nav[data-controller='navbar']"
  end

  test "GET /dashboard displays house score and room cards" do
    get dashboard_path
    assert_response :success

    # House score is displayed
    assert_select "[data-testid='house-score']"

    # Room names are displayed as cards
    rooms(:kitchen, :bathroom, :bedroom).each do |room|
      assert_match room.name, response.body
    end
  end

  # Phase 4B: Dashboard — Room Detail Interaction

  test "room card links to room tasks via turbo frame" do
    get dashboard_path
    assert_response :success

    # Room cards should link to room tasks path with turbo frame
    assert_select "a[data-turbo-frame='modal']"
  end

  test "room detail shows all tasks with scores and done buttons" do
    room = rooms(:kitchen)
    get room_tasks_path(room)
    assert_response :success

    room.tasks.each do |task|
      assert_match task.name, response.body
      assert_match task.health_score.to_s, response.body
    end
    assert_select "input[type=submit][value='Done'], button[type=submit]"
  end

  # Phase 4C: Dashboard — Empty States

  test "GET /dashboard with no rooms shows add room prompt" do
    Room.destroy_all
    get dashboard_path
    assert_response :success
    assert_match(/add/i, response.body)
  end

  test "GET /dashboard with a room that has no tasks shows placeholder" do
    get dashboard_path
    assert_response :success

    # Bedroom has no tasks, should show "--" as score placeholder
    assert_match("--", response.body)
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

  # Floorplan

  test "GET /floorplan returns success" do
    get floorplan_path
    assert_response :success
  end

  test "GET /floorplan shows the nav bar" do
    get floorplan_path
    assert_response :success
    assert_select "nav", count: 1
  end

  test "GET /floorplan renders floorplan canvas container" do
    get floorplan_path
    assert_response :success
    assert_select "#floorplan-canvas"
  end

  test "GET /floorplan shows placed rooms" do
    room = rooms(:kitchen)
    room.update!(x: 100, y: 200, width: 300, height: 150)

    get floorplan_path
    assert_response :success
    assert_match room.name, response.body
    assert_select ".floorplan-room"
  end

  test "GET /floorplan does not show sidebar" do
    get floorplan_path
    assert_response :success
    assert_select "aside", count: 0
  end

  test "GET /floorplan shows Edit link" do
    get floorplan_path
    assert_response :success
    assert_select "a[href='#{floorplan_edit_path}']", text: "Edit"
  end

  test "GET /floorplan subscribes to house_scores turbo stream" do
    get floorplan_path
    assert_response :success
    signed_stream = Turbo::StreamsChannel.signed_stream_name(:house_scores)
    assert_match signed_stream, response.body
  end

  # Floorplan Edit

  test "GET /floorplan/edit returns success" do
    get floorplan_edit_path
    assert_response :success
  end

  test "GET /floorplan/edit shows sidebar with unplaced rooms" do
    get floorplan_edit_path
    assert_response :success
    assert_select "aside"
    rooms(:kitchen, :bathroom, :bedroom).each do |room|
      assert_match room.name, response.body
    end
  end

  test "GET /floorplan/edit shows canvas" do
    get floorplan_edit_path
    assert_response :success
    assert_select "#floorplan-canvas"
  end

  test "GET /floorplan/edit does not show Edit link" do
    get floorplan_edit_path
    assert_response :success
    assert_select "a[href='#{floorplan_edit_path}']", count: 0
  end
end
