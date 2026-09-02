defmodule Kantele.Character.AssistCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.AssistCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player() do
    vitals = %Vitals{
      jing: 2000,
      jingli: 2000,
      neili: 9000,
      max_neili: 10000,
      max_jingli: 2000,
      qi: 5000,
      max_qi: 5000
    }

    stats = %Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      skills: %{},
      mapped: %{},
      performs: MapSet.new(),
      combat_exp: 1000,
      score: 0,
      potential: 100,
      weiwang: 0
    }

    combat = Kantele.Character.Combat.new()

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
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

  describe "assist 命令" do
    test "查询状态时无所协助" do
      p = player()
      conn = AssistCommand.run(build_conn(p), %{})
      text = output_text(conn)

      assert text =~ "你现在并没有帮助任何人"
    end

    test "取消未发出的请求" do
      p = player()
      conn = AssistCommand.run(build_conn(p), %{"rest" => "cancel"})
      text = output_text(conn)

      assert text =~ "你现在并没有发出协助请求"
    end

    test "接受无人请求" do
      p = player()
      conn = AssistCommand.run(build_conn(p), %{"rest" => "accept"})
      text = output_text(conn)

      assert text =~ "现在没有人请求你协助"
    end

    test "拒绝无人请求" do
      p = player()
      conn = AssistCommand.run(build_conn(p), %{"rest" => "refuse"})
      text = output_text(conn)

      assert text =~ "现在没有人请求你协助"
    end

    test "assist 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("assist 张三")
      assert parsed.module == AssistCommand
    end
  end
end