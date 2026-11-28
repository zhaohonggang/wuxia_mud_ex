defmodule Kantele.Character.CombatWaidiKillTest do
  @moduledoc """
  A-5-c C2：击杀入侵 NPC → 杀手 waidi 状态写入。

  对应 LPC `adm/daemons/invasion/npc/invader.c:151-160`：
  - `waidi/born_time != 本次波次 born_time` → `delete("waidi")` 后重置
    `set("waidi/born_time", ...)` + `add("waidi/number", 1)`（=1）；
  - 同波 → `add("waidi/number", 1)` 累加。
  ex 落点：`meta.env[:waidi] = %{born_time:, number:}`（env 即 LPC set() 仓库）。
  """

  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.CombatEvent
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(opts \\ []) do
    stats =
      Stats.new()
      |> struct(
        Keyword.merge(
          [
            str: 20,
            dex: 20,
            con: 20,
            int: 20,
            skills: %{},
            potential: 100
          ],
          Keyword.get(opts, :stats, [])
        )
      )

    %Kalevala.Character{
      id: Keyword.get(opts, :id, "player-1"),
      name: Keyword.get(opts, :name, "张三"),
      pid: self(),
      room_id: "test:room",
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: stats,
        combat: Combat.new(),
        env: Keyword.get(opts, :env, %{})
      }
    }
  end

  defp kill(conn_character, born_time) do
    conn =
      CombatEvent.enemy_died(build_conn(conn_character), %{
        topic: "combat/enemy-died",
        data: %{
          id: "invasion-1-1",
          exp: 5,
          potential: 2,
          waidi_born_time: born_time
        }
      })

    conn.private.update_character || conn.character
  end

  test "首次击杀入侵者：delete waidi 语义 → born_time 置波次值，number=1" do
    c = kill(player(), 1_700_000_001)

    assert Map.get(c.meta.env || %{}, :waidi) == %{born_time: 1_700_000_001, number: 1}
  end

  test "同波再杀：number 累加，born_time 不变" do
    c =
      player()
      |> kill(1_700_000_001)
      |> kill(1_700_000_001)
      |> kill(1_700_000_001)

    assert Map.get(c.meta.env || %{}, :waidi) == %{born_time: 1_700_000_001, number: 3}
  end

  test "跨波（born_time 变化）：delete waidi 重置 → number 回 1" do
    c =
      player()
      |> kill(1_700_000_001)
      |> kill(1_700_000_001)
      |> kill(1_700_000_002)

    assert Map.get(c.meta.env || %{}, :waidi) == %{born_time: 1_700_000_002, number: 1}
  end

  test "已有旧波 waidi 的玩家跨波击杀：born_time 更新、number 重置" do
    c =
      player(env: %{waidi: %{born_time: 1_699_999_999, number: 7}})
      |> kill(1_700_000_001)

    assert Map.get(c.meta.env || %{}, :waidi) == %{born_time: 1_700_000_001, number: 1}
  end

  test "非入侵击杀（waidi_born_time 缺省/nil）：不写 waidi" do
    conn =
      CombatEvent.enemy_died(build_conn(player()), %{
        topic: "combat/enemy-died",
        data: %{id: "liuxi:yezhu", exp: 5, potential: 2}
      })

    c = conn.private.update_character || conn.character
    refute Map.get(c.meta.env || %{}, :waidi)
  end

  test "已有 waidi 时普通击杀不破坏既有 waidi 状态" do
    c =
      player(env: %{waidi: %{born_time: 1_700_000_001, number: 2}})
      |> kill(nil)

    assert Map.get(c.meta.env || %{}, :waidi) == %{born_time: 1_700_000_001, number: 2}
  end
end
