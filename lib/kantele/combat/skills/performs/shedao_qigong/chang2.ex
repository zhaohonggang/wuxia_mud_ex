defmodule Kantele.Combat.Skills.Performs.ShedaoQigong.Chang2 do
  @moduledoc """
  perform「chang2」（source shedao-qigong/chang2.c，由 translate_perform.py 骨架生成，inherit ?）

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
      #   %{"assign_refs": [], "level_gates": [{"shedao-qigong", "80"}], "map_gates": [], "prepared_gates": [], "resource_gates": [], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["唱仙法只能在战斗中使用。\n", "你的蛇岛奇功不够娴熟，不会使用唱仙法。\n", "你已经唱得太久了，不能再唱了。\n"], "color_codes": ["HIR", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "resource_adds": [{"neili", "100"}], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "100"}], "affect_by": [], "apply_adds": ["attack", "defense", "dodge"], "busy_lines": [], "remote_damage": false, "set_flags": [], "temp_set": []}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // 唱仙法
      # 
      # #include <ansi.h>
      # 
      # int perform(object me)
      # {
      # //    int skill;
      # //    string msg;
      # 
      #     if (! me->is_fighting())
      #         return notify_fail("唱仙法只能在战斗中使用。\n");
      # 
      #     if ((int)me->query_skill("shedao-qigong", 1) < 80)
      #         return notify_fail("你的蛇岛奇功不够娴熟，不会使用唱仙法。\n");
      # 
      #     if ((int)me->query_temp("chang") <= -20)
      #         return notify_fail("你已经唱得太久了，不能再唱了。\n");
      # 
      #     message_combatd(HIR "只听$N" HIR "口中念念有词，顷刻"
      #                         "之间内力大涨！\n" NOR, me);
      #     me->add_temp("apply/attack", -1);
      #     me->add_temp("apply/dodge", -1);
      #     me->add_temp("apply/defense", -1);
      #     me->add_temp("chang", -1);
      #     me->add("neili", 100);
      # 
      #     return 1;
      # }
end
