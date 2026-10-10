defmodule Kantele.Combat.Skills.Performs.XuanyuanArrow.Baibu do
  @moduledoc """
  perform「baibu」（source xuanyuan-arrow/baibu.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"skill", "xuanyuan-arrow"}], "level_gates": [{"xuanyuan-arrow", "100"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "100"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["百步穿杨只能在战斗中对对手使用。\n", "你现在手中并没有拿着箭，怎么施展百步穿杨？\n", "至少要有一支箭你才能施展百步穿杨。\n", "你的轩辕箭法不够娴熟，不会使用百步穿杨。\n", "你内力不够了。\n", "对方都已经这样了，用不着这么费力吧？\n"], "amount_calls": [{"query_amount", ""}], "amount_gates": ["3"], "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_d_ahinfo": %{"clear": true, "query": true}, "combat_messages": %{"fail": [], "other": ["HIY "突然间，$N" HIY "几个筋斗倒翻而去，已在$n" HIY
      #                "数丈之外。$n" HIY "正待追击，$N" HIY "忽然转身，好一个「百步穿杨」！\n"
      #                HIY "说时迟，那时快，" HIY + weapon->name() + HIY "已带着破空之声，直射$n"
      #                HIY "面门！\n" NOR", "COMBAT_D->query_ahinfo()))
      #                           msg += pmsg", "= CYN "可是$p" CYN "从容不迫，轻巧的闪过了$P"
      #                          CYN "这一箭。\n" NOR"], "success": ["= HIR "结果$p" HIR "反应不及，中了$P" + HIR "一箭！\n" NOR"]}, "exp_compare": [{"my_exp", "ob_exp"}], "hit_ob_calls": [{"me", "target", "me->query("jiali") + 120"}], "receive_damage_calls": [%{"formula": "skill / 3 + random(skill / 3)", "kind": "wound", "part": "qi", "source": "me"}], "reset_action": true, "resource_adds": [{"neili", "-80"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-80"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
