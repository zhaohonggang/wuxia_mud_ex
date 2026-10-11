defmodule Kantele.Combat.Skills.Performs.JiuyinShengong.Zhua do
  @moduledoc """
  perform「九阴神爪」（source jiuyin-shengong/zhua.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "jiuyin-shengong/zhua"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jiuyin-shengong")
    ap = Stats.skill(stats, "claw")
    damage = (-1)

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
          damage: damage,
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
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "jiuyin-shengong") < 280 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 300 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 180}
    vitals = %{vitals | neili: vitals.neili - 20}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

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
    Performs.feedback(attacker, 20, 2)
    result = Messages.interpolate("$N这一爪来势好快，正抓中$n的檀中大穴，$n一声惨叫，软绵绵的瘫了下去。
$n连忙腾挪躲闪，然而“扑哧”一声，$N五指正插入$n的，$n一声惨叫，血溅五步。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-180"}, {"neili", "-20"}], "assign_refs": [{"ap", "claw"}, {"ap", "unarmed"}, {"damage", "force"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(2);", "target->start_busy(1 + random(3));", "me->start_busy(2);"], "level_gates": [{"jiuyin-shengong", "280"}], "prepared_gates": [{"claw", "jiuyin-shengong"}, {"unarmed", "jiuyin-shengong"}], "remote_damage": true, "resource_gates": [{"neili", "300"}], "var_gates": [{"damage", "0"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // zhua.c 九阴神抓
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define ZHUA "「" HIR "九阴神爪" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #     int damage;
  #     string msg;
  #     string pmsg;
  #     string *limbs;
  #     string limb;
  #     int ap, dp;
  # 
  #     if (userp(me) && !me->query("can_perform/jiuyin-shengong/zhua"))
  #         return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (!target)
  #         target = offensive_target(me);
  # 
  #     if (!target || !me->is_fighting(target))
  #         return notify_fail(ZHUA "只能对战斗中的对手使用。\n");
  # 
  #     if (me->query_temp("weapon"))
  #         return notify_fail(ZHUA "只能空手施展！\n");
  # 
  #     if ((int)me->query_skill("jiuyin-shengong", 1) < 280)
  #         return notify_fail("你的九阴神功还不够娴熟，不能使用" ZHUA "。\n");
  # 
  #     if ((int)me->query("neili", 1) < 300)
  #         return notify_fail("你现在内力太弱，不能使用" ZHUA "。\n");
  # 
  #     if (me->query_skill_prepared("claw") != "jiuyin-shengong" && me->query_skill_prepared("unarmed") != "jiuyin-shengong")
  #         return notify_fail("你没有准备使用九阴神功，无法施展" ZHUA "。\n");
  # 
  #     if (!living(target))
  #         return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIY "$N" HIY "微微一笑，右手成爪，忽的抓向$n" HIY "的要穴！\n" NOR;
  #     me->add("neili", -20);
  # 
  #     ap = me->query_skill("unarmed");
  #     if (ap < me->query_skill("claw"))
  #         ap = me->query_skill("claw");
  #     ap += me->query_skill("martial-cognize", 1);
  #     dp = target->query_skill("parry") +
  #          target->query_skill("martial-cognize", 1);
  # 
  #     me->want_kill(target);
  #     if (ap / 2 + random(ap * 2) > dp)
  #     {
  #         me->start_busy(2);
  #         me->add("neili", -180);
  #         damage = 0;
  # 
  #         if (me->query("max_neili") > target->query("max_neili") * 2)
  #         {
  #             msg += HIR "$N" HIR "这一爪来势好快，正抓中$n" HIR "的檀中大穴，$n" HIR
  #                        "一声惨叫，软绵绵的瘫了下去。\n" NOR;
  #             damage = -1;
  #         }
  #         else
  #         {
  #             target->start_busy(1 + random(3));
  # 
  #             damage = ap + (int)me->query_skill("force");
  #             //damage = damage / 2 + random(damage / 2);
  #             damage = damage / 2 + random(damage);
  # 
  #             if (arrayp(limbs = target->query("limbs")))
  #                 limb = limbs[random(sizeof(limbs))];
  #             else
  #                 limb = "要害";
  #             pmsg = HIR "$n连忙腾挪躲闪，然而“扑哧”一声，$N" HIR "五指正插入$n" HIR "的" + limb + "，$n" HIR "一声惨叫，血溅五步。\n" NOR;
  #             msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 110, pmsg);
  #         }
  #     }
  #     else
  #     {
  #         me->start_busy(2);
  #         msg += CYN "可是$p" CYN "看破了$P" CYN "的来势，应对得法，避开了这一抓。\n" NOR;
  #     }
  # 
  #     message_combatd(msg, me, target);
  #     if (damage < 0)
  #         target->die(me);
  # 
  #     return 1;
  # }
end
