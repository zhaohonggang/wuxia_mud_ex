defmodule Kantele.Combat.Skills.Performs.ShenzhangBada.Bafang do
  @moduledoc """
  perform「bafang」（source shenzhang-bada/bafang.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "dodge"}], "level_gates": [{"force", "300"}, {"shenzhang-bada", "200"}], "map_gates": [{"strike", "shenzhang-bada"}], "prepared_gates": [], "resource_gates": [{"neili", "700"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「威镇八方」只能在战斗中对对手使用。\n", "你必须空手才能使用「威镇八方」！\n", "你的内功的修为不够，不能使用这一绝技！\n", "你的神掌八打修为不够，目前不能使用「威镇八方」！\n", "你的真气不够，无法使用「威镇八方」！\n", "你没有激发神掌八打，不能使用「威镇八方」！\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike") + me->query_skill("shenzhang-bada",1)", "dp_formula": "target->query_skill("dodge") + target->query_skill("parry")"}, "color_codes": ["CYN", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "深深的吸了一口气，大喝一声，全身衣袍无风自鼓，"
      #                      HIY "然后提气往上一纵，居高临下，双掌奋力击下，刹那间，内劲犹如旋风般"
      #                      "击向$n" + HIY "！\n" NOR", "= COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 70)", "= CYN "可是$p" CYN "看破了$N" CYN "的企图，轻轻"
      #                          CYN "向后飘出数丈，躲过了这一致命的一击！\n"NOR"], "success": []}, "damage_formula": %{"formula": "ap / 2"}, "hit_formula": %{"left_side": "ap / 3 + random(ap)", "operator": ">", "right_side": "dp / 2"}, "resource_adds": [{"neili", "-100"}, {"neili", "-350"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-350"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // bafang.c 威镇八方
      # 
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         // object weapon; 
      #         string msg;
      #         int ap, dp;
      #         int damage;
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail("「威镇八方」只能在战斗中对对手使用。\n");
      # 
      #         if (me->query_temp("weapon") ||
      #             me->query_temp("secondary_weapon"))
      #                 return notify_fail("你必须空手才能使用「威镇八方」！\n");
      # 
      #         if (me->query_skill("force") < 300)
      #                 return notify_fail("你的内功的修为不够，不能使用这一绝技！\n");
      # 
      #         if (me->query_skill("shenzhang-bada", 1) < 200)
      #                 return notify_fail("你的神掌八打修为不够，目前不能使用「威镇八方」！\n");
      # 
      #         if (me->query("neili") < 700)
      #                 return notify_fail("你的真气不够，无法使用「威镇八方」！\n");
      # 
      #         if (me->query_skill_mapped("strike") != "shenzhang-bada")
      #                 return notify_fail("你没有激发神掌八打，不能使用「威镇八方」！\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIY "$N" HIY "深深的吸了一口气，大喝一声，全身衣袍无风自鼓，"
      #                    HIY "然后提气往上一纵，居高临下，双掌奋力击下，刹那间，内劲犹如旋风般"
      #                    "击向$n" + HIY "！\n" NOR;
      # 
      #         ap = me->query_skill("strike") + me->query_skill("shenzhang-bada",1);
      #         dp = target->query_skill("dodge") + target->query_skill("parry");
      # 
      #         if (ap / 3 + random(ap) > dp / 2)
      #         {
      #                 damage = ap / 2;
      #                 damage += random(damage);
      #                 me->add("neili", -350);
      #                 me->start_busy(2);
      #                msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 70);
      #         } else
      #         {
      #                 me->add("neili", -100);
      #                 me->start_busy(3);
      #                 msg += CYN "可是$p" CYN "看破了$N" CYN "的企图，轻轻"
      #                        CYN "向后飘出数丈，躲过了这一致命的一击！\n"NOR;
      #         }
      #                 message_combatd(msg, me, target);
      # 
      #                 return 1;
      # }
end
