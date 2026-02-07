require "test_helper"

class RoomsControllerTest < ActionDispatch::IntegrationTest
  # Phase 2A: Rooms CRUD

  test "GET /rooms lists all rooms" do
    get rooms_path
    assert_response :success
    assert_select "main" do
      rooms(:kitchen, :bathroom, :bedroom).each do |room|
        assert_match room.name, response.body
      end
    end
  end

  test "POST /rooms creates a room with valid params" do
    assert_difference "Room.count", 1 do
      post rooms_path, params: { room: { name: "Living Room" } }
    end
    assert_redirected_to rooms_path
    assert_equal "Living Room", Room.last.name
  end

  test "PATCH /rooms/:id updates room attributes" do
    room = rooms(:kitchen)
    patch room_path(room), params: { room: { name: "Updated Kitchen" } }
    assert_redirected_to rooms_path
    assert_equal "Updated Kitchen", room.reload.name
  end

  test "DELETE /rooms/:id destroys the room and cascades" do
    room = rooms(:kitchen)
    task_count = room.tasks.count
    completion_count = Completion.joins(:task).where(tasks: { room_id: room.id }).count

    assert task_count > 0, "Kitchen should have tasks from fixtures"
    assert completion_count > 0, "Kitchen tasks should have completions from fixtures"

    assert_difference "Room.count", -1 do
      assert_difference "Task.count", -task_count do
        assert_difference "Completion.count", -completion_count do
          delete room_path(room)
        end
      end
    end
    assert_redirected_to rooms_path
  end
end
