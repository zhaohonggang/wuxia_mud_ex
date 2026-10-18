defmodule Kantele.World.NpcActions.Down do
  @moduledoc """
  NPC 倒下/尸体化（P5-1c，full `bi`）。

  对应 LPC NPC `die()` 里 `::die()` 的框架部分。语义与
  `Kantele.Character.CombatEvent` 的 NPC 死亡分支保持一致：

  - `combat.dead: true`（停掉大脑与 `combat/tick`）
  - `meta.defeated_by` 记录放倒者
  - `StatusTracker.mark_dead/1`
  - 自投递 `combat/respawn`（按 NPC `combat_config.respawn_delay`，缺省 30s）

  与战斗死亡不同的是：条件致倒**没有战斗敌人**，故不走 `combat/enemy-died`
  结算；对手通知由调用方（`Kantele.World.NpcActions.Bi`）自行处理。
  """

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kalevala.Event
  alias Kantele.Character.Combat
  alias Kantele.Character.Combat.StatusTracker

  @default_respawn_ms 30_000

  @doc "把 `character` 标为倒下（几何与 CombatEvent 一致），返回更新后的 conn"
  def mark_dead(conn, character, killer_id) do
    character =
      character
      |> Map.put(:status, "#{character.name}的尸体躺在地上。")
      |> Map.put(:meta, Map.put(character.meta, :defeated_by, killer_id))
      |> Map.put(:meta, Map.put(character.meta, :combat, %{character.meta.combat | dead: true}))

    StatusTracker.mark_dead(character.id)

    Process.send_after(
      self(),
      %Event{from_pid: self(), topic: "combat/respawn", data: %{}},
      respawn_delay(character)
    )

    put_character(conn, character)
  end

  defp respawn_delay(%{meta: %{combat_config: %{respawn_delay: ms}}})
       when is_integer(ms) and ms > 0,
       do: ms

  defp respawn_delay(_character), do: @default_respawn_ms
end
