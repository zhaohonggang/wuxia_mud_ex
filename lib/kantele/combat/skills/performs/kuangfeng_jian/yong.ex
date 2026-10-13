defmodule Kantele.Combat.Skills.Performs.KuangfengJian.Yong do
  @moduledoc """
  perform「风起云涌」（source kuangfeng-jian/yong.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 装备剑类武器 →
  基本轻功>=140 → 狂风快剑>=140 → 激发 sword 为狂风快剑 → 内力>=250 →
  目标存活（.c 无准备门槛）。
  ap = 剑法 + 轻功；dp = 目标招架 + 目标轻功。
  命中判定：ap/2 + random(ap) > dp。
  命中：伤害 = ap + random(ap/2)、65+random(6)% 外伤，扣 230 内力、忙乱 2；
  未命中：扣 120 内力、忙乱 2。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs
  alias Kantele.Character.Vitals

  @perform_id "kuangfeng-jian/yong"
  @move_name "「风起云涌」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "kuangfeng-jian")
    ap = Stats.skill(stats, "sword") + Stats.skill(stats, "dodge")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      weapon_name = Map.get(weapon, :name)

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
          # 命中文案含 weapon->name()（攻击方武器名），经事件数据传给目标侧
          weapon_name: weapon_name,
          rng: rng
        }
      })

      apply_effect(conn, character, target, weapon_name)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #              (string)weapon->query("skill_type") != "sword")
  # 武器结构体字段是 :skill_type（非 LPC 的 query("skill_type")）
  defp check_weapon(combat) do
    case Combat.weapon(combat) do
      %{skill_type: "sword"} = weapon -> {:ok, weapon}
      _ -> {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill("dodge", 1) < 140) / if (me->query_skill("kuangfeng-jian", 1) < 140)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "dodge") < 140 ->
        {:error, "你的基本轻功的修为不够，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "kuangfeng-jian") < 140 ->
        {:error, "你的狂风快剑修为不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "kuangfeng-jian")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "sword") != "kuangfeng-jian" do
      {:error, "你没有激发狂风快剑，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili") < 250)
  defp check_resources(character) do
    if character.meta.vitals.neili < 250 do
      {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  # LPC: msg = HIW "$N" HIW "凝神聚气，运转手中" + weapon->name() + HIW "，刹那间犹如"
  #               "狂风骤起，风声萧萧，" + weapon->name() + HIW "猛地卷向$n" HIW "。\n" NOR;
  # 两处 weapon->name() 把文案拆成三段字面量，E 侧用 <> weapon_name <> 保持拆分
  defp apply_effect(conn, character, target, weapon_name) do
    msg =
      "$N凝神聚气，运转手中" <> weapon_name <>
        "，刹那间犹如狂风骤起，风声萧萧，" <> weapon_name <> "猛地卷向$n。\n"

    conn
    |> Broadcast.publish(Messages.interpolate(msg, [n1: character.name, n2: target.name]))
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
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
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    weapon_name = Map.get(data, :weapon_name, "")
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("parry") + target->query_skill("dodge");
    dp = Stats.skill(stats, "parry") + Stats.skill(stats, "dodge")

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = ap + random(ap / 2);
      #          do_damage(me, target, WEAPON_ATTACK, damage, 65 + random(6), …);
      #          me->add("neili", -230); me->start_busy(2);
      damage = ap + Engine.rand(rng, div(ap, 2))
      percent = 65 + Engine.rand(rng, 6)
      character = apply_damage(character, damage, percent)
      Performs.feedback(attacker, 230, 2)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "$n看得目瞪口呆，只觉一阵狂风吹过，" <> weapon_name <> "却已透胸而过。\n",
          bindings
        )
      )
      |> put_character(character)
    else
      # LPC: me->add("neili", -120); me->start_busy(2);
      Performs.feedback(attacker, 120, 2)

      conn
      |> Broadcast.publish(
        Messages.interpolate("可是$n微微一笑，轻轻格躲开了$N的剑招。\n", bindings)
      )
      |> put_character(character)
    end
  end

  # LPC: COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, percent, msg)
  # wound = damage * percent / 100（armor 未建模，按 percent 直算）
  defp apply_damage(character, damage, percent) do
    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage * percent, 100))

    %{character | meta: %{character.meta | vitals: vitals}}
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define YONG "「" HIW "风起云涌" NOR "」"
  # 
  # inherit F_SSERVER;
  #  
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  #  
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/kuangfeng-jian/yong"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(YONG "只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #               (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" YONG "。\n");
  # 
  #         if (me->query_skill("dodge", 1) < 140)
  #                 return notify_fail("你的基本轻功的修为不够，难以施展" YONG "。\n");
  # 
  #         if (me->query_skill("kuangfeng-jian", 1) < 140)
  #                 return notify_fail("你的狂风快剑修为不够，难以施展" YONG "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "kuangfeng-jian")
  #                 return notify_fail("你没有激发狂风快剑，难以施展" YONG "。\n");
  # 
  #         if (me->query("neili") < 250)
  #                 return notify_fail("你现在真气不够，难以施展" YONG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "凝神聚气，运转手中" + weapon->name() + HIW "，刹那间犹如"
  #               "狂风骤起，风声萧萧，" + weapon->name() + HIW "猛地卷向$n" HIW "。\n" NOR;
  # 
  #         ap = me->query_skill("sword") + me->query_skill("dodge");
  #         dp = target->query_skill("parry") + target->query_skill("dodge");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 2);
  #                 me->add("neili", - 230);
  #                 me->start_busy(2);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 65 + random(6),
  #                                            HIR "$n" HIR "看得目瞪口呆，只觉一阵狂风吹过，" + weapon->name() + HIR 
  #                                            "却已透胸而过。\n" NOR);
  #         } else
  #         {
  #                 me->add("neili", -120);
  #                 me->start_busy(2);
  #                 msg += CYN "可是$n" CYN "微微一笑，轻轻格躲开了$N"
  #                        CYN "的剑招。\n"NOR;
  #         }
  # 
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
