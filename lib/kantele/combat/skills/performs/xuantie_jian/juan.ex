defmodule Kantele.Combat.Skills.Performs.XuantieJian.Juan do
  @moduledoc """
  perform「卷字诀」（source xuantie-jian/juan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "dodge"}], "level_gates": [{"force", "400"}, {"xuantie-jian", "100"}], "map_gates": [{"sword", "xuantie-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "100"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对。\n", "你的玄铁剑法不够娴熟，不能使用", "你的内功火候不够，不能使用", "你现在内力太弱，不能使用", "你没有激发玄铁剑法，不能施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("dodge")"}, "color_codes": ["CYN", "HIW", "HIY", "NOR", "YEL"], "combat_messages": %{"fail": [], "other": ["HIY "$N一抖手中的" + weapon->name() + HIY "，自下而上的朝$n"
      #                 HIY "卷了过去，曲曲折折，变化无常！\n" NOR", "= YEL "$p" YEL "连忙竭力招架，一时无暇反击。\n" NOR", "= CYN "可是$p" CYN "看破了$P" CYN "的企图，斜跃避开了$P"
      #                          CYN "的攻击。\n"NOR"], "success": []}, "resource_adds": [{"neili", "-25"}, {"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-25"}, {"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy(ap / 20 + 2);", "me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy(ap / 20 + 2);
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // juan.c 卷字诀
      # 
      # #include <ansi.h>
      # 
      # inherit F_SSERVER;
      # 
      # #define JUAN "「" HIW "卷字诀" NOR "」"
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         // int damage;
      #         int ap, dp;
      #         string msg;
      # 
      #         if (userp(me) && ! me->query("can_perform/xuantie-jian/juan"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(JUAN "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你使用的武器不对。\n");
      # 
      #         if ((int)me->query_skill("xuantie-jian", 1) < 100)
      #                 return notify_fail("你的玄铁剑法不够娴熟，不能使用" JUAN "。\n");
      # 
      #         if ((int)me->query_skill("force") < 400)
      #                 return notify_fail("你的内功火候不够，不能使用" JUAN "。\n");
      # 
      #         if ((int)me->query("neili") < 100 )
      #                 return notify_fail("你现在内力太弱，不能使用" JUAN "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "xuantie-jian")
      #                 return notify_fail("你没有激发玄铁剑法，不能施展" JUAN "。\n");
      # 
      #         if (target->is_busy())
      #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
      # 
      #         if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIY "$N一抖手中的" + weapon->name() + HIY "，自下而上的朝$n"
      #               HIY "卷了过去，曲曲折折，变化无常！\n" NOR;
      # 
      #         ap = me->query_skill("sword");
      #         dp = target->query_skill("dodge");
      #         if (random(ap) > dp / 2)
      #         {
      #                 target->start_busy(ap / 20 + 2);
      #                 me->add("neili", -50);
      #                 msg += YEL "$p" YEL "连忙竭力招架，一时无暇反击。\n" NOR;
      #         } else
      #         {
      #                 msg += CYN "可是$p" CYN "看破了$P" CYN "的企图，斜跃避开了$P"
      #                        CYN "的攻击。\n"NOR;
      #         me->add("neili", -25);
      #             me->start_busy(2);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
