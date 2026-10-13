defmodule Kantele.Combat.Skills.Performs.JueqingZhang.Hun do
  @moduledoc """
  perform「魂飞魄散」（source jueqing-zhang/hun.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 空手（主副兵器均不可）→
  绝情掌>=140 → 激发 strike 为绝情掌 → 准备 strike 为绝情掌 → 内功>=180 →
  内力>=300 → 目标存活。
  ap = 拳脚（strike）；dp = 目标招架（parry）。
  命中判定：ap/2 + random(ap) > dp。
  命中：伤害 = 绝情掌等级 + random(等级)、60% 外伤，扣 200 内力、忙乱 3；
  未命中：扣 100 内力、忙乱 4。
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

  @perform_id "jueqing-zhang/hun"
  @move_name "「魂飞魄散」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jueqing-zhang")
    ap = Stats.skill(stats, "strike")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_prepared(character),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
          rng: rng
        }
      })

      apply_effect(conn, character, target)
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
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #          return notify_fail(HUN "只能空手施展。\n");
  # 框架无副兵器槽，仅检查主兵器
  defp check_weapon(combat) do
    if Combat.weapon(combat) != nil do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill("jueqing-zhang", 1) < 140) …
  #     if (me->query_skill("force") < 180) …
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "jueqing-zhang") < 140 ->
        {:error, "你绝情掌不够娴熟，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "force") < 180 ->
        {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "jueqing-zhang")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "strike") != "jueqing-zhang" do
      {:error, "你没有激发绝情掌，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "jueqing-zhang")
  # prepared_perform 返回绝招 ID（如 jueqing-zhang/hun），须取技能前缀比对
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "strike")

    if prepared == nil or hd(String.split(prepared, "/")) != "jueqing-zhang" do
      {:error, "你没有准备绝情掌，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 300)
  defp check_resources(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
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

  # LPC: msg = HIC "\n$N" HIC "运转真气，……正是绝情谷绝学「魂飞魄散」。\n" NOR;
  # （C 侧各段字面量仅由颜色宏/空白分隔，合并为同一条文案）
  defp apply_effect(conn, character, target) do
    msg =
      "\n$N运转真气，将内力注于掌风之中，双掌猛然拍向$n，掌风凌厉无比，气势凌人，直可惊天地，泣鬼神，正是绝情谷绝学「魂飞魄散」。\n"

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
    lvl = Map.get(data, :level, 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("parry");
    dp = Stats.skill(stats, "parry")

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = me->query_skill("jueqing-zhang", 1); damage += random(damage);
      #          COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60, …);
      damage = lvl + Engine.rand(rng, lvl)
      character = apply_damage(character, damage, 60)
      # LPC: me->start_busy(3); me->add("neili", -200);
      Performs.feedback(attacker, 200, 3)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "但见$N双掌拍来，掌风作响，当真气势凌人。$n顿觉心惊胆战，毫无招架之力，微迟疑间$N这掌已正中$n胸口，顿将$p震退数步。\n",
          bindings
        )
      )
      |> put_character(character)
    else
      # LPC: me->start_busy(4); me->add("neili", -100);
      Performs.feedback(attacker, 100, 4)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "$n见$N这掌拍来，内力充盈，气势凌人，只得奋力向后一纵，才躲过这一掌。\n",
          bindings
        )
      )
      |> put_character(character)
    end
  end

  # LPC: COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, percent, msg)
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
  # #define HUN "「" HIM "魂飞魄散" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/jueqing-zhang/hun"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(HUN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(HUN "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("jueqing-zhang", 1) < 140)
  #                 return notify_fail("你绝情掌不够娴熟，难以施展" HUN "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "jueqing-zhang")
  #                 return notify_fail("你没有激发绝情掌，难以施展" HUN "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "jueqing-zhang")
  #                 return notify_fail("你没有准备绝情掌，难以施展" HUN "。\n");
  # 
  #         if (me->query_skill("force") < 180)
  #                 return notify_fail("你的内功修为不够，难以施展" HUN "。\n");
  # 
  #         if ((int)me->query("neili") < 300)
  #                 return notify_fail("你现在的真气不够，难以施展" HUN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         ap = me->query_skill("strike");
  #         dp = target->query_skill("parry");
  # 
  #         msg = HIC "\n$N" HIC "运转真气，将内力注于掌风之中，双掌猛"
  #               "然拍向$n" HIC "，掌风凌厉无比，气势凌人，直可惊天"
  #               "地，泣鬼神，正是绝情谷绝学「" HIM "魂飞魄散" HIC "」。"
  #               "\n" NOR;
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = (int)me->query_skill("jueqing-zhang", 1);
  #                 damage += random(damage);
  # 
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60,
  #                                            HIR "但见$N" HIR "双掌拍来，掌风作响，"
  #                                            "当真气势凌人。$n" HIR "顿觉心惊胆战，"
  #                                            "毫无招架之力，微迟疑间$N" HIR "这掌"
  #                                            "已正中$n" HIR "胸口，顿将$p震退数步。"
  #                                            " \n" NOR);
  # 
  #                 me->start_busy(3);
  #                 me->add("neili", -200);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "见$N" CYN "这掌拍来，内力"
  #                        "充盈，气势凌人，只得奋力向后一纵，才躲"
  #                        "过这一掌。\n" NOR;
  # 
  #                 me->start_busy(4);
  #                 me->add("neili", -100);
  #         }
  #         message_sort(msg, me, target);
  #         return 1;
  # }
end
