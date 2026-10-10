defmodule Kantele.Combat.Skills.Performs.RanmuDaofa.Huo do
  @moduledoc """
  perform「huo」（source ranmu-daofa/huo.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "ranmu-daofa"}, {"dp", "force"}], "level_gates": [{"force", "250"}, {"ranmu-daofa", "180"}], "map_gates": [{"blade", "ranmu-daofa"}, {"force", "hunyuan-yiqi"}, {"force", "luohan-fumogong"}, {"force", "yijinjing"}], "prepared_gates": [], "resource_gates": [{"max_neili", "3000"}, {"neili", "600"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「火麒蚀月」只能对战斗中的对手使用。\n", "你使用的武器不对。\n", "你现在没有激发少林内功为内功，难以施展「火麒蚀月」。\n", "你的燃木刀法不够娴熟，不能使用火麒蚀月。\n", "你的内功火候不够，不能使用火麒蚀月。\n", "你的内力修为太弱，不能使用火麒蚀月。\n", "你现在内力太弱，不能使用火麒蚀月。\n", "你没有激发燃木刀法，不能施展火麒蚀月。\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("ranmu-daofa", 1) + me->query_skill("force")", "dp_formula": "target->query_skill("force")"}, "color_codes": ["CYN", "HIR", "NOR", "RED"], "combat_messages": %{"fail": [], "other": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 130,
      #                                       RED "只闻一股焦臭从$n" RED "处传来，$n" RED "已被"
      #                                       "$P" RED "这精深奥妙的一"
      #                                       "刀击中，鲜血飞溅而出！\n" NOR)", "= CYN "$p" CYN "见$P" CYN "来势汹汹，不敢抵挡，急忙斜跃避开。\n"NOR"], "success": ["HIR "只见$N" HIR "手中" + weapon->name() + HIR "一抖，刀身登时腾起"
      #                       "滔天烈焰，如浴火麒麟一般席卷$n" HIR "全身！\n"NOR"]}, "damage_formula": %{"formula": "ap + random(ap)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-200"}, {"neili", "-400"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}, {"neili", "-400"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2 + random(2));", "target->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2 + random(2));
      #   - target->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
