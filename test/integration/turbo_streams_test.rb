require "test_helper"

class TurboStreamsTest < ActionDispatch::IntegrationTest
  # Phase 5B: Layout and Auto-Refresh

  test "dashboard view subscribes to house_scores stream" do
    get dashboard_path
    assert_response :success
    signed_name = Turbo::StreamsChannel.signed_stream_name(:house_scores)
    assert_select "turbo-cable-stream-source[signed-stream-name=?]", signed_name
  end

  test "home view subscribes to house_scores stream" do
    get root_path
    assert_response :success
    signed_name = Turbo::StreamsChannel.signed_stream_name(:house_scores)
    assert_select "turbo-cable-stream-source[signed-stream-name=?]", signed_name
  end

  test "layout has turbo_refreshes_with morph" do
    get root_path
    assert_response :success
    assert_select 'meta[name="turbo-refresh-method"][content="morph"]'
  end

  test "dashboard has meta refresh for decay updates" do
    get dashboard_path
    assert_response :success
    assert_select 'meta[http-equiv="refresh"][content="3600"]'
  end

  test "mobile does NOT have meta refresh" do
    get root_path
    assert_response :success
    assert_select 'meta[http-equiv="refresh"]', count: 0
  end
end
