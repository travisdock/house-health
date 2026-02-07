require "test_helper"

class CompletionsControllerTest < ActionDispatch::IntegrationTest
  # Phase 3C: Completions Controller

  test "POST /tasks/:task_id/completions creates a completion" do
    task = tasks(:wipe_counters)
    assert_difference "Completion.count", 1 do
      post task_completions_path(task)
    end
    assert_equal task.id, Completion.last.task_id
  end

  test "completion uses created_at as the completion time" do
    task = tasks(:wipe_counters)
    freeze_time do
      post task_completions_path(task)
      assert_in_delta Time.current, Completion.last.created_at, 1.second
    end
  end

  test "POST responds with turbo stream" do
    task = tasks(:wipe_counters)
    post task_completions_path(task), as: :turbo_stream
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
  end

  test "POST redirects to referrer for non-turbo requests" do
    task = tasks(:wipe_counters)
    post task_completions_path(task), headers: { "HTTP_REFERER" => root_url }
    assert_response :redirect
  end

  test "completing a task updates the task health score to 100" do
    task = tasks(:mop_floor)
    assert task.health_score < 100, "Task should have decayed before completion"

    freeze_time do
      post task_completions_path(task)
      assert_equal 100, task.reload.health_score
    end
  end

  test "POST with invalid task_id returns 404" do
    post task_completions_path(task_id: 999999)
    assert_response :not_found
  end
end
