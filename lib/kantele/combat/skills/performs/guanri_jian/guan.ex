defmodule Kantele.Combat.Skills.Performs.GuanriJian.Guan do
  @moduledoc """
  perform「天洪地炉观」（source guanri-jian/guan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"count", "sword"}, {"dp", "force"}, {"lvl", "guanri-jian"}], "level_gates": [{"guanri-jian", "280"}], "map_gates": [{"sword", "guanri-jian"}], "prepared_gates": [], "resource_gates": [{"max_neili", "5000"}, {"neili", "800"}], "var_gates": [{"i", "9"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"affect_by_callbacks": [%{"buff_name": "zhurong_jian", "duration_formula": "lvl / 50 + random(lvl / 20)", "id_formula": "me->query("id")", "level_formula": "lvl + random(lvl)"}], "all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你观日剑法不够娴熟，难以施展", "你没有激发观日剑法，难以施展", "你的内力修为不够，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("force")"}, "callback_functions": [%{"body": "int lvl = me->query_skill("guanri-jian", 1);
      #   
      #           target->affect_by("zhurong_jian",
      #                   ([ "level"    : lvl + random(lvl),
      #                      "id"       : me->query("id"),
      #               ", "name": "final", "params": "object me, object target, int damage", "return_type": "string"}], "color_codes": ["CYN", "HIR", "HIW", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 150,
      #                                              (: final, me, target, damage :))", "= CYN "可是$n" CYN "看破了$N" CYN "的企图，斜跃避开。\n" NOR"], "success": ["WHT "$N" WHT "施出观日剑法之「" HIW "天洪地炉观"
      #                 HIR "日" HIW "神诀" NOR + WHT "」，将内力尽数注"
      #                 "入" + weapon->name() + WHT "剑身直奔\n$n" WHT
      #                 "而去。霎时间炽炎暴涨，热浪扑面卷来，四周空气便"
      #                 "似沸腾一般。\n" NOR"]}, "damage_formula": %{"formula": "ap + random(ap)"}, "do_damage_calls": [%{"attack_type": "WEAPON_ATTACK", "callback": "final", "damage_factor": 150, "damage_var": "damage"}], "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-600"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-600"}], "affect_by": ["zhurong_jian"], "apply_adds": ["attack", "damage"], "busy_lines": ["me->start_busy(3);", "me->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
