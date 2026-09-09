defmodule Kantele.World.Weather.Data.IO do
  @moduledoc false

  @data_path Path.expand("../../../../data/nature/weather.ucl", __DIR__)

  @external_resource @data_path

  @doc false
  def path(), do: @data_path

  @doc false
  def load_tables!() do
    parsed = @data_path |> File.read!() |> Elias.parse()

    parsed.phases
    |> Map.new(fn {key, block} ->
      {key, block.table |> Enum.sort_by(& &1.hour)}
    end)
  end
end

defmodule Kantele.World.Weather.Data do
  @moduledoc """
  Tiansum phase tables (Q2-T2)

  Loads `data/nature/weather.ucl` at compile time. 12 tables
  (`spring/summer/autumn/winter` × `rain/sun/wind`), each with 8 rows of
  3 game-hours (hour = 0,3,6,9,12,15,18,21). Fields align with LPC
  adm/etc/nature: hour / time_msg / desc_msg / outcolor.

  @external_resource marks the data file so edits trigger a recompile.
  """

  alias Kantele.World.Weather.Data.IO

  @weathers [:rain, :sun, :wind]

  @external_resource IO.path()
  @tables IO.load_tables!()

  @doc "全部 12 套表：%{key => rows}（rows 按 hour 升序）"
  def tables(), do: @tables

  @doc "某套表（如 `:spring_rain`）；无则 nil"
  def table(key), do: Map.get(@tables, key)

  @doc "某季度的三套天气表 key 列表（:spring_rain 等）"
  def keys(season) when season in [:spring, :summer, :autumn, :winter] do
    Enum.map(@weathers, &:"#{season}_#{&1}")
  end

  @doc "按 hour 查当段（hour 取 ≤ 的最大档；越界取首/末档）"
  def select_phase(rows, hour) when is_list(rows) do
    rows
    |> Enum.filter(&(&1.hour <= hour))
    |> List.last()
    |> Kernel.||(List.first(rows))
  end
end