defmodule Kantele.Combat.Skills.Performs.YinyangRen.Hua do
  @moduledoc """
  perform「日月无华」（source yinyang-ren/hua.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"level", "yinyang-ren"}], "level_gates": [{"force", "200"}], "map_gates": [{"blade", "yinyang-ren"}, {"sword", "yinyang-ren"}], "prepared_gates": [], "resource_gates": [{"neili", "150"}], "var_gates": [{"level", "180"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你阴阳刃法不够娴熟，难以施展", "你没有激发阴阳刃法，难以施展", "你的内功火候不足，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIG", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIG "\n$N" HIG "使出阴阳刃法「" HIY "日月无华" HIG "」，手"
      #                 "中" + weapon->name() + HIG "光芒瀑涨，刺眼眩目，日月为"
      #                 "之失辉，刹那间光芒已盖向$n" HIG "。" NOR", "CYN "可是$n" CYN "看破了$N"
      #                         CYN "的企图，一丝不乱，应对自若。\n" NOR"], "success": ["HIR "$n" HIR "被耀眼的光芒所惑，心中惊"
      #                         "疑不定，一时间不知如何应对！\n" NOR"]}, "resource_adds": [{"neili", "-120"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-120"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy(level / 24 + 2);", "me->start_busy(1);", "me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy(level / 24 + 2);
      #   - me->start_busy(1);
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
