defmodule Kantele.Character.DivorceCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.DivorceCommand
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
    spouse = Keyword.get(opts, :spouse, nil)
    temp = Keyword.get(opts, :temp, %{})

    %Kalevala.Character{
      id: Keyword.get(opts, :id, "player-1"),
      name: Keyword.get(opts, :name, "张三"),
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat,
        spouse: spouse,
        temp: temp
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

  describe "divorce 命令" do
    test "单身时拒绝离婚" do
      p = player(spouse: nil)
      conn = DivorceCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "单身一人"
    end

    test "第一次离婚请求需要确认" do
      p = player(spouse: %{id: "player-2", name: "李四"})
      conn = DivorceCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "再输入一次 divorce"
      assert output_text(conn) =~ "决心"
    end

    test "确认离婚时设置temp标志" do
      p = player(spouse: %{id: "player-2", name: "李四"})
      conn = DivorceCommand.run(build_conn(p), %{})
      updated_char = conn.private.update_character || conn.character
      meta = updated_char.meta
      assert PlayerMeta.get_temp(meta, "pending/divorce") == 1
    end

    test "确认离婚后第二次调用实际离婚" do
      p = player(spouse: %{id: "player-2", name: "李四"}, temp: %{"pending/divorce" => 1})
      conn = DivorceCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "下定决心"
      assert output_text(conn) =~ "李四"
      assert output_text(conn) =~ "分手"
    end

    test "离婚后meta.spouse被清除" do
      p = player(spouse: %{id: "player-2", name: "李四"}, temp: %{"pending/divorce" => 1})
      conn = DivorceCommand.run(build_conn(p), %{})
      updated_char = conn.private.update_character || conn.character
      assert PlayerMeta.spouse(updated_char.meta) == nil
    end
  end
end
