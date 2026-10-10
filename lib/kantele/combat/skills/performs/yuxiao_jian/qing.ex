defmodule Kantele.Combat.Skills.Performs.YuxiaoJian.Qing do
  @moduledoc """
  perform「天地情长」（source yuxiao-jian/qing.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "force"}, {"skill", "yuxiao-jian"}], "level_gates": [], "map_gates": [{"sword", "yuxiao-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "1000"}, {"neili", "300"}], "var_gates": [{"skill", "150"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你没有激发玉箫剑法，难以施展", "你玉箫剑法等级不够，难以施展", "看样子对方真气并不充沛，无需运用", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword") + me->query_skill("force") +
      #                me->query_skill("chuixiao-jiafa", 1)", "dp_formula": "target->query_skill("force") * 2"}, "color_codes": ["HIC", "HIG", "HIM", "NOR"], "combat_messages": %{"fail": [], "other": ["HIG "$N" HIG "手中的" + weapon->name() + HIG "倏的刺出，卷起一阵"
      #                 "阵气旋，不住的往里收缩。\n" NOR", "= HIM "$p" HIM "顿觉$P" HIM "的内力隐藏在一个个气旋中，难"
      #                          "以捉摸去处，只能强运内力抵消。\n" NOR", "= HIC "可是$p" HIC "心神安定，丝毫没有受到困惑。\n"NOR"], "success": []}, "resource_adds": [{"neili", "-120"}, {"neili", "-500"}, {"neili", "-cost"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-120"}, {"neili", "-500"}], "affect_by": [], "apply_adds": [], "busy_lines": ["//me->start_busy(1 + random(3));", "me->start_busy(1);", "me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - //me->start_busy(1 + random(3));
      #   - me->start_busy(1);
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define QING "「" HIG "天地情长" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me)
      # {
      #         string msg;
      #         object weapon, target;
      #         int skill, ap, dp;
      #         int cost;
      # 
      #         if (userp(me) && ! me->query("can_perform/yuxiao-jian/qing"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target)
      #         {
      #             me->clean_up_enemy();
      #             target = me->select_opponent();
      #         }
      # 
      #     if (! target || ! me->is_fighting(target))
      #                 return notify_fail(QING "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你所使用的武器不对，难以施展" QING "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "yuxiao-jian")
      #                 return notify_fail("你没有激发玉箫剑法，难以施展" QING "。\n");
      # 
      #         skill = me->query_skill("yuxiao-jian",1);
      # 
      #         if (skill < 150)
      #                 return notify_fail("你玉箫剑法等级不够，难以施展" QING "。\n");
      # 
      #         if (target->query("neili") < 300)
      #                 return notify_fail("看样子对方真气并不充沛，无需运用" QING "。\n");
      # 
      #         if (me->query("neili") < 1000)
      #                 return notify_fail("你现在的真气不足，难以施展" QING "。\n");
      # 
      #         if (! living(target))
      #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIG "$N" HIG "手中的" + weapon->name() + HIG "倏的刺出，卷起一阵"
      #               "阵气旋，不住的往里收缩。\n" NOR;
      # 
      #         ap = me->query_skill("sword") + me->query_skill("force") +
      #              me->query_skill("chuixiao-jiafa", 1);
      #         dp = target->query_skill("force") * 2;
      #         if (ap > dp && ap / 2 + random(ap) > dp)
      #         {
      #                 me->add("neili", -500);
      #                 msg += HIM "$p" HIM "顿觉$P" HIM "的内力隐藏在一个个气旋中，难"
      #                        "以捉摸去处，只能强运内力抵消。\n" NOR;
      #                 cost = 500 + (ap - dp) * 3 / 2;
      #                 if (cost > target->query("neili"))
      #                         cost = target->query("neili");
      #                 target->add("neili", -cost);
      #                 //me->start_busy(1 + random(3));
      #                 me->start_busy(1);
      #         } else
      #         {
      #                 me->add("neili", -120);
      #                 msg += HIC "可是$p" HIC "心神安定，丝毫没有受到困惑。\n"NOR;
      #                 me->start_busy(2);
      #         }
      #         message_combatd(msg, me, target);
      #         return 1;
      # }
end
