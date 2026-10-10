defmodule Kantele.Combat.Skills.Performs.LuohanFumogong.Fireice do
  @moduledoc """
  exert「冰」（source luohan-fumogong/fireice.c，由 translate_perform.py 骨架生成，inherit F_CLEAN_UP）

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
      #   %{"assign_refs": [{"skill", "luohan-fumogong"}], "level_gates": [{"luohan-fumogong", "180"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"max_neili", "4000"}, {"neili", "500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所学的内功中没有这种功能。\n", "你只能用", "你现在正在施展", "你罗汉伏魔功火候不足，难以施展", "你的内力修为不足，难以施展", "你现在的内力不足，难以施展"], "buff_delete": ["fireice"], "call_outs": [%{"args": "me, skill / 5", "delay": "skill", "fn": "remove_effect"}], "callback_functions": [%{"body": "if (me->query_temp("fireice"))
      #           {
      #                   me->add_temp("apply/unarmed_damage", -amount);
      #                   me->add_temp("apply/damage", -amount);
      #                   me->add_temp("apply/armor", "name": "remove_effect", "params": "object me, int amount", "return_type": "void"}], "color_codes": ["HIC", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "receive_damage_calls": [%{"formula": "0", "kind": "damage", "part": "qi", "source": None}], "resource_adds": [{"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-300"}], "affect_by": [], "apply_adds": ["armor", "damage", "unarmed_damage"], "busy_lines": ["me->start_busy(3);"], "remote_damage": false, "set_flags": [], "temp_set": ["fireice"]}
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # 
      # inherit F_CLEAN_UP;
      # 
      # #define FIREICE "「" HIW "冰" HIR "火" HIW "九重天" NOR "」"
      # 
      # void remove_effect(object me, int amount);
      # 
      # int exert(object me, object target)
      # {
      #         int skill;
      #         string fam;
      #         fam = me->query("family/family_name");
      # 
      #         if (userp(me) && ! me->query("skybook/item/xuanbingjiu"))
      #                 return notify_fail("你所学的内功中没有这种功能。\n");
      # 
      #         if (target != me)
      #                 return notify_fail("你只能用" FIREICE "来提升自己的战斗力。\n");
      # 
      #         if ((int)me->query_temp("fireice"))
      #                 return notify_fail("你现在正在施展" FIREICE "。\n");
      # 
      #         if ((int)me->query_skill("luohan-fumogong", 1) < 180)
      #                 return notify_fail("你罗汉伏魔功火候不足，难以施展" FIREICE "。\n");
      # 
      #         if ((int)me->query("max_neili") < 4000)
      #                 return notify_fail("你的内力修为不足，难以施展" FIREICE "。\n");
      # 
      #         if ((int)me->query("neili") < 500)
      #                 return notify_fail("你现在的内力不足，难以施展" FIREICE "。\n");
      # 
      #         skill = me->query_skill("luohan-fumogong", 1);
      #         me->add("neili", -300);
      #         me->receive_damage("qi", 0);
      # 
      #         message_combatd(HIC "$N" HIC "纵声长啸，运转「" HIW "冰"
      #                         HIR "火" HIW "九重天" HIC "」真气，聚力"
      #                         "于掌间，光华流动，煞为壮观。\n" NOR, me);
      # 
      #         me->add_temp("apply/unarmed_damage", skill / 5);
      #         me->add_temp("apply/damage", skill / 5);
      #         me->add_temp("apply/armor", skill * 2 / 5);
      #         me->set_temp("fireice", 1);
      # 
      #         me->start_call_out((: call_other, __FILE__, "remove_effect",
      #                               me, skill / 5 :), skill);
      # 
      #         if (me->is_fighting())
      #                 me->start_busy(3);
      # 
      #         return 1;
      # }
      # 
      # void remove_effect(object me, int amount)
      # {
      #         if (me->query_temp("fireice"))
      #         {
      #                 me->add_temp("apply/unarmed_damage", -amount);
      #                 me->add_temp("apply/damage", -amount);
      #                 me->add_temp("apply/armor", -amount * 2);
      #                 me->delete_temp("fireice");
      #                 tell_object(me, "你的" FIREICE "运行完毕，将内力收回丹田。\n");
      #         }
      # }
end
