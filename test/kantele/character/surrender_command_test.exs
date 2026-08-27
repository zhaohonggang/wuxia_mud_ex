defmodule Kantele.Character.SurrenderCommandTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.SurrenderCommand

  import Kalevala.ConnTest

  describe "surrender 命令前置校验" do
    test "非战斗状态拒绝投降" do
      conn = run_surrender(player())

      assert output_text(conn) =~ "没有人在打你"
    end

    test "战斗中投降清除敌人并扣分" do
      character = player_in_fight(score: 100)

      conn = run_surrender(character)
      character = conn.private.update_character || conn.character

      assert output_text(conn) =~ "不打了"
      assert Combat.enemy?(character.meta.combat, "npc:1") == false
      assert character.meta.stats.score == 50
    end

    test "分数不足 50 时扣到 0" do
      character = player_in_fight(score: 30)

      conn = run_surrender(character)
      character = conn.private.update_character || conn.character

      assert character.meta.stats.score == 0
    end

    test "分数为 0 时投降不报错" do
      character = player_in_fight(score: 0)

      conn = run_surrender(character)
      character = conn.private.update_character || conn.character

      assert character.meta.stats.score == 0
    end
  end

  # ---- helpers ----

  defp player(opts \\ []) do
    score = Keyword.get(opts, :score, 0)

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      meta: %PlayerMeta{
        vitals: Kantele.Character.Vitals.new(),
        stats: %{Kantele.Character.Stats.new() | score: score},
        combat: Combat.new()
      }
    }
  end

  defp player_in_fight(opts) do
    score = Keyword.get(opts, :score, 0)

    combat =
      Combat.new()
      |> Combat.add_enemy(%{id: "npc:1", pid: self(), name: "野猪", room_id: "test:room"})
      |> elem(0)

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      meta: %PlayerMeta{
        vitals: Kantele.Character.Vitals.new(),
        stats: %{Kantele.Character.Stats.new() | score: score},
        combat: combat
      }
    }
  end

  defp run_surrender(character) do
    SurrenderCommand.run(build_conn(character), %{})
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end
end
