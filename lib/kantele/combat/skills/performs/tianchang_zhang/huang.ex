defmodule Kantele.Combat.Skills.Performs.TianchangZhang.Huang do
  @moduledoc """
  perform「huang」（source tianchang-zhang/huang.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "force"}, {"skill", "tianchang-zhang"}], "level_gates": [], "map_gates": [{"strike", "tianchang-zhang"}], "prepared_gates": [], "resource_gates": [{"neili", "150"}], "var_gates": [{"dp", "1"}, {"skill", "100"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「地老天荒」只能对战斗中的对手使用。\n", "必须空手才能施展「地老天荒」。\n", "你没有激发天长掌法，无法施展「地老天荒」。\n", "你的天长掌法修为有限，不能使用「地老天荒」！\n", "你的真气不够，无法运用「地老天荒」！\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike", 1) / 2 + skill", "dp_formula": "1"}, "color_codes": ["HIC", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["= HIC "然而$n" HIC "内功深湛，丝毫不为$N"
      #                          HIC "的掌风所动，若无其事" NOR"], "success": ["HIR "$N" HIR "“嚯”的一声震喝，提起掌来，只见掌心一片血红，倏的凌空拍出，"
      #                 HIR "一股热风登时袭向$n" HIR "的胸前大穴。\n" NOR", "= COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 45,
      #                                              HIR "$n" HIR "一时间只觉得气血上涌，浑"
      #                                              "身如遭火焚，气息大乱，不由得吐了一口"
      #                                              "鲜血。\n" NOR)"]}, "damage_formula": %{"formula": "skill + random(skill / 3)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-120"}, {"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-120"}, {"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // huang.c 地老天荒
      # 
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         string msg;
      #         int skill, ap, dp, damage;
      # 
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         if (! me->is_fighting(target))
      #                 return notify_fail("「地老天荒」只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon"))
      #                 return notify_fail("必须空手才能施展「地老天荒」。\n");
      # 
      #         if (me->query_skill_mapped("strike") != "tianchang-zhang")
      #                 return notify_fail("你没有激发天长掌法，无法施展「地老天荒」。\n");
      # 
      #         skill = me->query_skill("tianchang-zhang", 1);
      # 
      #         if (skill < 100)
      #                 return notify_fail("你的天长掌法修为有限，不能使用「地老天荒」！\n");
      # 
      #         if (me->query("neili") < 150)
      #                 return notify_fail("你的真气不够，无法运用「地老天荒」！\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIR "$N" HIR "“嚯”的一声震喝，提起掌来，只见掌心一片血红，倏的凌空拍出，"
      #               HIR "一股热风登时袭向$n" HIR "的胸前大穴。\n" NOR;
      # 
      #         ap = me->query_skill("strike", 1) / 2 + skill;
      #         dp = target->query_skill("force");
      #         if (dp < 1) dp = 1;
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 me->add("neili", -120);
      #                 me->start_busy(2);
      #                 damage = skill + random(skill / 3);
      #                 msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 45,
      #                                            HIR "$n" HIR "一时间只觉得气血上涌，浑"
      #                                            "身如遭火焚，气息大乱，不由得吐了一口"
      #                                            "鲜血。\n" NOR);
      #         } else
      #         {
      #                 me->add("neili",-50);
      #                 msg += HIC "然而$n" HIC "内功深湛，丝毫不为$N"
      #                        HIC "的掌风所动，若无其事" NOR;
      #                 me->start_busy(3);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
