defmodule Kantele.Combat.Skills.Performs.XuedaoDafa.Shi do
  @moduledoc """
  perform「噬血穹苍」（source xuedao-dafa/shi.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "blade"}, {"count", "xuedao-dafa"}, {"dp", "dodge"}], "level_gates": [{"force", "250"}, {"xuedao-dafa", "180"}], "map_gates": [{"blade", "xuedao-dafa"}, {"force", "xuedao-dafa"}], "prepared_gates": [], "resource_gates": [{"neili", "500"}, {"qi", "100"}], "var_gates": [{"i", "6"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的内功火候不够，难以施展", "你的血刀大法还不到家，难以施展", "你没有激发血刀大法为内功，难以施展", "你没有激发血刀大法为刀法，难以施展", "你目前气血翻滚，难以施展", "你目前真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("blade") + me->query("str") * 10", "dp_formula": "target->query_skill("dodge") + target->query("dex") * 10"}, "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_exp_formulas": [{"lvl", "to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3))"}], "combat_messages": %{"fail": [], "other": ["= CYN "$p" CYN "只见$P" CYN "来势汹涌，难以抵挡，当"
      #                          "即飞身朝后跃出数尺。\n" NOR", "= HIY "\n紧接着$N" HIY "嗔目大喝，手中" + weapon->name() +
      #                  HIY "一振，迸出漫天血光，铺天盖地洒向$n" HIY "！\n"NOR", "= HIY "霎时间$n" HIY "只觉周围杀气弥漫，心底微微一"
      #                          "惊，连忙奋力招架。\n" NOR"], "success": ["HIY "$N" HIY "陡然施出「" HIR "噬血穹苍" HIY "」，手中" +
      #                 weapon->name() + HIY "腾起无边杀意，携着风雷之势向$n" HIY
      #                 "劈斩而去！\n"NOR", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 75,
      #                                              HIR "$n" HIR "只觉眼前一蓬血雨喷洒而出"
      #                                              "，已被$N" HIR "这一刀劈了个正中。\n" NOR)", "= HIR "霎时间$n" HIR "只觉周围杀气弥漫，全身气血翻"
      #                          "滚，甚难招架。\n" NOR"]}, "damage_formula": %{"formula": "ap / 2 + random(ap)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "receive_damage_calls": [%{"formula": "80", "kind": "wound", "part": "qi", "source": None}], "resource_adds": [{"neili", "-200 - random(200)"}], "resource_queries": ["neili", "qi"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (random(3) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(2 + random(6));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - if (random(3) == 1 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(2 + random(6));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
