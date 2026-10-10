defmodule Kantele.Combat.Skills.Performs.LiuheBian.Lianhuan do
  @moduledoc """
  perform「lianhuan」（source liuhe-bian/lianhuan.c，由 translate_perform.py 骨架生成，inherit F_DBASE）

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
      #   %{"assign_refs": [{"dp", "parry"}, {"lvl", "liuhe-bian"}, {"skill", "force"}], "level_gates": [{"dodge", "180"}, {"force", "270"}, {"liuhe-bian", "180"}, {"whip", "180"}], "map_gates": [{"whip", "liuhe-bian"}], "prepared_gates": [], "resource_gates": [], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所用的外功中没有这个功能!\n", "六合连环诀只能对战斗中的对手使用。\n", "你刚刚使用过六合连环诀，内力还未平复！\n", "你手中无鞭，如何能够施展连环诀？\n", "你的内功火候未到，无法配合鞭法施展连环诀！\n", "你鞭法修为不足，还不能使用连环诀！\n", "你六合鞭法修为不足，还不能使用连环诀！\n", "你的内力不够，无法施展！\n", "对方都已经这样了，用不着这么费力吧？\n", "你轻功修为不足，无法快速攻击！\n"], "ap_dp_formulas": %{"ap_formula": "skill + random(skill)", "dp_formula": "target->query_skill("parry", 1) + target->query_skill("dodge", 1)"}, "buff_delete": ["lianhuan"], "callback_functions": [%{"body": "int lvl; 
      #           lvl = (int)me->query_skill("liuhe-bian", 1); 
      #           lvl = lvl / 3; 
      #           me->delete_temp("lianhuan"); 
      #    
      #           if ( me->is_fighting() ) { 
      #                   message_vision(HIR "", "name": "remove_effect", "params": "object me, int amount", "return_type": "void"}], "color_codes": ["CYN", "HIB", "HIC", "HIG", "HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,  
      #                       HIY "\n【天合】，$N舞动手中" + weapon->name() +  
      #                       HIY "瞬息击向$n的额头，啪的一声轻响，顿时一条血印。\n" NOR)", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,  
      #                       HIW "\n【地合】，$N一个横扫打向$n的下盘，$n未能看破企图，一声惨嚎，"  
      #                       + weapon->name() + HIW "鞭端已没入小腿半寸"  
      #                               "，登时连退数步！\n" NOR)", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,  
      #                       HIG "\n【神合】，$N手中" + weapon->name() + HIG "似有灵性一般" 
      #                       "死追着$n而去。\n" NOR)", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,  
      #                       HIC "\n【鬼合】，$N突然面如死灰，动作僵硬，然后杀气却更胜一筹，"  
      #                       + weapon->name() + HIC "发出灵异的光芒，$n几乎看到了死亡的颜色。\n"    NOR)", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,  
      #                       HIB "\n【六合】，$N口中高唱佛号，手中" + weapon->name() +  
      #                       HIB "连环击出，鞭影重重，$n再也支持不住，身上被拉出一条条豁口。\n" NOR)", "= CYN "$n" CYN "不慌不忙，以快打快，将$N" 
      #                       CYN "的招式完全化去。\n" NOR"], "success": ["HIR "\n$N大喝一声，口中轻轻念诵佛经，手中" +  
      #                          weapon->name() + "霍霍，招招连环，" 
      #                          "快如电闪！\n\n" NOR", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,  
      #                       HIR "\n【人合】，$N与" + weapon->name() + HIR"合为一体急射向$n，"  
      #                       "$n措手不急被打的吐血不止！\n" NOR)"]}, "damage_formula": %{"formula": "hurt / i"}, "exp_compare": [{"ap", "dp"}], "resource_adds": [{"neili", "-200"}, {"neili", "-300"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "whip"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}, {"neili", "-300"}], "affect_by": [], "apply_adds": ["damage"], "busy_lines": ["me->start_busy(2);", "me->start_busy(2 + random(3));"], "remote_damage": true, "set_flags": [], "temp_set": ["lianhuan"]}
      #   - me->start_busy(2);
      #   - me->start_busy(2 + random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
