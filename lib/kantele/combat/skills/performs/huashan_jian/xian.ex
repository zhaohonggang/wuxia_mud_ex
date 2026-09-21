defmodule Kantele.Combat.Skills.Performs.HuashanJian.Xian do
  @moduledoc """
  夺命连环三仙剑「xian」（对照 `kungfu/skill/huashan-jian/xian.c`）

  华山剑宗绝技：消耗 280 内力，连环三剑，发起 `combat/perform-incoming` 事件，
  由目标侧 `resolve_incoming` 判定命中并施加伤害。

  差异（TODO(migrate)）：
  - LPC 另要求 dodge>=160；本版仅以 huashan-jian>=160 与 mapped 把关；
  - LPC 三剑分别对 dodge/force/parry 判定，本版合为一次 parry 判定；
  - 命中判定：`rand(level) > parry/2`，忙乱 `level/22+2` 轮。
  - 伤害计算：`damage = level * 2`（简化），LPC 为 `ap+rand(ap/3|ap/2)`。
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

  @perform_id "huashan-jian/xian"
  @move_name "「夺命连环三仙剑」"

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
      [] -> {:error, @move_name <> "只能在战斗中对对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      :ok
    else
      {:error, "你使用的武器不对！\n"}
    end
  end

  defp check_skill_level(stats) do
    level = Stats.skill(stats, "huashan-jian")

    if level < 160 do
      {:error, "你华山剑法不够娴熟，无法施展#{@move_name}。\n"}
    else
      {:ok, level}
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "huashan-jian" do
      :ok
    else
      {:error, "你没有激发华山剑法，无法使用#{@move_name}。\n"}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你现在真气不够，无法施展#{@move_name}！\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, level) do
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 280}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn =
      Broadcast.publish(
        conn,
        "$N长啸一声，手中剑随即不停转动，汹涌而出，施展#{@move_name}，" <>
          "剑锋突变，一剑顿时化为三剑，袭向$n……\n",
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

    bindings = [n1: attacker.name, n2: character.name, weapon2: weapon_name || "剑"]

    hit = Engine.rand(rng, level) > div(parry, 2)

    if hit do
      damage = level * 2
      combat = Combat.start_busy(combat, div(level, 22) + 2)
      combat = Combat.apply_damage(combat, damage)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "结果$p躲避不及，被$N这一剑震得口吐鲜血，接连后退，受到#{damage}点伤害！\n",
          bindings
        )
      )
      |> put_character(put_combat(character, combat))
    else
      text =
        if weapon_name do
          Messages.interpolate(
            "但是$p斜身闪开，身在空中不及变招，只能挥出一招，正击中$N的剑脊上，飘然避去。\n",
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