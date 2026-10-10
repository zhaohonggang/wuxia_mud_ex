defmodule Kantele.Combat.Skills.Performs.RuanhongZhusuo.Bohu do
  @moduledoc """
  perform「搏虎诀」（source ruanhong-zhusuo/bohu.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "whip"}, {"dp", "force"}], "level_gates": [{"ruanhong-zhusuo", "150"}], "map_gates": [{"whip", "ruanhong-zhusuo"}], "prepared_gates": [], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，无法施展", "你的软红蛛索不够娴熟，无法施展", "你的真气不够，无法施展", "你没有激发软红蛛索，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("whip") + me->query_skill("force")", "dp_formula": "target->query_skill("force") + target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_exp_formulas": [{"lvl", "to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3))"}], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "一声暴喝，使出「搏虎」诀，手中" + weapon->name() +
      #                 HIY "狂舞，漫天鞭影幻作无数小圈，铺天盖地罩向$n" + HIY "！\n" NOR", "= CYN "可是$p" CYN "运足内力，奋力挡住了"
      #                          CYN "$P" CYN "这神鬼莫测的一击！\n"NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 55,
      #                                              HIR "只听$n" HIR "一声惨叫，" + weapon->name() + HIR
      #                                              "已在$p" + HIR "身上划出数道深可见骨的伤口，皮肉"
      #                                              "分离，鲜血飞溅，苦不堪言！\n" NOR)"]}, "damage_formula": %{"formula": "ap / 4 + random(ap / 3)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-300"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "whip"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-300"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
