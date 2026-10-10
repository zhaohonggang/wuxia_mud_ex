defmodule Kantele.Combat.Skills.Performs.BaihuaQuan.Cuo do
  @moduledoc """
  perform「cuo」（source baihua-quan/cuo.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"count", "baihua-quan"}, {"lvl", "baihua-quan"}], "level_gates": [{"baihua-quan", "160"}], "map_gates": [], "prepared_gates": [{"claw", "baihua-quan"}, {"cuff", "baihua-quan"}, {"hand", "baihua-quan"}, {"strike", "baihua-quan"}, {"unarmed", "baihua-quan"}], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["百花错乱只能对战斗中的对手使用。\n", "你现在没有准备使用百花错拳，无法施展百花错乱！\n", "百花错乱须是空手才能施展。\n", "你的真气不够，无法施展百花错乱。\n", "你的百花错拳还不够纯熟！\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "只见$N使出百花错拳的精妙百花错乱，擒拿手中夹着鹰爪功，左手查拳，右手绵掌。攻\n"
      #                     "出去是八卦掌，收回时已是太极拳，诸家杂陈，毫无规律，只令$n眼花缭乱。\n\n" NOR", "= HIY "$n只见$N运拳如奔，快拳缤纷递出，连忙振作精神勉强抵挡。\n" NOR"], "success": ["= HIW "$n只感到头晕目眩，只见$N或掌、或爪、或拳、或指铺天盖地的向自己各个部位袭来！\n"
      #                              "只一瞬间，全身竟已多了数十出伤痕，"NOR+HIR"鲜血"NOR+HIW"狂泻不止！\n"NOR"]}, "resource_adds": [{"neili", "-300"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-300"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (i > 5 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(6));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (i > 5 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(6));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
