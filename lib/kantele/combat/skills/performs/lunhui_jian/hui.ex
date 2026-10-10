defmodule Kantele.Combat.Skills.Performs.LunhuiJian.Hui do
  @moduledoc """
  perform「真·六道轮回」（source lunhui-jian/hui.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"damage", "lunhui-jian"}, {"dp", "parry"}], "level_gates": [{"buddhism", "500"}, {"force", "750"}, {"lunhui-jian", "500"}], "map_gates": [{"sword", "lunhui-jian"}], "prepared_gates": [], "resource_gates": [{"max_neili", "7500"}, {"neili", "1000"}, {"qi", "0"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的内功修为不够，难以施展", "你的内力修为不够，难以施展", "你对禅宗心法参悟不够，难以施展", "你释迦轮回剑火候不够，难以施展", "你没有激发释迦轮回剑，难以施展", "你现在真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword") +
      #                me->query_skill("buddhism", 1)", "dp_formula": "target->query_skill("parry") +
      #                target->query_skill("buddhism", 1)"}, "buff_delete": ["shield"], "callback_functions": [%{"body": "string msg;
      #   
      #           msg = HIR "$n" HIR "只觉心头一阵凄苦，竟忍不住要落"
      #                 "下泪来，喉咙一甜，呕出一口鲜血。\n" NOR;
      #   
      #           if (! target->query_temp("liudaolunhui"))
      #           {
      #                   msg += WHT "$p忽然察觉到全身的力气竟", "name": "attack1", "params": "object me, object target, int damage", "return_type": "string"}, %{"body": "object weapon;
      #           string wn, msg;
      #   
      #           msg = HIR "忽然间$n" HIR "感到胸口处一阵火热，剑气"
      #                 "袭体，带出一蓬血雨。\n" NOR;
      #   
      #           if (objectp(weapon = target->query_temp("weapon")))
      #           {
      #             ", "name": "attack2", "params": "object me, object target, int damage", "return_type": "string"}, %{"body": "int shd;
      #           string msg;
      #   
      #           msg = HIR "剑锋过处，卷起漫天血浪，$n" HIR "只感头晕目"
      #                 "眩，四肢乏力，难以再战。\n" NOR;
      #   
      #           if (target->query_temp("shield"))
      #           {
      #                   shd = target->quer", "name": "attack3", "params": "object me, object target, int damage", "return_type": "string"}, %{"body": "object cloth, armor;
      #           string cn, an, msg;
      #   
      #           msg = HIR "$n" HIR "顿时大惊失色，瞬间已被$N" HIR "连中"
      #                 "数剑，直削得血肉模糊。\n" NOR;
      #   
      #           if (objectp(cloth = target->query_temp("armor/cloth"))", "name": "attack4", "params": "object me, object target, int damage", "return_type": "string"}, %{"body": "string msg;
      #   
      #           msg = HIR "只见$n" HIR "全身一阵抽搐，被剑锋所携的极寒气流"
      #                 "包裹其中，刺痛难当。\n" NOR;
      #   
      #           if (! target->query_condition("poison"))
      #           {
      #                   target->affect_by("poison",
      #   ", "name": "attack5", "params": "object me, object target, int damage", "return_type": "string"}, %{"body": "string msg;
      #   
      #           msg = HIR "$N" HIR "剑势迅猛之极，令$n" HIR "毫无招架余地，"
      #                 "竟镇怯当场，素手待毙。\n" NOR;
      #   
      #           if (! target->query_temp("no_exert")
      #              || ! target->query_temp("no_perform"))
      #     ", "name": "attack6", "params": "object me, object target, int damage", "return_type": "string"}, %{"body": "string msg;
      #   
      #           msg = HIR "忽然间$n" HIR "感到胸口一阵火热，剑气"
      #                     "已从身体穿过，直飞空中。\n" NOR;
      #   
      #           if (!target->query_temp("no_exert") || !target->query_temp("no_perform"))
      #           {
      #             ", "name": "attack7", "params": "object me, object target, int damage", "return_type": "string"}], "color_codes": ["CYN", "HIM", "HIR", "HIW", "HIY", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 300,
      #                                              (: attack1, me, target, damage :))", "CYN "可是$n" CYN "收敛心神，奋力招"
      #                         "架，将剑招卸于无形。\n" NOR", "COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 300,
      #                                              (: attack2, me, target, damage :))", "CYN "可是$n" CYN "收敛心神，奋力招"
      #                         "架，将剑招卸于无形。\n" NOR", "COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 300,
      #                                              (: attack3, me, target, damage :))", "CYN "可是$n" CYN "收敛心神，奋力招"
      #                         "架，将剑招卸于无形。\n" NOR", "COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 300,
      #                                              (: attack4, me, target, damage :))", "CYN "可是$n" CYN "收敛心神，奋力招"
      #                         "架，将剑招卸于无形。\n" NOR", "COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 300,
      #                                              (: attack5, me, target, damage :))", "CYN "可是$n" CYN "收敛心神，奋力招"
      #                         "架，将剑招卸于无形。\n" NOR", "COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 300,
      #                                              (: attack6, me, target, damage :))", "CYN "可是$n" CYN "收敛心神，奋力招"
      #                         "架，将剑招卸于无形。\n" NOR", "COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 500,
      #                                                     (: attack7, me, target, damage :))", "CYN "可是$n" CYN "收敛心神，奋力招"
      #                                     "架，将剑气卸于无形。\n" NOR", "= WHT "$p忽然察觉到全身的力气竟似一丝"
      #                          "丝远离自己而去，无助之极。\n" NOR", "= WHT "忽听「锵锵锵」几声脆响，$n" WHT "的" + wn +
      #                          WHT "竟被$N" WHT "绞成了块块碎片。\n" NOR", "= WHT "$N" WHT "气劲涌至，宛若刀割，顿时将$n"
      #                          WHT "的护体真气摧毁得荡然无存。\n" NOR", "= WHT "忽听轰然声大作，$n" WHT "身着的" + cn +
      #                          WHT "在$N" WHT "内力激荡下，竟被震得粉碎。\n"
      #                          NOR", "= WHT "忽听「哧啦」一声脆响，$n" WHT "身着的" +
      #                          an + WHT "竟被$N" WHT "震裂，化成块块碎片。\n"
      #                          NOR", "= WHT "霎时间$n" WHT "忽觉一股奇寒散入七经八脉"
      #                          "，仿佛连血液都停止了流动。\n" NOR", "= WHT "$n" WHT "只感到全身真气涣散，丹元瓦解，似"
      #                          "乎所有的武功竟都消逝殆尽。\n" NOR", "= WHT "$n" WHT "只感到全身真气涣散，丹元瓦解，似"
      #                              "乎所有的武功竟都消逝殆尽。\n" NOR"], "success": ["HIR "$n" HIR "只觉心头一阵凄苦，竟忍不住要落"
      #                 "下泪来，喉咙一甜，呕出一口鲜血。\n" NOR", "HIR "忽然间$n" HIR "感到胸口处一阵火热，剑气"
      #                 "袭体，带出一蓬血雨。\n" NOR", "HIR "剑锋过处，卷起漫天血浪，$n" HIR "只感头晕目"
      #                 "眩，四肢乏力，难以再战。\n" NOR", "HIR "$n" HIR "顿时大惊失色，瞬间已被$N" HIR "连中"
      #                 "数剑，直削得血肉模糊。\n" NOR", "HIR "只见$n" HIR "全身一阵抽搐，被剑锋所携的极寒气流"
      #                 "包裹其中，刺痛难当。\n" NOR", "HIR "$N" HIR "剑势迅猛之极，令$n" HIR "毫无招架余地，"
      #                 "竟镇怯当场，素手待毙。\n" NOR", "HIR "忽然间$n" HIR "感到胸口一阵火热，剑气"
      #                     "已从身体穿过，直飞空中。\n" NOR"]}, "damage_formula": %{"formula": "ap + random(ap)"}, "do_damage_calls": [%{"attack_type": "WEAPON_ATTACK", "callback": "attack1", "damage_factor": 300, "damage_var": "damage"}, %{"attack_type": "WEAPON_ATTACK", "callback": "attack2", "damage_factor": 300, "damage_var": "damage"}, %{"attack_type": "WEAPON_ATTACK", "callback": "attack3", "damage_factor": 300, "damage_var": "damage"}, %{"attack_type": "WEAPON_ATTACK", "callback": "attack4", "damage_factor": 300, "damage_var": "damage"}, %{"attack_type": "WEAPON_ATTACK", "callback": "attack5", "damage_factor": 300, "damage_var": "damage"}, %{"attack_type": "WEAPON_ATTACK", "callback": "attack6", "damage_factor": 300, "damage_var": "damage"}, %{"attack_type": "WEAPON_ATTACK", "callback": "attack7", "damage_factor": 500, "damage_var": "damage"}], "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-500 - random(500)"}], "resource_queries": ["max_neili", "neili", "qi"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": ["poison"], "apply_adds": ["armor", "attack", "dodge", "parry"], "busy_lines": ["me->start_busy(3 + random(3));"], "remote_damage": true, "set_flags": [{"consistence", "0"}], "temp_set": ["liudaolunhui", "no_exert", "no_perform"]}
      #   - me->start_busy(3 + random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
