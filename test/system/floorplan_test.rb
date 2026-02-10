require "application_system_test_case"

class FloorplanSystemTest < ApplicationSystemTestCase
  test "visiting floorplan shows placed rooms as colored elements" do
    room = rooms(:kitchen)
    room.update!(x: 100, y: 200, width: 300, height: 150)

    visit floorplan_path
    assert_selector ".floorplan-room", text: room.name
  end

  test "unplaced rooms appear in the sidebar on desktop" do
    visit floorplan_edit_path
    within("aside") do
      assert_text rooms(:kitchen).name
      assert_text rooms(:bathroom).name
    end
  end

  test "empty state shows helpful prompt when no rooms are placed" do
    visit floorplan_edit_path
    assert_text "Drag rooms from the sidebar"
  end

  test "placed room links to task modal via turbo frame" do
    room = rooms(:kitchen)
    room.update!(x: 100, y: 200, width: 300, height: 150)

    visit floorplan_path
    room_link = find(".floorplan-room", text: room.name)
    assert_equal room_tasks_path(room), URI.parse(room_link[:href]).path
    assert_equal "modal", room_link["data-turbo-frame"]
  end

  test "rooms with no tasks display gray" do
    room = rooms(:bedroom)
    room.update!(x: 400, y: 400, width: 200, height: 150)

    visit floorplan_path
    bedroom_el = find(".floorplan-room", text: room.name)
    style = bedroom_el[:style]
    # Browser resolves hsl(0, 0%, 80%) to rgb(204, 204, 204)
    assert_match(/rgb\(204, 204, 204\)/, style)
  end
end
