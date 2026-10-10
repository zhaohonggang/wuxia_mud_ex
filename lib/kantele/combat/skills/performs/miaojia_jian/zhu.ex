defmodule Kantele.Combat.Skills.Performs.MiaojiaJian.Zhu do
  @moduledoc """
  perform「黄龙吐珠」（source miaojia-jian/zhu.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "parry"}], "level_gates": [{"force", "150"}, {"miaojia-jian", "120"}], "map_gates": [{"sword", "miaojia-jian"}], "prepared_gates": [], "resource_gates": [{"max_neili", "1200"}, {"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你苗家剑法不够娴熟，难以施展", "你的内功火候不够，难以施展", "你的内力修为不够，难以施展", "你现在真气不够，难以施展", "你没有激发苗家剑法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "回圈手中" + weapon->name() + HIY "施「黄龙吐珠」斜"
      #                 "贯而出，剑尖顿时吐出一道黄芒，闪电般射向$n" + HIY "！\n" NOR", "= CYN "可是" CYN "$n" CYN "一声冷"
      #                          "笑，飞身一跃而起，避开了" CYN
      #                          "$N" CYN "发出的剑气。\n"NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 60,
      #                                              HIR "$n" HIR "见状连忙格挡，可哪里来得"
      #                                              "及，登时只觉全身一麻，剑气已透胸而过。\n"
      #                                              NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-150"}, {"neili", "-50"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}, {"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
