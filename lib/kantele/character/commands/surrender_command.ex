defmodule Kantele.Character.SurrenderCommand do
  @moduledoc """
  投降命令：`surrender` / `投降`

  对应 LPC cmds/std/surrender.c：战斗中投降脱战，扣 50 阅历。
  若最后对手仍然主动攻击（kill 状态），则投降被拒。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.Combat
  alias Kantele.Character.CommandView
  alias Kantele.Character.Records

  def run(conn, _params) do
    character = conn.character
    combat = character.meta.combat

    cond do
      not Combat.fighting?(combat) ->
        fail(conn, "投降？现在没有人在打你啊....？\n")

      true ->
        do_surrender(conn, character, combat)
    end
  end

  defp do_surrender(conn, character, combat) do
    # 检查最后对手是否仍在 kill 状态（LPC: last_opponent->is_killing(me)）
    # 简化：检查是否有 NPC 仍然主动攻击（aggressive/killer）
    # 由于 K 端没有 is_killing 概念，直接允许投降

    # 清除所有敌人（同 HaltCommand 逻辑）
    Enum.each(combat.enemies, fn enemy ->
      if Process.alive?(enemy.pid) do
        send(enemy.pid, %Kalevala.Event{
          from_pid: self(),
          topic: "combat/halt",
          data: %{id: character.id}
        })
      end
    end)

    # 扣 50 阅历
    stats = character.meta.stats
    score = stats.score || 0
    new_score = max(score - 50, 0)
    stats = %{stats | score: new_score}
    character = %{character | meta: Map.put(character.meta, :stats, stats)}

    # 重置战斗状态
    character = %{character | meta: Map.put(character.meta, :combat, Combat.new())}

    Records.save(character)

    conn
    |> put_character(character)
    |> render(CommandView, "text", %{text: "\n$N说道：「不打了，不打了，我投降....。」\n\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
