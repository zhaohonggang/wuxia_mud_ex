defmodule Kantele.Combat.Skills.Performs.ZhurongJian.Wan do
  @moduledoc """
  perform「万剑焚云」（source zhurong-jian/wan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "dodge"}, {"lvl", "zhurong-jian"}], "level_gates": [{"force", "220"}, {"zhurong-jian", "160"}], "map_gates": [{"sword", "zhurong-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"affect_by_callbacks": [%{"buff_name": "zhurong_jian", "duration_formula": "lvl / 50 * n + random(lvl / 20)", "id_formula": "me->query("id")", "level_formula": "lvl + random(lvl)"}], "all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你祝融剑法不够娴熟，难以施展", "你没有激发祝融剑法，难以施展", "你的内功火候不够，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("dodge")"}, "callback_functions": [%{"body": "int lvl, n;
      #   
      #           lvl = me->query_skill("zhurong-jian", 1);
      #           n = 1 + random(lvl / 20);
      #   
      #           target->affect_by("zhurong_jian",
      #                   ([ "level"    : lvl + random(lvl),
      #            ", "name": "final", "params": "object me, object target, int damage", "return_type": "string"}], "color_codes": ["CYN", "HIM", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 55,
      #                                             (: final, me, target, damage :))", "CYN "$n" CYN "眼剑" +wn + CYN"已至，强自镇定，"
      #                         "侧身躲过，但对$N" CYN "这招仍是心有余悸。\n" NOR"], "success": ["HIM "\n$N" HIM "剑招突变，将真气注入剑身，剑体顿时变得通红，一式「"
      #                 HIR "万剑焚云" HIM "」使出，霎时呼啸声大作，手中" + wn + HIM "化做"
      #                 "千万柄利刃，笼罩$n" HIM "周身。" NOR"]}, "damage_formula": %{"formula": "ap / 2 + random(ap)"}, "do_damage_calls": [%{"attack_type": "WEAPON_ATTACK", "callback": "final", "damage_factor": 55, "damage_var": "damage"}], "resource_adds": [{"neili", "-100"}, {"neili", "-200"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-200"}], "affect_by": ["zhurong_jian"], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
