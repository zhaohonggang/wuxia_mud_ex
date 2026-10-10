defmodule Kantele.Combat.Skills.Performs.LinjiZhuang.Powerup do
  @moduledoc """
  exert「powerup」（source linji-zhuang/powerup.c，由 translate_perform.py 骨架生成，inherit F_CLEAN_UP）

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
      #   %{"assign_refs": [{"skill", "linji-zhuang"}, {"skill2", "mahayana"}], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "100"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你只能用临济庄提升自己的战斗力。\n", "你的内力不够。\n", "你已经在运功中了。\n"], "buff_delete": ["powerup"], "call_outs": [%{"args": "me, skill / 3, di", "delay": "skill", "fn": "remove_effect"}], "callback_functions": [%{"body": "if (me->query_temp("powerup"))
      #           {
      #                   me->add_temp("apply/attack", -amount);
      #                   me->add_temp("apply/dodge", -amount);
      #                   me->add_temp("apply/damage", -di);", "name": "remove_effect", "params": "object me, int amount, int di", "return_type": "void"}], "color_codes": ["HIR", "MAG", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "receive_damage_calls": [%{"formula": "0", "kind": "damage", "part": "qi", "source": None}], "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": ["attack", "damage", "dodge"], "busy_lines": ["if (me->is_fighting()) me->start_busy(1 + random(3));"], "remote_damage": false, "set_flags": [], "temp_set": ["powerup"]}
      #   - if (me->is_fighting()) me->start_busy(1 + random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

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
