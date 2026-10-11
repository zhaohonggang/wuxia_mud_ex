defmodule Kantele.Combat.Skills.Performs.LinjiZhuang.Powerup do
  @moduledoc """
  exert「powerup」（source linji-zhuang/powerup.c，由 translate_perform.py 生成，inherit F_CLEAN_UP）

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
  #   %{"add_costs": [{"neili", "-100"}], "apply_adds": ["attack", "damage", "dodge"], "assign_refs": [{"skill", "linji-zhuang"}, {"skill2", "mahayana"}], "busy_lines": ["if (me->is_fighting()) me->start_busy(1 + random(3));"], "remote_damage": false, "resource_gates": [{"neili", "100"}], "temp_set": ["powerup"]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // powerup.c
  # 
  # #include <ansi.h>
  # 
  # inherit F_CLEAN_UP;
  # 
  # void remove_effect(object me, int amount, int di);
  # 
  # int exert(object me, object target)
  # {
  #         int skill, skill2;
  #         int di;
  #         object weapon;
  # 
  #         if (target != me)
  #                 return notify_fail("你只能用临济庄提升自己的战斗力。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你的内力不够。\n");
  # 
  #         if ((int)me->query_temp("powerup"))
  #                 return notify_fail("你已经在运功中了。\n");
  # 
  #         skill = me->query_skill("linji-zhuang", 1);
  #         skill2 = me->query_skill("mahayana", 1);
  # 
  #         me->add("neili", -100);
  #         me->receive_damage("qi", 0);
  # 
  #         if (me->query("sex")) di = 0; else di = skill / 2;
  #         if (di > 100) di = 100;
  #         di += skill2 / 10;
  # 
  #         message_combatd(MAG "$N" MAG "微一凝神，运起临济庄，一声娇喝，"
  #                         "四周的空气仿佛都凝固了！\n" NOR, me);
  # 
  #         if (objectp(weapon = me->query_temp("weapon")))
  #         {
  #                 if (di >= 95)
  #                         message_combatd(HIR "$N" HIR "脸色一沉，运起临济庄神通，霎时间" +
  #                                         weapon->name() + HIR "光华四射，漫起无边杀意。\n" NOR, me);
  #                 else
  #                 if (di >= 80)
  #                         message_combatd(HIR "$N" HIR "潜运内力，只见" +
  #                                         weapon->name() + HIR "闪过一道光华，气势摄人，令人肃穆。\n" NOR, me);
  #                 else
  #                 if (di >= 30)
  #                         message_combatd(HIR "$N" HIR "默运内力，就见那" +
  #                                         weapon->name() + HIR "隐隐透出一股光芒，闪烁不定。\n" NOR, me);
  #         }
  # 
  #         me->add_temp("apply/attack", skill / 3);
  #         me->add_temp("apply/dodge", skill / 3);
  #         me->add_temp("apply/damage", di);
  #         me->set_temp("powerup", 1);
  #         me->start_call_out((: call_other,__FILE__, "remove_effect", me, skill / 3, di :), skill);
  # 
  #         if (me->is_fighting()) me->start_busy(1 + random(3));
  # 
  #         return 1;
  # }
  # 
  # void remove_effect(object me, int amount, int di)
  # {
  #         if (me->query_temp("powerup"))
  #         {
  #                 me->add_temp("apply/attack", -amount);
  #                 me->add_temp("apply/dodge", -amount);
  #                 me->add_temp("apply/damage", -di);
  #                 me->delete_temp("powerup");
  #                 tell_object(me, "你的临济庄运行完毕，将内力收回丹田。\n");
  #         }
  # }
end
