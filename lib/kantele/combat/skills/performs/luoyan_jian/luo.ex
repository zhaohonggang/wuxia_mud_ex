defmodule Kantele.Combat.Skills.Performs.LuoyanJian.Luo do
  @moduledoc """
  perform「一剑落九雁」（source luoyan-jian/luo.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"count", "luoyan-jian"}, {"dp", "dodge"}], "level_gates": [{"luoyan-jian", "150"}], "map_gates": [{"sword", "luoyan-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "400"}], "var_gates": [{"i", "9"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你的回风落雁剑不够娴熟，难以施展", "你没有激发回风落雁剑法，难以施展", "你目前的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("dodge")"}, "color_codes": ["HIC", "HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$n" HIY "见$P" HIY "剑势汹涌，寒意顿生，竟"
      #                         "被逼得连连后退，狼狈不已。\n" NOR", "HIC "$n" HIC "见$N" HIC "这几剑来势迅猛无比，毫"
      #                         "无破绽，只得小心应付。\n" NOR"], "success": ["HIW "\n$N" HIW "蓦的一声清啸，施出衡山派绝学「" HIR "一剑落九雁"
      #                 HIW "」，手中" + weapon->name() + HIW "青光荡漾。霎时间回风"
      #                 "落雁剑剑招连绵涌出，有如神助，剑气笼罩$n" HIW "四方。" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-200"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (random(3) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(9));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(3) == 1 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(9));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
