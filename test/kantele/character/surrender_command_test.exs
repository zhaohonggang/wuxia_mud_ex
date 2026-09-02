defmodule Kantele.Character.SurrenderCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.SurrenderCommand
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
      score: Keyword.get(opts, :score, 100),
      weiwang: Keyword.get(opts, :weiwang, 0)
    }

    combat = Kantele.Character.Combat.new()
    combat = if Keyword.get(opts, :fighting, false) do
      %{combat | enemies: [%{pid: self(), name: "对手"}]}
    else
      combat
    end

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

  describe "surrender 命令" do
    test "无战斗时拒绝投降" do
      p = player(fighting: false)
      conn = SurrenderCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "没有人在打你"
    end

    test "战斗中有敌人时投降" do
      p = player(fighting: true, score: 100)
      conn = SurrenderCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "投降"
      assert output_text(conn) =~ "不打了"
    end

    test "投降后score减少50" do
      p = player(fighting: true, score: 100)
      conn = SurrenderCommand.run(build_conn(p), %{})
      updated = conn.private.update_character || conn.character
      assert updated.meta.stats.score == 50
    end

    test "投降后战斗状态清除" do
      p = player(fighting: true, score: 100)
      conn = SurrenderCommand.run(build_conn(p), %{})
      updated = conn.private.update_character || conn.character
      assert updated.meta.combat.enemies == []
    end
  end
end
