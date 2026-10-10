defmodule Kantele.Combat.Skills.Performs.QiankunDanuoyi.Nuoyi do
  @moduledoc """
  perform「nuoyi」（source qiankun-danuoyi/nuoyi.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "force"}, {"dp", "force"}, {"level", "qiankun-danuoyi"}], "level_gates": [{"qiankun-danuoyi", "50"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "400"}], "var_gates": [{"i", "2"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「大挪移」只能对战斗中的对手使用。\n", "你的乾坤大挪移还没有修炼到第二层，无法施展大挪移。\n", "你现在真气不够，无法使用「大挪移」。\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "level + me->query_skill("force") * 2 / 3", "dp_formula": "target->query_skill("force") * 2 / 3 +
      #                target->query_skill("dodge", 1)"}, "color_codes": ["CYN", "HIC", "HIG", "HIM", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIM "$N" HIM "招数忽然的一变，摹可明方，内力四处回旋，无形中牵引着$n"
      #                 HIM "的招式！\n"", "= CYN "然而$p" CYN "内功深厚，并没有被$P"
      #                          CYN "这巧妙的劲力所带动。\n" CYN", "= HIC "结果$p" HIC "的招式莫名其妙的变"
      #                          "了方向，竟然控制不住！幸好身边没有别"
      #                          "人，没有酿成大祸。\n" NOR", "= HIG "结果$p" HIG "发出的招式不由自主"
      #                          "的变了方向，突然攻向" + name + HIG "，不禁令" +
      #                          name + HIG "大吃一惊，招架不迭！" NOR"], "success": ["= HIR "结果$p" HIR "一招击出，正好打在自己的"
      #                          "要害上，不禁一声惨叫，摔跌开去。\n" NOR"]}, "damage_formula": %{"formula": "target->query("max_qi")"}, "hit_formula": %{"left_side": "ap / 3 + random(ap / 3)", "operator": ">", "right_side": "dp"}, "receive_damage_calls": [%{"formula": "damage / 2", "kind": "damage", "part": "qi", "source": "me"}, %{"formula": "damage / 2", "kind": "wound", "part": "qi", "source": "me"}], "resource_adds": [{"neili", "-350"}], "resource_queries": ["max_qi", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-350"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "if (! der->is_busy()) der->start_busy(1);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - if (! der->is_busy()) der->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
