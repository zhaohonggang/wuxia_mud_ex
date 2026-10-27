defmodule Kantele.Character.BegCreditEvent do
  @moduledoc """
  乞讨结果落地：beggar 角色进程加币 + 技能/潜能/实战经验/忙乱（对应 LPC 成功分支）。

  - `:success` → `meta.coins += amount`；`begging` 技能 +1；`potential`+1；
    `combat_exp`+1；忙乱 3~6 轮。
  - `:fail_roll` / `:fail_ignore` → 仅忙乱 3 轮（LPC 两种失败都 `start_busy(3)`）。

  房间进程裁定并转发的跨进程事件，本进程落地并 `Records.save`
  （房间事件不回写 `context.characters`，跨角色改币必须在角色进程落盘，
  与 casino/payout 同款跨进程模式）。
  """
  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.Character.Combat
  alias Kantele.Character.Records
  alias Kantele.Character.Stats

  def run(conn, %{data: %{result: result, amount: amount}}) do
    character = conn.private.update_character || conn.character

    case result do
      :success ->
        stats = character.meta.stats || %Stats{}
        {stats, _improved} = Stats.improve_skill(stats, "begging")

        stats =
          %{stats |
            potential: (stats.potential || 0) + 1,
            combat_exp: (stats.combat_exp || 0) + 1
          }

        combat = character.meta.combat || %Combat{}
        combat = Combat.start_busy(combat, 3 + :rand.uniform(4) - 1)

        meta =
          character.meta
          |> Map.put(:coins, (character.meta.coins || 0) + amount)
          |> Map.put(:stats, stats)
          |> Map.put(:combat, combat)

        character = %{character | meta: meta}
        conn = put_character(conn, character)
        Records.save(character)
        conn

      :fail_roll ->
        apply_busy(conn, character, 3)

      :fail_ignore ->
        apply_busy(conn, character, 3)

      _ ->
        conn
    end
  end

  def run(conn, _data), do: conn

  defp apply_busy(conn, character, rounds) do
    combat = character.meta.combat || %Combat{}
    combat = Combat.start_busy(combat, rounds)
    meta = %{character.meta | combat: combat}
    character = %{character | meta: meta}
    conn = put_character(conn, character)
    Records.save(character)
    conn
  end
end
