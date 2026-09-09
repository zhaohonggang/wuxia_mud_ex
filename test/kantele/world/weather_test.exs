defmodule Kantele.World.WeatherTest do
  use ExUnit.Case, async: true

  alias Kantele.World.Weather
  alias Kantele.World.Weather.Data

  defp ctx(overrides \\ %{}) do
    Map.merge(
      %{season: :winter, weather: :sun, phase: %{hour: 0}},
      Map.new(overrides)
    )
  end

  test "数据：12 套表齐全，每套 8 段且小时覆盖 0..21 步长 3" do
    tables = Data.tables()
    assert map_size(tables) == 12

    Enum.each(tables, fn {key, rows} ->
      assert length(rows) == 8
      assert Enum.map(rows, & &1.hour) == [0, 3, 6, 9, 12, 15, 18, 21]
      assert key in [:spring_rain, :summer_rain, :autumn_rain, :winter_rain,
        :spring_sun, :summer_sun, :autumn_sun, :winter_sun,
        :spring_wind, :summer_wind, :autumn_wind, :winter_wind]

      Enum.each(rows, fn row ->
        assert is_integer(row.hour)
        assert is_binary(row.time_msg)
        assert is_binary(row.desc_msg)
        assert is_binary(row.outcolor)
      end)
    end)
  end

  test "select_phase：取不越过 hour 的最大档，边界取首/末档" do
    rows = Data.table(:spring_rain)

    assert Data.select_phase(rows, 0).hour == 0
    assert Data.select_phase(rows, 5).hour == 3
    assert Data.select_phase(rows, 18).hour == 18
    assert Data.select_phase(rows, 23).hour == 21
  end

  test "step：同季节同时段无播报、状态不变" do
    {new_ctx, announcements} = Weather.step(ctx(), %{season: :winter, hour: 0, month: 1})

    assert announcements == []
    assert new_ctx.season == :winter
    assert new_ctx.weather == :sun
    assert new_ctx.phase.hour == 0
  end

  test "step：时段变化播报（同季节同天气）" do
    {new_ctx, [ann]} =
      Weather.step(ctx(), %{season: :winter, hour: 5, month: 2})

    assert new_ctx.phase.hour == 3
    assert String.starts_with?(ann, "【天象】")
    assert new_ctx.weather == :sun
  end

  test "step：换季重选天气表并播报；表 key 归一" do
    {new_ctx, [ann]} =
      Weather.step(ctx(season: :winter, weather: :sun), %{season: :spring, hour: 8, month: 4})

    assert new_ctx.season == :spring
    assert new_ctx.weather in [:rain, :sun, :wind]
    assert new_ctx.phase.hour == 6
    assert String.contains?(ann, "春")
    assert to_string(Weather.table_key(new_ctx.season, new_ctx.weather)) =~ "spring"
  end

  test "table_key 拼接正确" do
    assert Weather.table_key(:summer, :rain) == :summer_rain
    assert Weather.table_key(:autumn, :wind) == :autumn_wind
  end

  describe "GenServer（匿名实例，接真实时钟）" do
    setup do
      {:ok, server} = Weather.start_link(name: :anonymous, seed: 1, announce: false, cycle_ms: 500)
      %{server: server}
    end

    test "API 返回合理天象数据", %{server: server} do
      assert Weather.season(server) in [:spring, :summer, :autumn, :winter]
      assert Weather.weather(server) in [:rain, :sun, :wind]
      assert to_string(Weather.current_table(server)) =~ "_"

      phase = Weather.current_phase(server)
      assert phase.hour in [0, 3, 6, 9, 12, 15, 18, 21]
      assert is_binary(phase.time_msg)

      desc = Weather.outdoor_description(server)
      assert is_binary(desc)
      assert String.starts_with?(desc, "{color")
      assert Weather.light(server) in [:light, :dark]
    end

    test "tick 推进后状态仍一致（时段/季节合法）", %{server: server} do
      assert Weather.tick(server) == :ok
      assert Weather.season(server) in [:spring, :summer, :autumn, :winter]
      assert Weather.current_phase(server).hour in [0, 3, 6, 9, 12, 15, 18, 21]
    end
  end
end