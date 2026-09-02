defmodule Kantele.Character.DescribeCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.DescribeCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
      jingli: Keyword.get(opts, :jingli, 2000),
      neili: Keyword.get(opts, :neili, 9000),
      max_neili: Keyword.get(opts, :max_neili, 10000),
      max_jingli: Keyword.get(opts, :max_jingli, 2000),
      qi: Keyword.get(opts, :qi, 5000),
      max_qi: Keyword.get(opts, :max_qi, 5000)
    }

    stats = %Stats{
      str: Keyword.get(opts, :str, 20),
      dex: Keyword.get(opts, :dex, 20),
      con: Keyword.get(opts, :con, 20),
      int: Keyword.get(opts, :int, 20),
      skills: Keyword.get(opts, :skills, %{}),
      combat_exp: Keyword.get(opts, :combat_exp, 0),
      score: Keyword.get(opts, :score, 0),
      weiwang: Keyword.get(opts, :weiwang, 0)
    }

    combat = Kantele.Character.Combat.new()

    %Kalevala.Character{
      id: Keyword.get(opts, :id, "player-1"),
      name: Keyword.get(opts, :name, "张三"),
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

  describe "describe 命令" do
    test "设置描述成功" do
      p = player()
      conn = DescribeCommand.run(build_conn(p), %{"description" => "一个身穿白衣的年轻剑客"})
      assert output_text(conn) =~ "设定了新的描述"
    end

    test "describe none清除描述" do
      p = player()
      conn = DescribeCommand.run(build_conn(p), %{"description" => "none"})
      assert output_text(conn) =~ "取消了"
    end

    test "超过8行被拒绝" do
      p = player()
      lines = for i <- 1..10, do: "第#{i}行"
      desc = Enum.join(lines, "\n")
      conn = DescribeCommand.run(build_conn(p), %{"description" => desc})
      assert output_text(conn) =~ "八行以内"
    end

    test "路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("describe 描述内容")
      assert parsed.module == DescribeCommand
    end
  end
end
