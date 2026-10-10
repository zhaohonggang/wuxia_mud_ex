defmodule Kantele.Combat.Skills.Performs.HonglianDao.Huo do
  @moduledoc """
  perform「流星火雨」（source honglian-dao/huo.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"force", "120"}, {"honglian-dao", "80"}], "map_gates": [{"blade", "honglian-dao"}], "prepared_gates": [], "resource_gates": [{"max_neili", "800"}, {"neili", "100"}], "var_gates": [{"i", "4"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的内功火候不够，难以施展", "你红莲刀法不够娴熟，难以施展", "你的内力修为不够，难以施展", "你现在真气不够，难以施展", "你没有激发红莲刀法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIR", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": ["HIR "$N" HIR "施出红莲刀法绝技，手中" + weapon->name() +
      #                 HIR "运转如飞，激起层层热浪席卷$n" HIR "周身！\n" NOR"]}, "resource_adds": [{"neili", "-80"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-80"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1 + random(4));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(4));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define HUO "「" HIR "流星火雨" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     object weapon;
      #     string msg;
      #     int i;
      # 
      #         if (userp(me) && ! me->query("can_perform/honglian-dao/huo"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #     if (! target) target = offensive_target(me);
      # 
      #     if (! target || ! me->is_fighting(target))
      #                 return notify_fail(HUO "只能对战斗中的对手使用。\n");
      # 
      #     if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "blade")
      #                 return notify_fail("你使用的武器不对，难以施展" HUO "。\n");
      # 
      #         if ((int)me->query_skill("force") < 120 )
      #                 return notify_fail("你的内功火候不够，难以施展" HUO "。\n");
      # 
      #         if ((int)me->query_skill("honglian-dao", 1) < 80)
      #                 return notify_fail("你红莲刀法不够娴熟，难以施展" HUO "。\n");
      # 
      #         if ((int)me->query("max_neili") < 800)
      #                 return notify_fail("你的内力修为不够，难以施展" HUO "。\n");
      # 
      #         if ((int)me->query("neili") < 100)
      #                 return notify_fail("你现在真气不够，难以施展" HUO "。\n");
      # 
      #         if (me->query_skill_mapped("blade") != "honglian-dao")
      #                 return notify_fail("你没有激发红莲刀法，难以施展" HUO "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIR "$N" HIR "施出红莲刀法绝技，手中" + weapon->name() +
      #               HIR "运转如飞，激起层层热浪席卷$n" HIR "周身！\n" NOR;
      #         message_combatd(msg, me, target);
      # 
      #         me->add("neili", -80);
      # 
      #         for (i = 0; i < 4; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      #                 COMBAT_D->do_attack(me, target, weapon, 0);
      #         }
      # 
      #         me->start_busy(1 + random(4));
      #         return 1;
      # }
end
