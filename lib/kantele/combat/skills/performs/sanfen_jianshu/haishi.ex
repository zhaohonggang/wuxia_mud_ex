defmodule Kantele.Combat.Skills.Performs.SanfenJianshu.Haishi do
  @moduledoc """
  perform「haishi」（source sanfen-jianshu/haishi.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "dodge"}], "level_gates": [{"dodge", "150"}, {"sanfen-jianshu", "150"}, {"sword", "150"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你不会使用「海市蜃楼」这一绝技！\n", "「海市蜃楼」只能在战斗中对对手使用。\n", "你使用的武器不对。\n", "你的剑术修为不够，目前不能使用「海市蜃楼」！\n", "你的三分剑术的修为不够，不能使用这一绝技！\n", "你的轻功修为不够，无法使用「海市蜃楼」！\n", "你的真气不够！\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("dodge")"}, "color_codes": ["HIC", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "狂喝一声，手中" + weapon->name() +
      #                 HIW "将到之际，突然圈转，使出三分剑术的独得之秘"
      #                 "「海市蜃楼」，一招之中\n又另蕴涵三招，招式繁复狠"
      #                 "辣，剑招虚虚实实，霍霍剑光径直逼向$n"
      #                 HIW "！\n\n" NOR", "= HIC "$n" HIC "见状身形急退，避开了$N"
      #                          HIC "凌厉的攻击！\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 70,
      #                                              HIR "$n" HIR "完全无法辨清虚实，只感一阵触心的刺痛，一声惨叫，已被$N"
      #                                              HIR "凌厉的剑招刺中。\n" NOR)", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 80,
      #                                                      HIR "\n$N" HIR "见$n" HIR "重创之下不禁破绽迭出，"
      #                                                      HIR "冷笑一声，手中" + weapon->name() +
      #                                                      HIR "挥洒，又攻出一剑，正中$p" HIR "胸口。\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-150"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1 + random(2));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(2));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
