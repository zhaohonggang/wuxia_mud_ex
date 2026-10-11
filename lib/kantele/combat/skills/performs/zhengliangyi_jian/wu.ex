defmodule Kantele.Combat.Skills.Performs.ZhengliangyiJian.Wu do
  @moduledoc """
  perform「无声无色」（source zhengliangyi-jian/wu.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  @perform_id "zhengliangyi-jian/wu"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character) do
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
      Stats.skill(stats, "dodge") < 220 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "zhengliangyi-jian") < 160 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "zhengliangyi-jian" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 200}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}], "assign_refs": [{"ap", "sword"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(2);"], "level_gates": [{"dodge", "220"}, {"zhengliangyi-jian", "160"}], "map_gates": [{"sword", "zhengliangyi-jian"}], "remote_damage": true, "resource_gates": [{"neili", "200"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define WU "「" HIW "无声无色" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # string final(object me, object target, int damage);
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/zhengliangyi-jian/wu"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (environment(me)->query("no_fight"))
  #                 return notify_fail("在这里不能攻击他人。\n");
  # 
  #         // 执行天书任务的特殊房间防止龙吟中断剧情。
  #         if (environment(me)->query("skybook"))
  #                 return notify_fail("在这里不能攻击他人。\n");
  # 
  #         if (! target || ! target->is_character()
  #            || target->query("not_living"))
  #                 return notify_fail(WU "只能对对手使用。\n");
  # 
  #         if (target == me)
  #                 return notify_fail("你打算攻击自己？\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，无法施展" WU "。\n");
  # 
  #         if ((int)me->query_skill("zhengliangyi-jian", 1) < 160)
  #                 return notify_fail("你的正两仪剑法不够娴熟，难以施展" WU "。\n");
  # 
  #         if ((int)me->query_skill("dodge") < 220)
  #                 return notify_fail("你的轻功火候不足，难以施展" WU "。\n");
  # 
  #         if (me->query_dex() < 45)
  #                 return notify_fail("你现在身法太差，难以施展" WU "。\n");
  # 
  #         if (me->query("neili") < 200)
  #                 return notify_fail("你现在真气不够，难以施展" WU "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "zhengliangyi-jian") 
  #                 return notify_fail("你没有激发正两仪剑法，难以施展" WU "。\n");
  # 
  #         if ((int)target->query_condition("die_guard"))
  #                 return notify_fail("对方正被官府保护着呢，还是别去招惹。\n");
  # 
  #         if (target->query_competitor())
  #                 return notify_fail("比武的时候最好是正大光明的较量。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "一声阴笑，突然使出一招「无声无色」，疾向$n"
  #               HIW "背后刺去。\n" NOR;
  # 
  #         me->add("neili", -200);
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("parry");
  # 
  #         me->start_busy(2);
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap * 2 / 3 + random(ap / 3);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 30,
  #                                            (: final, me, target, damage :));
  #         } else
  #         {
  #                 msg += HIC "可是$p" HIC "看破了$P" HIC "的企图，飞身"
  #                        "一跃而起，将$P" HIC "这招化解于无形。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  #         me->want_kill(target);
  # 
  #         if (! target->is_killing(me))
  #                 target->kill_ob(me);
  #         return 1;
  # }
  # 
  # string final(object me, object target, int damage)
  # {
  #         object weapon;
  #         weapon = me->query_temp("weapon");
  # 
  #         return  HIW "结果$n" HIW "并没有察觉$N" HIW "的杀意，丝毫没把"
  #                 "这一招放在心上，只\n是身子略微的向前一倾。\n" NOR +
  #                 HIR "霎时只见$N" HIR "招数一紧，顿时只听“嗤啦”一声"
  #                 "破空之响，$n" HIR "\n一声惨嚎，" + weapon->name() +
  #                 HIR "剑身已透背而入。\n" NOR;
  # }
end
