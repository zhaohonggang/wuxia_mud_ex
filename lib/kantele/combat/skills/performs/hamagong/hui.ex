defmodule Kantele.Combat.Skills.Performs.Hamagong.Hui do
  @moduledoc """
  exert「hui」（source hamagong/hui.c，由 translate_perform.py 骨架生成，inherit F_CLEAN_UP）

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
      #   %{"assign_refs": [], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你并没有倒转经脉啊。\n"], "buff_delete": ["hmg_dzjm"], "color_codes": ["HIB", "NOR"], "combat_messages": %{"fail": [], "other": ["HIB "$N" HIB "缓缓吐出一口气，脸色变了变，阴阳不定。\n" NOR"], "success": []}, "resource_sets": [{"neili", "0"}], "target_logic": %{"requires_fighting": false, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": ["armor", "dispel_poison", "dodge", "parry"], "busy_lines": [], "remote_damage": false, "set_flags": [{"neili", "0"}], "temp_set": []}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // hui.c 蛤蟆功回息
      # 
      # #include <ansi.h>
      # 
      # inherit F_CLEAN_UP;
      # 
      # void remove_effect(object me, int a_amount);
      # 
      # int exert(object me, object target)
      # {
      #         int skill;
      #         string msg;
      # 
      #         if (! (skill = me->query_temp("hmg_dzjm")))
      #                 return notify_fail("你并没有倒转经脉啊。\n");
      # 
      #         msg = HIB "$N" HIB "缓缓吐出一口气，脸色变了变，阴阳不定。\n" NOR;
      #         message_combatd(msg, me);
      # 
      #         me->add_temp("apply/dodge", -skill / 3);
      #         me->add_temp("apply/parry", -skill / 3);
      #         me->add_temp("apply/armor", -skill / 2);
      #         me->add_temp("apply/dispel_poison", -skill / 2);
      #         me->delete_temp("hmg_dzjm");
      # 
      #         me->set("neili", 0);
      #         return 1;
      # }
end
