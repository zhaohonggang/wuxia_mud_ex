defmodule Kantele.Character.JialiTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.JialiCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp fighter(stats_opts \\ []) do
    default_skills = Map.put(Stats.new().skills, "liuxi-neigong", 20)

    stats =
      Stats.new()
      |> struct(
        Keyword.merge(
          [skills: default_skills, mapped: %{"force" => "liuxi-neigong"}],
          stats_opts
        )
      )

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: stats,
        combat: Combat.new()
      }
    }
  end

  defp run(character, arg), do: JialiCommand.run(build_conn(character), %{"arg" => arg})

  defp current_character(conn), do: conn.private.update_character || conn.character

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  test "设置档位写入 combat.jiali（战斗外也可设）" do
    # liuxi-neigong 默认 20 级 → 上限 10 档
    conn = run(fighter(), "8")

    assert current_character(conn).meta.combat.jiali == 8
    assert output_text(conn) =~ "加力"
  end

  test "超过 enable 内功等级一半时拒绝" do
    conn = run(fighter(), "11")

    assert output_text(conn) =~ "最多加力 10"
    assert current_character(conn).meta.combat.jiali == 0
  end

  test "0 关闭加力" do
    character = fighter()

    {combat, _} = Combat.add_enemy(Combat.new(), %{id: "x", pid: self(), name: "虎", room_id: "r"})
    character = put_combat(character, combat)
    character = put_jiali(character, 5)

    conn = run(character, "0")

    assert current_character(conn).meta.combat.jiali == 0
    assert output_text(conn) =~ "收敛内息"
  end

  test "未 enable 内功拒绝" do
    conn = run(fighter(skills: Stats.new().skills, mapped: %{}), "3")

    assert output_text(conn) =~ "enable"
  end

  test "非数字参数提示用法" do
    conn = run(fighter(), "abc")

    assert output_text(conn) =~ "格式"
  end

  defp put_combat(character, combat),
    do: %{character | meta: Map.put(character.meta, :combat, combat)}

  defp put_jiali(character, level),
    do: put_combat(character, %{character.meta.combat | jiali: level})
end
