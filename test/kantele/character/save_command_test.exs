defmodule Kantele.Character.SaveCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.SaveCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  test "save 渲染存档结果（不崩溃）" do
    conn = SaveCommand.run(build_conn(player()), %{})
    text = output_text(conn)
    assert text != ""
  end

  test "save 路由解析" do
    {:ok, parsed} = Kantele.Character.Commands.parse("save")
    assert parsed.module == Kantele.Character.SaveCommand

    {:ok, parsed} = Kantele.Character.Commands.parse("存档")
    assert parsed.module == Kantele.Character.SaveCommand
  end
end
