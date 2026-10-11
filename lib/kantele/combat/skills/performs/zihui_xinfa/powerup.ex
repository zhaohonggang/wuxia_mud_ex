defmodule Kantele.Combat.Skills.Performs.ZihuiXinfa.Powerup do
  @moduledoc """
  exert「powerup」（source zihui-xinfa/powerup.c，由 translate_perform.py 生成，inherit F_CLEAN_UP）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView

  @impl true
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

  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对
  defp check_gates(character), do: check_resources(character)

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 100 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}], "apply_adds": ["attack", "defense", "dodge"], "assign_refs": [{"skill", "zihui-xinfa"}], "busy_lines": ["if (me->is_fighting()) me->start_busy(1 + random(3));"], "remote_damage": false, "resource_gates": [{"neili", "100"}], "temp_set": ["powerup"]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // powerup.c
  # 
  # #include <ansi.h>
  # 
  # inherit F_CLEAN_UP;
  # 
  # void remove_effect(object me, int amount);
  # 
  # int exert(object me, object target)
  # {
  #     int skill;
  # 
  #     if (target != me)
  #         return notify_fail("你只能用紫徽心法提升自己的战斗力。\n");
  # 
  #     if ((int)me->query("neili") < 100)
  #         return notify_fail("你的真气不够！");
  # 
  #     if ((int)me->query_temp("powerup"))
  #         return notify_fail("你已经在运功中了。\n");
  # 
  #     skill = me->query_skill("zihui-xinfa", 1);
  # 
  #     me->add("neili", -100);
  # 
  #     message_combatd(HIM "$N一声长啸，脚下按北斗方位连踏七步，身形"
  #                         "急转、飘洒之极！\n" NOR, me);
  # 
  #     me->add_temp("apply/attack", skill / 3);
  #     me->add_temp("apply/dodge", skill / 3);
  #         me->add_temp("apply/defense", skill / 3);
  #     me->set_temp("powerup", 1);
  # 
  #     me->start_call_out( (: call_other, __FILE__, "remove_effect", me, skill / 3 :), skill);
  # 
  #     if (me->is_fighting()) me->start_busy(1 + random(3));
  # 
  #     return 1;
  # }
  # 
  # void remove_effect(object me, int amount)
  # {
  #         if ((int)me->query_temp("powerup"))
  #         {
  #             me->add_temp("apply/attack", -amount);
  #             me->add_temp("apply/dodge", -amount);
  #                 me->add_temp("apply/defense", -amount);
  #             me->delete_temp("powerup");
  #                 tell_object(me, "你的紫徽心法运行完毕，将内力收回丹田。\n");
  #         }
  # }
end
