defmodule Kantele.Combat.Skills.Performs.Hamagong.Reserve do
  @moduledoc """
  exert「reserve」（source hamagong/reserve.c，由 translate_perform.py 骨架生成，inherit F_CLEAN_UP）

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
      #   %{"assign_refs": [{"skill", "hamagong"}], "level_gates": [{"hamagong", "120"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你的蛤蟆功不够娴熟，不会经脉倒转。\n", "你现在的真气不够。\n", "你已经倒转经脉了。\n"], "color_codes": ["HIB", "NOR"], "combat_messages": %{"fail": [], "other": ["HIB "$N" HIB "忽地双手撑地倒立，逆运经脉，顿时"
      #                 "内息暗生，防御力大增。\n" NOR"], "success": []}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": ["armor", "dispel_poison", "dodge", "parry"], "busy_lines": ["if (me->is_fighting()) me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": ["hmg_dzjm"]}
      #   - if (me->is_fighting()) me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // reserve.c 蛤蟆功经脉倒转
      # 
      # #include <ansi.h>
      # 
      # inherit F_CLEAN_UP;
      # 
      # void remove_effect(object me, int a_amount);
      # 
      # int exert(object me, object target)
      # {
      #         // object weapon;
      #         int skill;
      #         string msg;
      # 
      #         if ((int)me->query_skill("hamagong", 1) < 120)
      #                 return notify_fail("你的蛤蟆功不够娴熟，不会经脉倒转。\n");
      # 
      #         if ((int)me->query("neili") < 200)
      #                 return notify_fail("你现在的真气不够。\n");
      # 
      #         if ((int)me->query_temp("hmg_dzjm"))
      #                 return notify_fail("你已经倒转经脉了。\n");
      # 
      #         skill = me->query_skill("hamagong", 1);
      #         msg = HIB "$N" HIB "忽地双手撑地倒立，逆运经脉，顿时"
      #               "内息暗生，防御力大增。\n" NOR;
      #         message_combatd(msg, me);
      # 
      #         me->add_temp("apply/dodge", skill / 3);
      #         me->add_temp("apply/parry", skill / 3);
      #         me->add_temp("apply/armor", skill / 2);
      #         me->add_temp("apply/dispel_poison", skill / 2);
      #         me->set_temp("hmg_dzjm", skill);
      # 
      #         me->add("neili", -100);
      #         if (me->is_fighting()) me->start_busy(2);
      # 
      #         return 1;
      # }
end
