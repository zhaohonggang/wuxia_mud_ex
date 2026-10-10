defmodule Kantele.Combat.Skills.Performs.GuanriJian.Fen do
  @moduledoc """
  perform「焚阳剑」（source guanri-jian/fen.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "force"}, {"lvl", "guanri-jian"}], "level_gates": [{"guanri-jian", "150"}], "map_gates": [{"sword", "guanri-jian"}], "prepared_gates": [], "resource_gates": [{"max_neili", "2000"}, {"neili", "500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"affect_by_callbacks": [%{"buff_name": "zhurong_jian", "duration_formula": "lvl / 50 + random(lvl / 20)", "id_formula": "me->query("id")", "level_formula": "lvl + random(lvl)"}], "all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你观日剑法不够娴熟，难以施展", "你没有激发观日剑法，难以施展", "你的内力修为不够，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("force")"}, "callback_functions": [%{"body": "int lvl = me->query_skill("guanri-jian", 1);
      #   
      #           target->affect_by("zhurong_jian",
      #                   ([ "level"    : lvl + random(lvl),
      #                      "id"       : me->query("id"),
      #               ", "name": "final", "params": "object me, object target, int damage", "return_type": "string"}], "color_codes": ["CYN", "HIR", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 75,
      #                                              (: final, me, target, damage :))", "= CYN "可是$n" CYN "看破了$N"
      #                          CYN "的企图，斜跃避开。\n" NOR"], "success": ["WHT "$N" WHT "运转内力，陡然一势「" HIR "焚阳剑" NOR +
      #                 WHT "」划出，手中" + weapon->name() + WHT "携着一股热"
      #                 "流卷向$n" WHT "全身。\n" NOR"]}, "damage_formula": %{"formula": "ap / 2 + random(ap)"}, "do_damage_calls": [%{"attack_type": "WEAPON_ATTACK", "callback": "final", "damage_factor": 75, "damage_var": "damage"}], "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-300"}], "affect_by": ["zhurong_jian"], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define FEN "「" HIR "焚阳剑" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # string final(object me, object target, int damage);
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         string msg;
      #         int ap, dp, damage;
      # 
      #         if (userp(me) && ! me->query("can_perform/guanri-jian/fen"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(FEN "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你所使用的武器不对，难以施展" FEN "。\n");
      # 
      #         if ((int)me->query_skill("guanri-jian", 1) < 150)
      #                 return notify_fail("你观日剑法不够娴熟，难以施展" FEN "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "guanri-jian")
      #                 return notify_fail("你没有激发观日剑法，难以施展" FEN "。\n");
      # 
      #         if ((int)me->query("max_neili") < 2000)
      #                 return notify_fail("你的内力修为不够，难以施展" FEN "。\n");
      # 
      #         if ((int)me->query("neili") < 500)
      #                 return notify_fail("你现在的真气不足，难以施展" FEN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = WHT "$N" WHT "运转内力，陡然一势「" HIR "焚阳剑" NOR +
      #               WHT "」划出，手中" + weapon->name() + WHT "携着一股热"
      #               "流卷向$n" WHT "全身。\n" NOR;
      # 
      #         ap = me->query_skill("sword");
      #         dp = target->query_skill("force");
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = ap / 2 + random(ap);
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 75,
      #                                            (: final, me, target, damage :));
      # 
      #                 me->start_busy(3);
      #                 me->add("neili", -300);
      #         } else
      #         {
      #                 msg += CYN "可是$n" CYN "看破了$N"
      #                        CYN "的企图，斜跃避开。\n" NOR;
      #                 me->start_busy(4);
      #                 me->add("neili", -100);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
      # 
      # string final(object me, object target, int damage)
      # {
      #         int lvl = me->query_skill("guanri-jian", 1);
      # 
      #         target->affect_by("zhurong_jian",
      #                 ([ "level"    : lvl + random(lvl),
      #                    "id"       : me->query("id"),
      #                    "duration" : lvl / 50 + random(lvl / 20) ]));
      # 
      #         return  HIR "只听$n" HIR "一声惨嚎，几柱鲜血射出，剑伤"
      #                 "处腾起一道烈火，烧得嗤嗤作响。\n" NOR;
      # }
end
