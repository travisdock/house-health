require "application_system_test_case"

class TurboStreamsSystemTest < ApplicationSystemTestCase
  # Phase 5C: System test for Turbo Stream integration

  test "completing a task updates scores on the same page" do
    visit root_path

    # Bathroom has clean_toilet with no completions → score 0
    assert_text "Bathroom"
    bathroom_link = find("a", text: "Bathroom")
    assert_match(/\b0\b/, bathroom_link.text)

    # Open bathroom modal
    bathroom_link.click

    # Modal shows the task with a Done button
    within("dialog") do
      assert_text "Clean toilet"
      click_button "Done"
    end

    # After morph refresh, bathroom score updates on the main page
    assert_no_selector "dialog[open]", wait: 5
    assert_selector "a", text: /Bathroom.*100/, wait: 5
  end
end
