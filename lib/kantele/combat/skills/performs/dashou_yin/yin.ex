defmodule Kantele.Combat.Skills.Performs.DashouYin.Yin do
  @moduledoc """
  perform「金刚印」（source dashou-yin/yin.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "hand"}, {"dp", "parry"}, {"skill", "dashou-yin"}], "level_gates": [], "map_gates": [{"hand", "dashou-yin"}], "prepared_gates": [{"hand", "dashou-yin"}], "resource_gates": [{"neili", "150"}], "var_gates": [{"dp", "1"}, {"skill", "100"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的大手印修为不够，难以施展", "你的真气不够，难以施展", "你没有激发大手印，难以施展", "你没有准备大手印，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("hand") + me->query_skill("lamaism", 1)", "dp_formula": "1"}, "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "面容庄重，单手携着劲风朝$n" HIY "猛然拍出，正"
      #                 "是密宗绝学「金刚印」。\n" NOR", "= CYN "可是$p" CYN "不慌不忙，巧妙的架开了$P"
      #                          CYN "的金刚印。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 40,
      #                                              HIR "结果$p" HIR "招架不及，被$P" HIR
      #                                              "这一下打得七窍生烟，吐血连连。\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-40"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-40"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
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
      # #define YIN "「" HIY "金刚印" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         string msg;
      #         int skill, ap, dp, damage;
      # 
      #         if (userp(me) && ! me->query("can_perform/dashou-yin/yin"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         if (! me->is_fighting(target))
      #                 return notify_fail(YIN "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(YIN "只能空手施展。\n");
      # 
      #         skill = me->query_skill("dashou-yin", 1);
      # 
      #         if (skill < 100)
      #                 return notify_fail("你的大手印修为不够，难以施展" YIN "。\n");
      # 
      #         if (me->query("neili") < 150)
      #                 return notify_fail("你的真气不够，难以施展" YIN "。\n");
      # 
      #         if (me->query_skill_mapped("hand") != "dashou-yin")
      #                 return notify_fail("你没有激发大手印，难以施展" YIN "。\n");
      # 
      #         if (me->query_skill_prepared("hand") != "dashou-yin")
      #                 return notify_fail("你没有准备大手印，难以施展" YIN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIY "$N" HIY "面容庄重，单手携着劲风朝$n" HIY "猛然拍出，正"
      #               "是密宗绝学「金刚印」。\n" NOR;
      # 
      #         ap = me->query_skill("hand") + me->query_skill("lamaism", 1);
      #         dp = target->query_skill("parry");
      #         if (dp < 1) dp = 1;
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 me->add("neili", -100);
      #                 me->start_busy(2);
      #                 damage = ap / 2 + random(ap);
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 40,
      #                                            HIR "结果$p" HIR "招架不及，被$P" HIR
      #                                            "这一下打得七窍生烟，吐血连连。\n" NOR);
      #         } else
      #         {
      #                 me->add("neili",-40);
      #                 msg += CYN "可是$p" CYN "不慌不忙，巧妙的架开了$P"
      #                        CYN "的金刚印。\n" NOR;
      #                 me->start_busy(3);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
