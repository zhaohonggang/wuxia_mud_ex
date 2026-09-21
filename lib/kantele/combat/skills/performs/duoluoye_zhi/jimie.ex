defmodule Kantele.Combat.Skills.Performs.DuoluoyeZhi.Jimie do
  @moduledoc """
  菩提寂灭「jimie」（对照 `kungfu/skill/duoluoye-zhi/jimie.c`）

  多罗叶指攻击绝招：消耗 800 内力，发起 `combat/perform-incoming` 事件，
  由目标侧 `resolve_incoming` 判定命中并施加伤害。

  差异（TODO(migrate)）：
  - LPC `ap = finger + duoluoye-zhi`、`dp = dodge + force`、命中率 `ap/2+rand(ap)`；
    本版为 `rand(level) > parry/2`，忙乱 `level/22+2` 轮。
  - LPC 还要求 max_neili>=2500、miss 亦耗内伤（self qi damage/4），未建模；
  - 伤害计算：`damage = level * 2`（简化），LPC 有复杂公式。
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

  @perform_id "duoluoye-zhi/jimie"
  @move_name "「菩提寂灭」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         :ok <- check_weapon(combat),
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

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "unarmed" do
      :ok
    else
      {:error, "你必须空手才能使用#{@move_name}！\n"}
    end
  end

  defp check_skill_level(stats) do
    level = Stats.skill(stats, "duoluoye-zhi")

    if level < 180 do
      {:error, "你的多罗叶指修为不够，目前不能使用#{@move_name}！\n"}
    else
      {:ok, level}
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "finger") == "duoluoye-zhi" do
      :ok
    else
      {:error, "你没有激发多罗叶指，不能使用#{@move_name}！\n"}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 800 do
      {:error, "你的真气不够，无法使用#{@move_name}！\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, level) do
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 800}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn =
      Broadcast.publish(
        conn,
        "$N运起全身功力，双手一圈，用一股内劲拖住$n，随即全力一指戳出，施展#{@move_name}！\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        level: level,
        ap: level * 2,
        dp: 0
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    level = Map.get(data, :level, 0)
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    combat = character.meta.combat
    weapon = Combat.weapon(combat)
    weapon_name = weapon && Map.get(weapon, :name)
    parry = Stats.skill(character.meta.stats, "parry")

    bindings = [n1: attacker.name, n2: character.name, weapon2: weapon_name || "双指"]

    hit = Engine.rand(rng, level) > div(parry, 2)

    if hit do
      damage = level * 2
      combat = Combat.start_busy(combat, div(level, 22) + 2)
      combat = Combat.apply_damage(combat, damage)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "结果$p被$N的#{@move_name}击中，一股霸道的内力伤及经脉，受到#{damage}点伤害！\n",
          bindings
        )
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