defmodule Kantele.Character.LookWeatherTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.LookView
  alias Kantele.World.Room

  defp room(flags) do
    %Room{
      id: "look-test-room",
      name: "测试荒野",
      description: "一片空旷的原野。",
      flags: flags,
      x: 0,
      y: 0,
      z: 0,
      features: [],
      exits: []
    }
  end

  test "户外房间 look 注入天象段（Q2-T3）" do
    text =
      LookView.render("_description", %{room: room(["outdoors"])})
      |> IO.iodata_to_binary()

    assert text =~ "一片空旷的原野"

    current = Kantele.World.Weather.outdoor_description()
    assert is_binary(current)
    assert text =~ current
  end

  test "室内房间无天象段" do
    text =
      LookView.render("_description", %{room: room([])})
      |> IO.iodata_to_binary()

    assert text =~ "一片空旷的原野"
    refute text =~ "{color foreground="
  end
end