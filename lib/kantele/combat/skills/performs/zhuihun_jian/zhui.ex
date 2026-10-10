defmodule Kantele.Combat.Skills.Performs.ZhuihunJian.Zhui do
  @moduledoc """
  perform「追魂夺命」（source zhuihun-jian/zhui.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "dodge"}], "level_gates": [{"zhuihun-jian", "100"}], "map_gates": [{"sword", "zhuihun-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你没有激发追魂夺命剑，难以施展", "你的追魂夺命剑还不够娴熟，难以施展", "你现在真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("dodge")"}, "callback_functions": [%{"body": "return  HIR "只听$n" HIR "一声惨叫，被这一剑穿胸而入，顿"
      #                   "时鲜血四处飞溅。\n" NOR;", "name": "final", "params": "object me, object target, int damage", "return_type": "string"}], "color_codes": ["CYN", "HIR", "NOR"], "combat_messages": %{"fail": ["= CYN "可$n" CYN "却是镇定逾恒，一丝不乱，"
      #                          "全神将此招化解开来。\n" NOR"], "other": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 60,
      #                                              (: final, me, target, damage :))"], "success": ["HIR "$N" HIR "一声冷哼，手中" + weapon->name() +
      #                 HIR "一式「追魂夺命」，剑身顿时漾起一道血光，直射$n"
      #                 HIR "！\n" NOR"]}, "damage_formula": %{"formula": "ap / 2 + random(ap / 2)"}, "do_damage_calls": [%{"attack_type": "WEAPON_ATTACK", "callback": "final", "damage_factor": 60, "damage_var": "damage"}], "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-150"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
