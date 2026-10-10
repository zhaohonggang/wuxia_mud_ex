defmodule Kantele.Combat.Skills.Performs.XueDao.Xueyu do
  @moduledoc """
  perform「xueyu」（source xue-dao/xueyu.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"count", "blade"}], "level_gates": [{"force", "120"}, {"xue-dao", "70"}], "map_gates": [{"blade", "xue-dao"}], "prepared_gates": [], "resource_gates": [{"neili", "100"}], "var_gates": [{"i", "5"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「血雨」只能对战斗中的对手使用。\n", "你使用的武器不对。\n", "你的血刀刀法不够娴熟，不会使用「血雨」。\n", "你的内功修为不够高。\n", "你现在真气不够，不能使用「血雨」。\n", "你没有激发血刀刀法，不能使用「血雨」。\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIR", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": ["HIR "$N" HIR "嗔目大喝，手腕一抖，" + weapon->name() +
      #                 HIR "如闪电一般砍向$n" HIR "！\n"NOR"]}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["me->start_busy(1 + random(5));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(5));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // xueyu.c 血雨
      # 
      # #include <ansi.h>
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     object weapon;
      #     string msg;
      #     int count;
      #         int i;
      # 
      #         if (! target)
      #         {
      #             me->clean_up_enemy();
      #             target = me->select_opponent();
      #         }
      #     if (! target || ! me->is_fighting(target))
      #         return notify_fail("「血雨」只能对战斗中的对手使用。\n");
      # 
      #     if (! objectp(weapon = me->query_temp("weapon")) ||
      #         (string)weapon->query("skill_type") != "blade")
      #         return notify_fail("你使用的武器不对。\n");
      # 
      #     if ((int)me->query_skill("xue-dao", 1) < 70)
      #         return notify_fail("你的血刀刀法不够娴熟，不会使用「血雨」。\n");
      # 
      #     if ((int)me->query_skill("force") < 120)
      #         return notify_fail("你的内功修为不够高。\n");
      # 
      #     if ((int)me->query("neili") < 100)
      #         return notify_fail("你现在真气不够，不能使用「血雨」。\n");
      # 
      #         if (me->query_skill_mapped("blade") != "xue-dao")
      #                 return notify_fail("你没有激发血刀刀法，不能使用「血雨」。\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIR "$N" HIR "嗔目大喝，手腕一抖，" + weapon->name() +
      #               HIR "如闪电一般砍向$n" HIR "！\n"NOR;
      # 
      #     message_combatd(msg, me, target);
      #     me->add("neili", -100);
      # 
      #     count = me->query_skill("blade") / 12;
      #     me->add_temp("apply/attack", count);
      # 
      #         for (i = 0; i < 5; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      #             COMBAT_D->do_attack(me, target, weapon, 0);
      #         }
      # 
      #     me->add_temp("apply/attack", -count);
      #         me->start_busy(1 + random(5));
      #     return 1;
      # }
end
