defmodule Kantele.Combat.Skills.Performs.Hamagong.Zhen do
  @moduledoc """
  perform「蟾震九天」（source hamagong/zhen.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "force"}, {"dp", "force"}, {"poison", "poison"}, {"skill", "hamagong"}], "level_gates": [{"strike", "200"}], "map_gates": [{"strike", "hamagong"}], "prepared_gates": [{"strike", "hamagong"}], "resource_gates": [{"max_neili", "4000"}, {"neili", "800"}], "var_gates": [{"skill", "240"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["蛤蟆功", "你的蛤蟆功修为不够精深，不能使用", "你的内力修为不够深厚，无法施展", "你的真气不够，无法运用", "你的掌法不够娴熟，无法施展", "你必须空手才能使用", "你必须先将蛤蟆功运用于掌法之中，才能运用", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("force")", "dp_formula": "(target->query_skill("force") + target->query_skill("parry") + target->query_skill("dodge") + target->query_skill("yiyang-zhi") ) / 3"}, "color_codes": ["HIB", "HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIB "$N身子蹲下，左掌平推而出，使的正是$N生平最得意的「蟾震九天」绝招，掌风直逼$n而去！\n" NOR", "HIY "可是$n发觉一股微风扑面而来，却已被逼得呼吸不畅，情知不妙，连忙跃开数尺。\n" NOR", "HIB "$N左掌劲力未消，右掌也跟着推出，功力相叠，" ZHEN "掌风排山倒海般涌向$n！\n"NOR", "HIY "$n喘息未定，又觉一股劲风扑面而来，连忙跃开数尺，狼狈地避开。\n" NOR", "HIB "$N双腿一蹬，双掌相并向前猛力推出，$n连同身前方圆三丈全在" ZHEN "劲力笼罩之下！\n"NOR", "HIY "$n用尽全身力量向右一纵一滚，摇摇欲倒地站了起来，但总算躲开了这致命的一击！\n" NOR"], "success": ["COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 50 + random(hamagong_effect),
      #                                              HIR "$n" HIR "不料$N会使出如此诡异招式，慌忙伸掌抵挡，"
      #                                                  "结果$N蛤蟆功内劲不断袭入，$n全身顿时感到一阵撕裂般的痛苦。\n" NOR)", "COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60 + random(hamagong_effect),
      #                                              HIR "$n" HIR "只觉此招，阴柔无比，诡异莫测，"
      #                                                  "心中一惊，却猛然间觉得一股阴风透骨而过。\n" NOR)", "COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70 + random(hamagong_effect),
      #                                              HIR "$n" HIR "全然无力阻挡，竟被$N" HIY "双掌击得飞起，重重的跌落在地上。\n" NOR)"]}, "damage_formula": %{"formula": "ap"}, "hit_formula": %{"left_side": "ap * 2 / 3 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-400 - random(400)"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3 + random(4));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3 + random(4));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
