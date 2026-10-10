defmodule Kantele.Combat.Skills.Performs.YinyangRen.Heng do
  @moduledoc """
  perform「横空出世」（source yinyang-ren/heng.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "blade"}, {"ap", "sword"}, {"dp", "parry"}], "level_gates": [{"dodge", "200"}, {"force", "200"}, {"yinyang-ren", "180"}], "map_gates": [{"blade", "yinyang-ren"}, {"sword", "yinyang-ren"}], "prepared_gates": [], "resource_gates": [{"max_neili", "2700"}, {"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的内功的修为不够，难以施展", "你的阴阳刃法修为不够，难以施展", "你的轻功火候不够，难以施展", "你的内力修为不足，难以施展", "你的真气不够，难以施展", "你没有激发阴阳刃法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("blade")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIC", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "\n只见$N" HIY "手中" + weapon->name() + HIY "斜指"
      #                 "苍天，猛然间招式突变，" + weapon->name() + HIY "“呼"
      #                 "呼”作响，一式「" HIC "横空出世" HIY "」，力劈虚空，"
      #                 "气压群山，犹如风卷残云般地袭向$n" HIY "。\n" NOR", "CYN "可却见" CYN "$n" CYN "猛的拔地而起，避开了"
      #                          CYN "$N" CYN "来势凶猛的一招。\n" NOR"], "success": ["COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 75,
      #                                              HIR "$n" HIR "见此招来势凶猛， 阻挡不"
      #                                              "及， 顿时被" + weapon->name() + HIR 
      #                                              "所伤，苦不堪言。\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-150"}, {"neili", "-240"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}, {"neili", "-240"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2 + random(2));", "me->start_busy(1 + random(2));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2 + random(2));
      #   - me->start_busy(1 + random(2));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
