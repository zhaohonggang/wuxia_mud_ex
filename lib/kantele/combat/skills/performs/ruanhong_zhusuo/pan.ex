defmodule Kantele.Combat.Skills.Performs.RuanhongZhusuo.Pan do
  @moduledoc """
  perform「盘鹰诀」（source ruanhong-zhusuo/pan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"ruanhong-zhusuo", "80"}], "map_gates": [{"whip", "ruanhong-zhusuo"}], "prepared_gates": [], "resource_gates": [{"neili", "100"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，无法施展", "你的软红蛛索不够娴熟，无法施展", "你的真气不够，无法施展", "你没有激发软红蛛索，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIR", "NOR", "YEL"], "combat_messages": %{"fail": [], "other": ["YEL "$N" YEL "使出软红蛛索「盘鹰」诀，手腕轻轻一抖，顿时鞭"
      #                 "影重重，完全笼罩$n" YEL "四周！\n"", "= CYN "可是$p" CYN "看破了$P"
      #                          CYN "的企图，小心应对，并没有上当。\n" NOR"], "success": ["= HIR "$n" HIR "微作诧异，一时勘破不透$N" HIR "招中"
      #                          "奥妙，顿被攻了个措手不及！\n" NOR"]}, "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "whip"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "me->start_busy(1);", "target->start_busy((int)me->query_skill("ruanhong-zhusuo") / 20 + 2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - me->start_busy(1);
      #   - target->start_busy((int)me->query_skill("ruanhong-zhusuo") / 20 + 2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // panying.c 盘鹰诀
      # 
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define PANYING "「" YEL "盘鹰诀" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         string msg;
      # //      int ap, dp;
      # //      int damage;
      #  
      #         if (! target) target = offensive_target(me);
      # 
      #         if (userp(me) && ! me->query("can_perform/ruanhong-zhusuo/panying"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(PANYING "只能在战斗中对对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #               (string)weapon->query("skill_type") != "whip")
      #                 return notify_fail("你使用的武器不对，无法施展" PANYING "。\n");
      # 
      #         if ((int)me->query_skill("ruanhong-zhusuo", 1) < 80)
      #                 return notify_fail("你的软红蛛索不够娴熟，无法施展" PANYING "。\n");
      # 
      #         if (target->is_busy())
      #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
      # 
      #         if (me->query("neili") < 100)
      #                 return notify_fail("你的真气不够，无法施展" PANYING "。\n");
      # 
      #         if (me->query_skill_mapped("whip") != "ruanhong-zhusuo")
      #                 return notify_fail("你没有激发软红蛛索，无法施展" PANYING "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = YEL "$N" YEL "使出软红蛛索「盘鹰」诀，手腕轻轻一抖，顿时鞭"
      #               "影重重，完全笼罩$n" YEL "四周！\n";
      # 
      #         me->start_busy(1);
      # 
      #         if (random(me->query("combat_exp")) > (int)target->query("combat_exp") / 2)
      #         {
      #                 msg += HIR "$n" HIR "微作诧异，一时勘破不透$N" HIR "招中"
      #                        "奥妙，顿被攻了个措手不及！\n" NOR;
      #                 target->start_busy((int)me->query_skill("ruanhong-zhusuo") / 20 + 2);
      #         } else
      #         {
      #                 msg += CYN "可是$p" CYN "看破了$P"
      #                        CYN "的企图，小心应对，并没有上当。\n" NOR;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
