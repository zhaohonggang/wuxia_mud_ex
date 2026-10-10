defmodule Kantele.Combat.Skills.Performs.TiexueDao.Xue do
  @moduledoc """
  perform「血浪滔天」（source tiexue-dao/xue.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

  TODO(migrate): 样本人工校对后，把以下门槛/语义写进 check_* 与 apply_effect。
  以上注释行（TODO(migrate)）校对完成后删除。
  """

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView

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

  # TODO(migrate) 提取器门槛事实（核对后替换为真实查法）：
      #   %{"assign_refs": [{"ap", "blade"}, {"dp", "parry"}], "level_gates": [{"force", "150"}, {"tiexue-dao", "100"}], "map_gates": [{"blade", "tiexue-dao"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你铁血刀法等级不够，难以施展", "你没有激发铁血刀法，难以施展", "你的内功修为不够，难以施展", "你目前的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("blade")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["= CYN "可是$n" CYN "眼明手快，奋力招架，将$N"
      #                          CYN "的招式全部挡开。\n" NOR"], "success": ["HIR "$N" HIR "杀气大盛，手中" + weapon->name() +
      #                 HIR "一振，顿时一道血光从刀锋闪过，将$n"
      #                 HIR "团团裹住。\n" NOR", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 35,
      #                                              HIR "只听$n" HIR "一声惨嚎，嗤啦一声，"
      #                                              "一股血柱自" HIR "血色刀影中激射而出。"
      #                                              "\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-120"}, {"neili", "-80"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-120"}, {"neili", "-80"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define XUE "「" HIR "血浪滔天" NOR "」"
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
      #         if (userp(me) && ! me->query("can_perform/tiexue-dao/xue"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(XUE "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon"))
      #            || (string)weapon->query("skill_type") != "blade")
      #                 return notify_fail("你所使用的武器不对，难以施展" XUE "。\n");
      # 
      #         if (me->query_skill("tiexue-dao", 1) < 100)
      #                 return notify_fail("你铁血刀法等级不够，难以施展" XUE "。\n");
      # 
      #         if (me->query_skill_mapped("blade") != "tiexue-dao")
      #                 return notify_fail("你没有激发铁血刀法，难以施展" XUE "。\n");
      # 
      #         if (me->query_skill("force") < 150)
      #                 return notify_fail("你的内功修为不够，难以施展" XUE "。\n");
      # 
      #         if (me->query("neili") < 200)
      #                 return notify_fail("你目前的真气不足，难以施展" XUE "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIR "$N" HIR "杀气大盛，手中" + weapon->name() +
      #               HIR "一振，顿时一道血光从刀锋闪过，将$n"
      #               HIR "团团裹住。\n" NOR;
      # 
      #         ap = me->query_skill("blade");
      #         dp = target->query_skill("parry");
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = ap / 2 + random(ap / 2);
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 35,
      #                                            HIR "只听$n" HIR "一声惨嚎，嗤啦一声，"
      #                                            "一股血柱自" HIR "血色刀影中激射而出。"
      #                                            "\n" NOR);
      #                 me->start_busy(2);
      #                 me->add("neili", -120);
      #         } else
      #         {
      #                 msg += CYN "可是$n" CYN "眼明手快，奋力招架，将$N"
      #                        CYN "的招式全部挡开。\n" NOR;
      #                 me->start_busy(3);
      #                 me->add("neili", -80);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
