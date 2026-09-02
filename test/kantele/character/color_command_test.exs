defmodule Kantele.Character.ColorCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.ColorCommand
  alias Kantele.Character.PlayerMeta
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

  test "color 渲染色彩对照表包含所有颜色" do
    conn = ColorCommand.run(build_conn(player()), %{})
    text = output_text(conn)
    assert text =~ "色彩对照表"
    assert text =~ "BLK"
    assert text =~ "RED"
    assert text =~ "GRN"
    assert text =~ "YEL"
    assert text =~ "BLU"
    assert text =~ "MAG"
    assert text =~ "CYN"
    assert text =~ "WHT"
    assert text =~ "黑色"
    assert text =~ "红色"
    assert text =~ "绿色"
    assert text =~ "黄色"
    assert text =~ "蓝色"
    assert text =~ "品红"
    assert text =~ "青色"
    assert text =~ "白色"
  end

  test "color 路由解析" do
    {:ok, parsed} = Kantele.Character.Commands.parse("color")
    assert parsed.module == Kantele.Character.ColorCommand

    {:ok, parsed} = Kantele.Character.Commands.parse("颜色")
    assert parsed.module == Kantele.Character.ColorCommand
  end
end
