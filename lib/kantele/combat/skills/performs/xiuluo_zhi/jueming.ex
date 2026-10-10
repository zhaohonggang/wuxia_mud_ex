defmodule Kantele.Combat.Skills.Performs.XiuluoZhi.Jueming do
  @moduledoc """
  perform「jueming」（source xiuluo-zhi/jueming.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "finger"}, {"dp", "dodge"}], "level_gates": [{"force", "150"}, {"xiuluo-zhi", "100"}], "map_gates": [{"finger", "xiuluo-zhi"}], "prepared_gates": [], "resource_gates": [{"neili", "500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「修罗绝命指」只能在战斗中对对手使用。\n", "你必须空手才能使用「修罗绝命指」！\n", "你的内功的修为不够，不能使用「修罗绝命指」！\n", "你的修罗指修为不够，目前不能使用「修罗绝命指」！\n", "你的真气不够，无法使用「修罗绝命指」！\n", "你没有激发修罗指，不能使用「修罗绝命指」！\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("finger") + me->query_skill("force")", "dp_formula": "target->query_skill("dodge") + target->query_skill("parry")"}, "color_codes": ["CYN", "HIB", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIB "$N" HIB "忽然面露凶光，身形变的异常飘渺，在$n"
      #                 HIB "的四周游走\n个不停，$n" HIB "正迷茫时，$N" HIB
      #                 "突然近身，毫无声息的一指戳\n出！\n" NOR", "= CYN "可是$n" CYN "看破了$N" CYN "的企图，轻"
      #                          "轻向后飘出数丈，躲过了这\n一致命的一击！\n"
      #                          NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80,
      #                                              HIR "只见$n" HIR "一声惨叫，已被$N" HIR
      #                                              "击中要害部位，只觉眼前一片\n漆黑，身体"
      #                                              "摇摇欲坠！\n" NOR)"]}, "damage_formula": %{"formula": "ap / 3 + random(ap / 3)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-150"}, {"neili", "-350"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}, {"neili", "-350"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
