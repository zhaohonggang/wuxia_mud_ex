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

  test "室内暗房 look 注入漆黑可见性文案（P-E room.light）" do
    dark_room = %{room([]) | light: 0}

    text =
      LookView.render("_description", %{room: dark_room})
      |> IO.iodata_to_binary()

    assert text =~ "一片空旷的原野"
    assert text =~ "漆黑"
  end

  test "室内亮房（默认 light=1）look 无漆黑文案" do
    text =
      LookView.render("_description", %{room: room([])})
      |> IO.iodata_to_binary()

    refute text =~ "漆黑"
  end

  test "室内暗房（显式 :dark）look 注入漆黑文案（P-E）" do
    dark_room = %{room([]) | light: :dark}

    text =
      LookView.render("_description", %{room: dark_room})
      |> IO.iodata_to_binary()

    assert text =~ "漆黑"
  end

  test "Weather.light_for_hour 边界：6/17 白昼，5/18 黑夜（P-E）" do
    assert Kantele.World.Weather.light_for_hour(6) == :light
    assert Kantele.World.Weather.light_for_hour(17) == :light
    assert Kantele.World.Weather.light_for_hour(5) == :dark
    assert Kantele.World.Weather.light_for_hour(18) == :dark
    assert Kantele.World.Weather.light_for_hour(12) == :light
    assert Kantele.World.Weather.light_for_hour(0) == :dark
  end
end
