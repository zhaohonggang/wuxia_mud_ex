defmodule Kantele.Combat.Skills.Performs.YinyangShiertian.Powerup do
  @moduledoc """
  exert「powerup」（source yinyang-shiertian/powerup.c，由 translate_perform.py 生成，inherit F_CLEAN_UP）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat

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

  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 3)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"apply_adds": ["armor", "attack", "damage", "defense", "dodge", "parry", "unarmed_damage"], "assign_refs": [{"skill", "force"}], "busy_lines": ["if (me->is_fighting()) me->start_busy(3);"], "remote_damage": false, "temp_set": ["powerup"]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # inherit F_CLEAN_UP;
  # 
  # void remove_effect(object me, int amount);
  # 
  # int exert(object me, object target)
  # {
  #         int skill;
  # 
  #         if (target != me)
  #                 return notify_fail("你只能用阴阳十二重天来提升自己的战斗力。\n");
  # 
  #         if ((int)me->query_temp("powerup"))
  #                 return notify_fail("你已经在运功中了。\n");
  # 
  #         skill = me->query_skill("force");
  # 
  #         message_combatd(HIR "$N" HIR "双目微闭，体内九阴九阳真气疾速运转十二周天，顿"
  #                         "时只见一股澎湃无比的气劲笼罩全身。\n" NOR, me);
  # 
  #         me->add_temp("apply/attack", skill / 2);
  #         me->add_temp("apply/defense", skill / 2);
  #         me->add_temp("apply/unarmed_damage", skill / 2);
  #         me->add_temp("apply/damage", skill / 2);
  #         me->add_temp("apply/parry", skill / 2);
  #         me->add_temp("apply/dodge", skill / 2);
  #         me->add_temp("apply/armor", skill * 2);
  #         me->set_temp("powerup", 1);
  # 
  #         me->start_call_out((: call_other, __FILE__, "remove_effect",
  #                               me, skill / 2 :), skill);
  # 
  #         if (me->is_fighting()) me->start_busy(3);
  # 
  #         return 1;
  # }
  # 
  # void remove_effect(object me, int amount)
  # {
  #         if (me->query_temp("powerup"))
  #         {
  #                 me->add_temp("apply/attack", -amount);
  #                 me->add_temp("apply/defense", -amount);
  #                 me->add_temp("apply/unarmed_damage", -amount);
  #                 me->add_temp("apply/damage", -amount);
  #                 me->add_temp("apply/parry", -amount);
  #                 me->add_temp("apply/dodge", -amount);
  #                 me->add_temp("apply/armor", -(amount * 4));
  #                 me->delete_temp("powerup");
  #                 tell_object(me, HIW "你的阴阳十二重天运行完毕，将内力收回丹田。\n" NOR);
  #         }
  # }
end
