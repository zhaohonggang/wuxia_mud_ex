defmodule Kantele.Combat.Skills.Performs.XixingDafa.Suck do
  @moduledoc """
  exert「suck」（source xixing-dafa/suck.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_gates(character) do
      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
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
      Stats.skill(stats, "xixing-dafa") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 1 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.max_neili < 100 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 100 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 10}
    vitals = %{vitals | max_neili: 0}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 7)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-10"}], "assign_refs": [{"amount", "xixing-dafa"}, {"dp", "force"}, {"sp", "force"}], "busy_lines": ["me->start_busy(4 + random(4));", "if (! target->is_busy()) target->start_busy(2);", "me->start_busy(7);"], "level_gates": [{"xixing-dafa", "200"}], "remote_damage": false, "resource_gates": [{"max_neili", "1"}, {"max_neili", "100"}, {"neili", "100"}], "set_flags": [{"max_neili", "0"}], "temp_set": ["sucked"]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // suck.c
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int exert(object me, object target)
  # {
  #     int sp, dp;
  #     int my_max, tg_max;
  #         int amount;
  #         object weapon;
  # 
  #     if (! target || target == me) target = offensive_target(me);
  # 
  #     if (environment(me)->query("no_fight"))
  #         return notify_fail("在这里不能攻击他人。\n");
  # 
  #     if (! objectp(target) || ! me->is_fighting(target))
  #         return notify_fail("你只能吸取战斗中的对手的丹元！\n");
  # 
  #         if (target->query("race") != "人类" ||
  #             target->query("not_living"))
  #                 return notify_fail("搞错了！只有活着的生物才能有丹元！\n");
  # 
  #         my_max = me->query("max_neili");
  #         tg_max = target->query("max_neili");
  # 
  #     if (me->query_temp("sucked"))
  #         return notify_fail("你刚刚吸取过丹元！\n");
  # 
  #         if (! me->is_fighting() || ! target->is_fighting())
  # 
  #     if ((int)me->query_skill("xixing-dafa", 1) < 200)
  #         return notify_fail("你的吸星大法尚未大成，还"
  #                                    "不能吸取对方的丹元收为己用！\n");
  # 
  #     if ((int)me->query("neili") < 100)
  #         return notify_fail("你的内力不够，不能使用吸星大法。\n");
  # 
  #         if ((int)me->query_current_neili_limit() <= my_max)
  #                 return notify_fail("你的内功水平有限，再吸取也是徒劳。\n");
  # 
  #     if ((int)target->query("max_neili") < 100)
  #         return notify_fail( target->name() +
  #             "丹元涣散，功力未聚，你无法从他体内吸取任何东西！\n");
  # 
  #         if ((int)target->query("max_neili") < (int)me->query("max_neili") / 5)
  #         return notify_fail( target->name() +
  #             "的内功修为远不如你，你无法从他体内吸取丹元！\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")))
  #             message_combatd(HIR "$N" HIR "探出右手，平平的拍在$n"
  #                                 HIR "的胸前，似乎没有半点力道。\n\n" NOR,
  #                                 me, target);
  #         else
  #                 message_combatd(HIR "$N" HIR "把手中的" + weapon->name() +
  #                                 HIR "一扬，慢慢的逼向$n" HIR + "，$p"
  #                                 HIR "连忙架住。\n" NOR,
  #                                 me, target);
  # 
  #         if (target->query_skill_mapped("force") == "taixuan-gong")
  #         {
  #                 tell_object(target, HIW + me->name() + HIW "伸出右手，轻轻握在你的手"
  #                              "臂上，试图吸取你的内力，但是你体内的太玄真气猛地将"
  #                              "其反弹回去。\n");
  # 
  #                 return notify_fail(HIG "你伸出右手，轻轻握在" + target->name() +
  #                                    HIG "的手臂上，却猛的感觉一股内劲将你的手弹回。\n" NOR);
  #         }
  # 
  #         if (living(target) && !target->is_killing(me))
  #         {
  #                 me->want_kill(target);
  #                 target->kill_ob(me);
  #         }
  # 
  #         sp = me->query_skill("force");
  #         dp = target->query_skill("force");
  # 
  #     me->set_temp("sucked", 1);
  # 
  #         if ((sp + random(sp) > dp + random(dp) ) || ! living(target))
  #     {
  #         tell_object(target, HIR "你只觉全身乏力，全身功力如"
  #                 "融雪般消失得无影无踪！\n" NOR);
  #         tell_object(me, HIG "你觉得" + target->name() +
  #                 HIG "的丹元自手掌源源不绝地流了进来。\n" NOR);
  # 
  #                 amount = 1 + (me->query_skill("xixing-dafa", 1) - 120) / 10;
  #                 target->add("max_neili", -amount);
  #                 me->add("max_neili", amount);
  #                 me->add("exception/xixing-count", amount * 10);
  #                 SKILL_D("xixing-dafa")->check_count(me);
  #                 if (target->query("max_neili") < 1)
  #             target->set("max_neili", 0);
  # 
  #                 me->start_busy(4 + random(4));
  #                 if (! target->is_busy()) target->start_busy(2);
  #                 me->add("neili", -10);
  # 
  #         call_out("del_sucked", 10, me);
  #     } else
  #     {
  #         message_combatd(HIY "可是$p" HIY "看破了$P" HIY
  #                                 "的企图，运用内力震开了$P" HIY
  #                                 "，随即躲了开去。\n" NOR,
  #                                 me, target);
  #                 me->start_busy(7);
  #         call_out("del_sucked", 20, me);
  #     }
  # 
  #     return 1;
  # }
  # 
  # void del_sucked(object me)
  # {
  #         me->delete_temp("sucked");
  # }
end
