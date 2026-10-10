defmodule Kantele.Combat.Skills.Performs.KunlunJian.Fanyin do
  @moduledoc """
  perform「域外梵音」（source kunlun-jian/fanyin.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "force"}, {"jing_wound", "sword"}, {"skill", "kunlun-jian"}], "level_gates": [{"force", "180"}, {"kunlun-jian", "120"}, {"tanqin-jifa", "120"}], "map_gates": [{"sword", "kunlun-jian"}], "prepared_gates": [], "resource_gates": [{"max_neili", "2000"}, {"neili", "300"}], "var_gates": [{"dp", "1"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的弹琴技法尚且不够熟练, 难以施展", "你的昆仑剑法等级不够, 难以施展", "你的内功修为不够，难以施展", "你的内力修为尚浅，难以施展", "你的真气不够，难以施展", "你没有激发昆仑剑法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "1"}, "color_codes": ["CYN", "MAG", "NOR"], "combat_messages": %{"fail": [], "other": ["MAG "$N" MAG "微微一笑，左手横握剑柄，右手五"
      #                 "指对准" + weapon->name() + NOR + MAG "剑脊"
      #                 "轻轻弹拨，剑身微颤，声若龙吟。\n顿时发出一"
      #                 "阵清脆的琴音……\n" NOR", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK,
      #                          jing_wound, 60, MAG "$n" MAG "顿时只觉琴音犹"
      #                          "如两柄利剑一般刺进双耳，刹那间头晕目眩，全身"
      #                          "刺痛！\n" NOR)", "= CYN "可是$n" CYN "赶忙宁心静气，收敛心神，丝"
      #                          "毫不受$N" CYN "琴音的干扰。\n" NOR"], "success": []}, "resource_adds": [{"neili", "-200"}, {"neili", "-50"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}, {"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2 + random(2));", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2 + random(2));
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
