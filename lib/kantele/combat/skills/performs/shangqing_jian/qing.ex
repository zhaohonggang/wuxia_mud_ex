defmodule Kantele.Combat.Skills.Performs.ShangqingJian.Qing do
  @moduledoc """
  perform「清流剑」（source shangqing-jian/qing.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "shangqing-jian/qing"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "shangqing-jian")
    ap = Stats.skill(stats, "sword")

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
          rng: rng
        }
      })

      apply_effect(conn, character)
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

  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对
  defp check_gates(character) do
    with :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 220 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "shangqing-jian") < 160 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "shangqing-jian" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 400 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 300}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "这里没有可供攻击的对手。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    _stats = character.meta.stats
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 300, 1)
    result = Messages.interpolate("$p奋力抵挡，却哪里招架得住，被$P这一剑刺中要脉，鲜血四处飞溅！
$p只觉眼花缭乱，一时难以勘透其中奥妙，连中数剑，被削得血肉模糊！
$p运气抵挡，可只觉一股无形剑气透体而过，难受之极，喷出数口鲜血！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-300"}], "assign_refs": [{"ap", "sword"}, {"damage", "shangqing-jian"}, {"dp", "dodge"}, {"dp", "force"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(2 + random(3));"], "level_gates": [{"force", "220"}, {"shangqing-jian", "160"}], "map_gates": [{"sword", "shangqing-jian"}], "remote_damage": true, "resource_gates": [{"neili", "400"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define QING "「" HIG "清流剑" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         object weapon;
  #         string wname;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/shangqing-jian/qing"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(QING "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #               (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" QING "。\n");
  # 
  #         if (me->query_skill("force") < 220)
  #                 return notify_fail("你的内功的修为不够，难以施展" QING "。\n");
  # 
  #         if (me->query_skill("shangqing-jian", 1) < 160)
  #                 return notify_fail("你的上清剑法修为不够，难以施展" QING "。\n");
  # 
  #         if (me->query("neili") < 400)
  #                 return notify_fail("你的真气不够，难以施展" QING "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "shangqing-jian")
  #                 return notify_fail("你没有激发上清剑法，难以施展" QING "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         wname = weapon->name();
  # 
  #         damage = (int)me->query_skill("shangqing-jian", 1) / 2;
  #         damage += random(damage / 3);
  # 
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("parry");
  #         msg = HIG "$N" HIG "施出上清剑法「清流剑」绝技，手中" + wname +
  #               HIG "随即一颤，对准$n" HIG "连攻数剑，招式凌厉无比！\n" NOR;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 10,
  #                                            HIR "$p" HIR "奋力抵挡，却哪里招架得住，被$P"
  #                                            HIR "这一剑刺中要脉，鲜血四处飞溅！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "$p" CYN "凝神聚气，硬声声将$P"
  #                        CYN "这一剑架开，丝毫无损。\n" NOR;
  #         }
  # 
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("dodge");
  #         msg += "\n" HIG "却见$N" HIG "跨步上前，手中" + wname +
  #                HIG "剑招陡变，又攻出一剑，剑尖顿闪出数道剑光，"
  #                "笼罩$n" HIG "全身！\n" NOR;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 20,
  #                                            HIR "$p" HIR "只觉眼花缭乱，一时难以勘透其"
  #                                            "中奥妙，连中数剑，被削得血肉模糊！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "丝毫不为$P"
  #                        CYN "华丽的剑光所动，稳稳将这一剑架开。\n" NOR;
  #         }
  # 
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("force");
  #         msg += "\n" HIG "$N" HIG "随即一声大喝，身外化身，剑外化剑，手中"
  #                + wname + HIG "顿时漾起一道青芒，再次攻向$n" HIG "而去！\n"
  #                NOR;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 30,
  #                                            HIR "$p" HIR "运气抵挡，可只觉一股无形剑气"
  #                                            "透体而过，难受之极，喷出数口鲜血！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "$p" CYN "一口气自丹田运了上来，$P"
  #                 CYN "附体剑芒虽然厉害，却未能伤$p" CYN "分毫。\n" NOR;
  #         }
  #         me->start_busy(2 + random(3));
  #         me->add("neili", -300);
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
