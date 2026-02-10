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

  test "GET /rooms/new renders the form" do
    get new_room_path
    assert_response :success
    assert_select "form"
  end

  test "GET /rooms/:id/edit renders the form" do
    get edit_room_path(rooms(:kitchen))
    assert_response :success
    assert_select "form"
  end

  test "POST /rooms creates a room with valid params" do
    assert_difference "Room.count", 1 do
      post rooms_path, params: { room: { name: "Living Room" } }
    end
    assert_redirected_to rooms_path
    assert_equal "Living Room", Room.last.name
  end

  test "POST /rooms with invalid params renders form with errors" do
    assert_no_difference "Room.count" do
      post rooms_path, params: { room: { name: "" } }
    end
    assert_response :unprocessable_entity
    assert_select "form"
  end

  test "PATCH /rooms/:id updates room attributes" do
    room = rooms(:kitchen)
    patch room_path(room), params: { room: { name: "Updated Kitchen" } }
    assert_redirected_to rooms_path
    assert_equal "Updated Kitchen", room.reload.name
  end

  test "PATCH /rooms/:id with invalid params renders form with errors" do
    room = rooms(:kitchen)
    patch room_path(room), params: { room: { name: "" } }
    assert_response :unprocessable_entity
    assert_select "form"
    assert_equal "Kitchen", room.reload.name
  end

  # Floorplan: Position endpoint

  test "PATCH /rooms/:id/position saves spatial data" do
    room = rooms(:kitchen)
    patch position_room_path(room), params: { room: { x: 100, y: 200, width: 300, height: 150 } }
    assert_response :ok

    room.reload
    assert_equal 100, room.x
    assert_equal 200, room.y
    assert_equal 300, room.width
    assert_equal 150, room.height
  end

  test "PATCH /rooms/:id/position with invalid data returns 422" do
    room = rooms(:kitchen)
    patch position_room_path(room), params: { room: { x: 100, y: 200, width: -50, height: 150 } }
    assert_response :unprocessable_entity
  end

  test "PATCH /rooms/:id/position does not affect room name" do
    room = rooms(:kitchen)
    original_name = room.name
    patch position_room_path(room), params: { room: { x: 100, y: 200, width: 300, height: 150 } }
    assert_response :ok
    assert_equal original_name, room.reload.name
  end

  test "existing PATCH /rooms/:id update is unaffected by position endpoint" do
    room = rooms(:kitchen)
    patch room_path(room), params: { room: { name: "Updated Kitchen" } }
    assert_redirected_to rooms_path
    assert_equal "Updated Kitchen", room.reload.name
    assert_nil room.x
  end

  test "POST /rooms with spatial params creates a placed room" do
    assert_difference "Room.count", 1 do
      post rooms_path, params: { room: { name: "New Room", x: 100, y: 200, width: 150, height: 100 } }
    end
    room = Room.last
    assert_equal "New Room", room.name
    assert_equal 100, room.x
    assert_equal 200, room.y
    assert_equal 150, room.width
    assert_equal 100, room.height
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
