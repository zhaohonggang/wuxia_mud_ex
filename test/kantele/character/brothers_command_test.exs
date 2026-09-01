defmodule Kantele.Character.BrothersCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.BrothersCommand
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
      skills: Keyword.get(opts, :skills, %{})
    }

    brothers = Keyword.get(opts, :brothers, [])

    %Kalevala.Character{
      id: Keyword.get(opts, :id, "player-1"),
      name: Keyword.get(opts, :name, "张三"),
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: Kantele.Character.Combat.new(),
        brothers: brothers
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

  describe "brothers 命令" do
    test "无兄弟时提示" do
      conn = BrothersCommand.run(build_conn(player()), %{})
      assert output_text(conn) =~ "现在还没有结义的兄弟们"
    end

    test "有兄弟时显示列表" do
      p = player(brothers: [%{id: "player-2", name: "李四"}, %{id: "player-3", name: "王五"}])
      conn = BrothersCommand.run(build_conn(p), %{})
      text = output_text(conn)
      assert text =~ "李四"
      assert text =~ "王五"
    end

    test "brothers out 非结拜成员" do
      conn = BrothersCommand.run(build_conn(player()), %{"rest" => "out 非结拜成员"})
      assert output_text(conn) =~ "没有这个结拜兄弟"
    end

    test "brothers out 第一次确认" do
      p = player(brothers: [%{id: "player-2", name: "李四"}])
      conn = BrothersCommand.run(build_conn(p), %{"rest" => "out 李四"})
      text = output_text(conn)
      assert text =~ "割袍断义"
      assert text =~ "请再输入一次"
    end

    test "brothers out 确认后解除关系" do
      p = player(brothers: [%{id: "player-2", name: "李四"}, %{id: "player-3", name: "王五"}])
      p = put_in(p.meta.temp, %{"pending/brother_out" => "李四"})
      conn = BrothersCommand.run(build_conn(p), %{"rest" => "out 李四"})
      assert output_text(conn) =~ "断绝了关系"
    end
  end
end
