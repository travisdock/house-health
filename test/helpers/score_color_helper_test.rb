require "test_helper"

class ScoreColorHelperTest < ActionView::TestCase
  # Phase 1C: Score Color Helper (Continuous HSL Gradient)

  test "score of 100 returns green hue (120)" do
    assert_equal "hsl(120, 70%, 45%)", score_color(100)
  end

  test "score of 0 returns red hue (0)" do
    assert_equal "hsl(0, 70%, 45%)", score_color(0)
  end

  test "score of 50 returns yellow hue (60)" do
    assert_equal "hsl(60, 70%, 45%)", score_color(50)
  end

  test "score of 75 returns yellow-green hue (90)" do
    assert_equal "hsl(90, 70%, 45%)", score_color(75)
  end

  test "score of 25 returns orange hue (30)" do
    assert_equal "hsl(30, 70%, 45%)", score_color(25)
  end

  test "nil score returns red" do
    assert_equal "hsl(0, 70%, 45%)", score_color(nil)
  end

  test "negative score returns red" do
    assert_equal "hsl(0, 70%, 45%)", score_color(-10)
  end

  test "score above 100 is clamped to green" do
    assert_equal "hsl(120, 70%, 45%)", score_color(150)
  end

  # score_color_light

  test "light: score of 100 returns hue 140" do
    assert_equal "hsl(140, 80%, 55%)", score_color_light(100)
  end

  test "light: score of 0 returns hue 20" do
    assert_equal "hsl(20, 80%, 55%)", score_color_light(0)
  end

  test "light: nil score returns hue 20" do
    assert_equal "hsl(20, 80%, 55%)", score_color_light(nil)
  end

  test "light: score of 50 returns hue 80" do
    assert_equal "hsl(80, 80%, 55%)", score_color_light(50)
  end

  test "light: score above 100 is clamped" do
    assert_equal "hsl(140, 80%, 55%)", score_color_light(150)
  end

  # Floorplan helpers

  test "floorplan_gradient returns gray for nil-score room" do
    room = Room.create!(name: "Empty Room")
    assert_equal "background: hsl(0, 0%, 80%)", floorplan_gradient(room)
  end

  test "floorplan_gradient returns score gradient for scored room" do
    freeze_time do
      room = Room.create!(name: "Scored Room")
      task = room.tasks.create!(name: "Task", decay_period_days: 7)
      task.completions.create!

      assert_equal score_gradient(100), floorplan_gradient(room)
    end
  end

  test "floorplan_color returns gray for nil-score room" do
    room = Room.create!(name: "Empty Room")
    assert_equal "hsl(0, 0%, 70%)", floorplan_color(room)
  end

  test "floorplan_color returns score color for scored room" do
    freeze_time do
      room = Room.create!(name: "Scored Room")
      task = room.tasks.create!(name: "Task", decay_period_days: 7)
      task.completions.create!

      assert_equal score_color(100), floorplan_color(room)
    end
  end
end
