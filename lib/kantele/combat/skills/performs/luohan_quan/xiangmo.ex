defmodule Kantele.Combat.Skills.Performs.LuohanQuan.Xiangmo do
  @moduledoc """
  降魔「xiangmo」（对照 `kungfu/skill/luohan-quan/xiangmo.c`）

  罗汉拳单体攻击：消耗 50 内力，对战斗中对手出招（空手/拳脚）。

  差异（TODO(migrate)）：
  - LPC 仅 `level:luohan-quan>=20`；本版加 `mapped` 与 `neili` 门槛；
  - 命中判定：`rand(level) > parry/2`，忙乱 `level/22+2` 轮。
  - 空手攻击不检查武器类型（cuff 为空手）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  @perform_id "luohan-quan/xiangmo"
  @move_name "「降魔」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, level} <- check_skill_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_neili(character) do
      apply_perform(conn, character, target, level)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, @move_name <> "只能对战斗中的对手使用。\n"}
    end
  end

  defp check_skill_level(stats) do
    level = Stats.skill(stats, "luohan-quan")

    if level < 20 do
      {:error, "你的罗汉拳不够娴熟，无法施展#{@move_name}。\n"}
    else
      {:ok, level}
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "cuff") == "luohan-quan" do
      :ok
    else
      {:error, "你没有激发罗汉拳，无法施展#{@move_name}。\n"}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 50 do
      {:error, "你现在真气不够，无法使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, level) do
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 50}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn =
      Broadcast.publish(
        conn,
        "$N双拳翻飞，使出罗汉拳「降魔」，拳势如罗汉降魔般轰向$n！\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{attacker: ref(character), perform_id: @perform_id, level: level}
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    level = Map.get(data, :level, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    combat = character.meta.combat
    weapon = Combat.weapon(combat)
    weapon_name = weapon && Map.get(weapon, :name)
    parry = Stats.skill(character.meta.stats, "parry")

    bindings = [n1: attacker.name, n2: character.name, weapon2: weapon_name || "双拳"]

    if Engine.rand(rng, level) > div(parry, 2) do
      combat = Combat.start_busy(combat, div(level, 22) + 2)

      conn
      |> Broadcast.publish(
        Messages.interpolate("结果$p瘁不及防，连连倒退几步，一时间无法回手！\n", bindings)
      )
      |> put_character(put_combat(character, combat))
    else
      text =
        if weapon_name do
          Messages.interpolate(
            "但是$p识破了$N的用意，自顾将手中的#{weapon_name}舞成一团光花，" <>
              "$N一怔之下再也攻不进去。\n",
            bindings
          )
        else
          Messages.interpolate("但是$p双手戳点刺拍，将$N的来招一一架开。\n", bindings)
        end

      Broadcast.publish(conn, text)
    end
  end

  defp put_combat(character, combat),
    do: %{character | meta: Map.put(character.meta, :combat, combat)}

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end