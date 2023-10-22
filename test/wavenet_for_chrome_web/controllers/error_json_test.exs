defmodule WavenetForChromeWeb.ErrorJSONTest do
  use WavenetForChromeWeb.ConnCase, async: true

  test "renders 404" do
    assert WavenetForChromeWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert WavenetForChromeWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
