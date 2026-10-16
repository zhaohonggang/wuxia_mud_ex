defmodule Kantele.Combat.Skills.Performs.DuanjiaSword.Jing do
  @moduledoc """
  惊天一击「jing」（对照 `kungfu/skill/duanjia-sword/jing.c`，inherit F_SSERVER）

  段家剑（剑 sword）攻击绝招：要求真气 >= 300、内功 force >= 120、
  duanjia-sword >= 70、剑已激发映射；命中判定为
  `random(force) > target_force/2`，命中伤害
  `damage=(force+sword)/5; damage+=random(damage)`，并扣除等同伤害的内力
  （外伤 50%）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "duanjia-sword/jing"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_skill_level(stats),
         :ok <- check_force(stats),
         :ok <- check_neili(character),
         :ok <- check_mapped(stats),
         :ok <- check_target_alive(target) do
      apply_perform(conn, character, target, stats)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「惊天一击」只能对战斗中的对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      :ok
    else
      {:error, "你使用的武器不对。\n"}
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "duanjia-sword") < 70 do
      {:error, "你的段家剑法不够娴熟，不会使用「惊天一击」。\n"}
    else
      :ok
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 120 do
      {:error, "你的内功修为不够高。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你现在真气不够，不能使用「惊天一击」。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "duanjia-sword" do
      :ok
    else
      {:error, "你现在没有激发段家剑，不能使用「惊天一击」。\n"}
    end
  end

  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_perform(conn, character, target, stats) do
    # LPC: msg = HIC "$N" HIC "一跃而起，手腕一抖，挽出一个美丽的剑花，飞向$n" HIC "。\n"NOR;
    # NOTE: 全段相邻拼接，无 weapon->name()，为单一字面量。
    start_msg = "$N一跃而起，手腕一抖，挽出一个美丽的剑花，飞向$n。\n"
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    # LPC: damage = (int)me->query_skill("force") + (int)me->query_skill("sword");
    #      damage = damage / 5;
    # 命中判定: random(me->query_skill("force")) > target->query_skill("force") / 2
    base = div(Stats.skill(stats, "force") + Stats.skill(stats, "sword"), 5)

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: Stats.skill(stats, "force"),
        dp: Stats.skill(target.meta.stats, "force"),
        base: base,
        rng: &:rand.uniform/1
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    ap = Map.get(data, :ap, 0)
    dp = Map.get(data, :dp, 0)
    base = Map.get(data, :base, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)

    # LPC: if (random(me->query_skill("force")) > target->query_skill("force") / 2)
    if Engine.rand(rng, max(ap, 1)) > div(dp, 2) do
      # LPC: damage += random(damage);
      #      me->add("neili", -damage);
      #      msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
      #        HIR "只见$N" HIR "人剑合一，穿向$n"
      #        HIR "，$n" HIR "只觉一股热"
      #        "流穿心而过，喉头一甜，鲜血狂喷而出！\n" NOR);
      #      me->start_busy(2);
      damage = base + Engine.rand(rng, max(base, 1))
      vitals = Vitals.damage(character.meta.vitals, :qi, damage)
      vitals = Vitals.wound(vitals, :qi, div(damage * 50, 100))
      character = %{character | meta: %{character.meta | vitals: vitals}}

      hit_msg = "只见$N人剑合一，穿向$n，$n只觉一股热流穿心而过，喉头一甜，鲜血狂喷而出！\n"
      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, damage, 2)

      conn
      |> put_character(character)
    else
      # LPC: msg += HIC "可是$p" HIC "猛地向边上一跃，跳出了$P" HIC "的攻击范围。\n"NOR;
      #      me->add("neili", -100); me->start_busy(3);
      miss_msg = "可是$p猛地向边上一跃，跳出了$P的攻击范围。\n"
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 100, 3)

      conn
      |> put_character(character)
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
