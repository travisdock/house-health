require "test_helper"

class TasksControllerTest < ActionDispatch::IntegrationTest
  # Phase 2B: Tasks CRUD (Nested Under Rooms)

  test "GET /rooms/:room_id/tasks/new renders the form" do
    get new_room_task_path(rooms(:kitchen))
    assert_response :success
    assert_select "form"
  end

  test "GET /rooms/:room_id/tasks/:id/edit renders the form" do
    get edit_room_task_path(rooms(:kitchen), tasks(:wipe_counters))
    assert_response :success
    assert_select "form"
  end

  test "POST /rooms/:room_id/tasks creates a task" do
    room = rooms(:kitchen)

    assert_difference "Task.count", 1 do
      post room_tasks_path(room), params: { task: { name: "Sweep floor", decay_period_days: 3 } }
    end

    task = Task.last
    assert_equal "Sweep floor", task.name
    assert_equal 3, task.decay_period_days
    assert_equal room.id, task.room_id
    assert_redirected_to rooms_path
  end

  test "POST /rooms/:room_id/tasks with invalid params renders form with errors" do
    room = rooms(:kitchen)
    assert_no_difference "Task.count" do
      post room_tasks_path(room), params: { task: { name: "", decay_period_days: 0 } }
    end
    assert_response :unprocessable_entity
    assert_select "form"
  end

  test "PATCH /rooms/:room_id/tasks/:id updates task attributes" do
    room = rooms(:kitchen)
    task = tasks(:wipe_counters)

    patch room_task_path(room, task), params: { task: { name: "Wipe all counters", decay_period_days: 2 } }

    assert_redirected_to rooms_path
    task.reload
    assert_equal "Wipe all counters", task.name
    assert_equal 2, task.decay_period_days
  end

  test "PATCH /rooms/:room_id/tasks/:id with invalid params renders form with errors" do
    room = rooms(:kitchen)
    task = tasks(:wipe_counters)
    patch room_task_path(room, task), params: { task: { name: "", decay_period_days: 0 } }
    assert_response :unprocessable_entity
    assert_select "form"
    task.reload
    assert_equal "Wipe counters", task.name
    assert_equal 1, task.decay_period_days
  end

  test "DELETE /rooms/:room_id/tasks/:id destroys the task and cascades" do
    room = rooms(:kitchen)
    task = tasks(:wipe_counters)
    completion_count = task.completions.count

    assert completion_count > 0, "Task should have completions from fixtures"

    assert_difference "Task.count", -1 do
      assert_difference "Completion.count", -completion_count do
        delete room_task_path(room, task)
      end
    end
    assert_redirected_to rooms_path
  end
end
