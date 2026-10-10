defmodule Kantele.Combat.Skills.Performs.SuxinJian.He do
  @moduledoc """
  perform「he」（source suxin-jian/he.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"damage", "sword"}], "level_gates": [{"force", "120"}, {"quanzhen-jian", "50"}, {"suxin-jian", "80"}], "map_gates": [{"sword", "suxin-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "400"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["双剑合璧只能对战斗中的对手使用。\n", "你使用的武器不对。\n", "你的内功不够娴熟，不能使用双剑合璧。\n", "你的玉女素心剑不够娴熟，不能使用双剑合璧。\n", "你的全真剑法不够娴熟，不能使用双剑合璧。\n", "你现在内力太弱，不能使用双剑合璧。\n", "你没有激发玉女素心剑，不能使用双剑合璧。\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "左手以全真剑法剑意，右手化玉女剑法剑"
      #                 "招，双剑合璧同时刺出。\n" NOR", "= CYN "可是$p" NOR CYN "看破了$P" NOR CYN "的企图，将"
      #                          "自己的全身上下护得密不透风，令$P" NOR CYN "无计可施。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 65,
      #                                              HIR "$n" HIR "看到$N" HIR "双剑飞舞，招式中所有"
      #                                              "破绽都为另一剑补去，竟不知如何是好！\n"
      #                                              HIR"一呆之下，$N" HIR "的剑招已经破身而入！$n"
      #                                              HIR "一声惨叫之下，登时受了重创！\n" NOR)"]}, "damage_formula": %{"formula": "(int)me->query_skill("sword", 1) +
      #                            (int)me->query_skill("quanzhen-jian", 1) +
      #                            (int)me->query_skill("yunv-jian", 1)"}, "resource_adds": [{"neili", "-350"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-350"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
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
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         int damage;
      #         string msg;
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail("双剑合璧只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你使用的武器不对。\n");
      # 
      #         if ((int)me->query_skill("force") < 120)
      #                 return notify_fail("你的内功不够娴熟，不能使用双剑合璧。\n");
      # 
      #         if ((int)me->query_skill("suxin-jian", 1) < 80)
      #                 return notify_fail("你的玉女素心剑不够娴熟，不能使用双剑合璧。\n");
      # 
      #         if ((int)me->query_skill("quanzhen-jian", 1) < 50)
      #                 return notify_fail("你的全真剑法不够娴熟，不能使用双剑合璧。\n");
      # 
      #         if ((int)me->query("neili", 1) < 400)
      #                 return notify_fail("你现在内力太弱，不能使用双剑合璧。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "suxin-jian")
      #                 return notify_fail("你没有激发玉女素心剑，不能使用双剑合璧。\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIY "$N" HIY "左手以全真剑法剑意，右手化玉女剑法剑"
      #               "招，双剑合璧同时刺出。\n" NOR;
      # 
      #         if (random(me->query_skill("force")) > target->query_skill("force") / 2)
      #         {
      #                 me->start_busy(2);
      # 
      #                 damage = (int)me->query_skill("sword", 1) +
      #                          (int)me->query_skill("quanzhen-jian", 1) +
      #                          (int)me->query_skill("yunv-jian", 1);
      # 
      #                 damage = damage / 2 + random(damage / 2);
      #                 me->add("neili", -350);
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 65,
      #                                            HIR "$n" HIR "看到$N" HIR "双剑飞舞，招式中所有"
      #                                            "破绽都为另一剑补去，竟不知如何是好！\n"
      #                                            HIR"一呆之下，$N" HIR "的剑招已经破身而入！$n"
      #                                            HIR "一声惨叫之下，登时受了重创！\n" NOR);
      #         } else
      #         {
      #                 me->start_busy(3);
      #                 msg += CYN "可是$p" NOR CYN "看破了$P" NOR CYN "的企图，将"
      #                        "自己的全身上下护得密不透风，令$P" NOR CYN "无计可施。\n" NOR;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
