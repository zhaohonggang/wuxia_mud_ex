defmodule Kantele.Combat.Skills.Performs.LonelySword.Yi do
  @moduledoc """
  perform「yi」（source lonely-sword/yi.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "parry"}], "level_gates": [{"lonely-sword", "120"}], "map_gates": [{"sword", "lonely-sword"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你只能对战斗中的对手使用绝招。\n", "无剑如何运用剑意？\n", "你现在的真气不够，无法使用剑意！\n", "你的独孤九剑还不到家，无法使用剑意！\n", "你没有激发独孤九剑，无法使用剑意！\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("parry") + target->query_skill("martial-cognize",1) +
      #                target->query_skill("lonely-sword")"}, "color_codes": ["CYN", "HIM", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIM "$N" HIM "一剑刺出，连自已也不知道要刺往何处。\n" NOR", "HIM "$N" HIM "随手挥洒手中的" + weapon->name() +
      #                          HIM "，漫无目的，不成任何招式。\n" NOR", "HIM "$N" HIM "斜斜刺出一剑，准头之差，令人匪夷所思。\n" NOR", "= CYN "$n" CYN "淡然处之，并没有将$P"
      #                          CYN "此招放在心上，随手架开，不漏半点破绽。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 60,
      #                                      HIR "$n" HIR "全然无法领会$P"
      #                                              HIR "这莫名其妙的招数，一个疏神，登时受创！\n" NOR)"]}, "damage_formula": %{"formula": "ap + random(ap)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-180"}, {"neili", "-60"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-180"}, {"neili", "-60"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // yi.c 剑意
      # 
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     object weapon;
      #         string msg;
      #         int ap, dp;
      #         int damage;
      # 
      #         if (! target)
      #         {
      #             me->clean_up_enemy();
      #             target = me->select_opponent();
      #         }
      # 
      #     if (! target || ! me->is_fighting(target))
      #         return notify_fail("你只能对战斗中的对手使用绝招。\n");
      # 
      #     if (! objectp(weapon = me->query_temp("weapon")) ||
      #         (string)weapon->query("skill_type") != "sword")
      #         return notify_fail("无剑如何运用剑意？\n");
      # 
      #     if ((int)me->query("neili") < 200)
      #         return notify_fail("你现在的真气不够，无法使用剑意！\n");
      # 
      #     if ((int)me->query_skill("lonely-sword", 1) < 120)
      #         return notify_fail("你的独孤九剑还不到家，无法使用剑意！\n");
      # 
      #     if (me->query_skill_mapped("sword") != "lonely-sword")
      #         return notify_fail("你没有激发独孤九剑，无法使用剑意！\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         switch (random(3))
      #         {
      #         case 0:
      #                 msg = HIM "$N" HIM "一剑刺出，连自已也不知道要刺往何处。\n" NOR;
      #                 break;
      # 
      #         case 1:
      #                 msg = HIM "$N" HIM "随手挥洒手中的" + weapon->name() +
      #                        HIM "，漫无目的，不成任何招式。\n" NOR;
      #                 break;
      # 
      #         default:
      #                 msg = HIM "$N" HIM "斜斜刺出一剑，准头之差，令人匪夷所思。\n" NOR;
      #                 break;
      #         }
      # 
      #         ap = me->query_skill("sword");
      #         dp = target->query_skill("parry") + target->query_skill("martial-cognize",1) +
      #              target->query_skill("lonely-sword");
      #         if (ap / 2 + random(ap) > dp)
      #     {
      #         damage = ap + random(ap);
      #                 me->add("neili", -180);
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 60,
      #                                    HIR "$n" HIR "全然无法领会$P"
      #                                            HIR "这莫名其妙的招数，一个疏神，登时受创！\n" NOR);
      #         me->start_busy(2);
      #     } else
      #     {
      #         msg += CYN "$n" CYN "淡然处之，并没有将$P"
      #                        CYN "此招放在心上，随手架开，不漏半点破绽。\n" NOR;
      #                 me->add("neili", -60);
      #         me->start_busy(3);
      #     }
      #     message_combatd(msg, me, target);
      # 
      #     return 1;
      # }
end
