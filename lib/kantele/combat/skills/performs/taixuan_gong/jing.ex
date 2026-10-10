defmodule Kantele.Combat.Skills.Performs.TaixuanGong.Jing do
  @moduledoc """
  perform「白首太玄经」（source taixuan-gong/jing.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "blade"}, {"ap", "sword"}, {"dp", "dodge"}, {"dp", "force"}, {"dp", "unarmed"}, {"lvl", "taixuan-gong"}], "level_gates": [{"blade", "340"}, {"force", "340"}, {"martial-cognize", "260"}, {"sword", "340"}], "map_gates": [{"blade", "taixuan-gong"}, {"sword", "taixuan-gong"}], "prepared_gates": [], "resource_gates": [{"max_neili", "10000"}, {"neili", "850"}], "var_gates": [{"lvl", "340"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你内功修为不够，难以施展", "你内力修为不够，难以施展", "你太玄功火候不够，难以施展", "你没有激发太玄功为刀或剑，难以施展", "你的基本剑法火候不足，难以施展", "你的基本刀法火候不足，难以施展", "你现在真气不够，难以施展", "你武学修养不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "lvl + me->query_skill("blade", 1)", "dp_formula": "target->query_dex() * 2 + target->query_skill("dodge", 1) + 
      #                target->query_skill("parry", 1)"}, "callback_functions": [%{"body": "target->add("neili", -(lvl + random(lvl)));
      #   
      #           return  HIY "$n" HIY "却觉$N" HIY "这招气势恢弘，于是运力奋力抵挡。但是无奈这"
      #                   "招威力惊人，$n" HIY "闷哼一声，倒退几步，顿觉内息涣散，" + weapon->name() + HIY 
      #                   ", "name": "final1", "params": "object me, object target, int damage, object weapon, int lvl", "return_type": "string"}, %{"body": "target->receive_damage("jing", damage / 2, me);
      #           target->receive_wound("jing", damage / 4, me);
      #           return  HIY "$n" HIY "心中一惊，但见$N" HIY "这几招奇异无比，招式变化莫测，"
      #                   "但威力却依然不减，正犹豫间，$n"", "name": "final2", "params": "object me, object target, int damage", "return_type": "string"}, %{"body": "target->start_busy(4 + random(lvl / 40));
      #     
      #           return  HIY "$N" HIY + msg + "法奇妙无比，手中" + weapon->name() + HIY "时而宛若游龙，时而"
      #                   "宛若惊鸿，霎那间$n" HIY "已遍体鳞伤，$N" HIY "猛然将手中" + weapon->name()", "name": "final3", "params": "object me, object target, int damage, object weapon, int lvl, string msg", "return_type": "string"}], "color_codes": ["HIC", "HIM", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": [""剑"", ""刀"", ""法已随意使出，各种招式源源而出，将$n" HIW "笼罩。\n" NOR, me, target)", "COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 80 + random(10),
      #                                            (: final1, me, target, damage, weapon, lvl :))", "HIC "$n" HIC "气贯双臂，凝神以对，竟将$N" HIC "之力卸去。\n" NOR", "COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 95 + random(10),
      #                                             HIY "$n" HIY "冷笑一声，觉得$N" HIY "此招肤浅之极，于"
      #                                             "是随意招架，猛然间，「噗嗤」！一声，" + weapon->name() +
      #                                             HIY "已穿透$n" HIY "的胸膛，鲜血不断涌出。\n" NOR, me , target)", "HIC "$n" HIC "会心一笑，看出$N" HIC "这招中的破绽，随意施招竟将这招化去。\n" NOR", "COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 80 + random(10),
      #                                              (: final2, me, target, damage :))", "HIC "$n" HIC "默运内功，内劲贯于全身，奋力抵挡住$N" HIC "这招。\n" NOR", "COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 80 + random(10),
      #                                             (: final3, me, target, damage, weapon, lvl, sub_msg :))", "HIC "$n" HIC "见这招来势凶猛，身形疾退，瞬间飘出三"
      #                         "丈，方才躲过$N" HIC "这招。\n" NOR", ""法奇妙无比，手中" + weapon->name() + HIY "时而宛若游龙，时而"
      #                   "宛若惊鸿，霎那间$n" HIY "已遍体鳞伤，$N" HIY "猛然将手中" + weapon->name() + HIY "一"
      #                   "转，剑势陡然加快，将$n" HIY "团团围住，竟无一丝空隙！\n" NOR"], "success": []}, "damage_formula": %{"formula": "ap + random(ap)"}, "hit_formula": %{"left_side": "ap * 4 / 5 + random(ap)", "operator": ">", "right_side": "dp"}, "receive_damage_calls": [%{"formula": "damage / 2", "kind": "damage", "part": "jing", "source": "me"}, %{"formula": "damage / 4", "kind": "wound", "part": "jing", "source": "me"}], "resource_adds": [{"neili", "-(lvl + random(lvl))"}, {"neili", "-400 - random(400)"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2 + random(3));", "target->start_busy(4 + random(lvl / 40));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2 + random(3));
      #   - target->start_busy(4 + random(lvl / 40));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
