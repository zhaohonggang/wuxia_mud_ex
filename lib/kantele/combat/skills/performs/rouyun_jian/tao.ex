defmodule Kantele.Combat.Skills.Performs.RouyunJian.Tao do
  @moduledoc """
  perform「三环套月」（source rouyun-jian/tao.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"dodge", "180"}, {"force", "180"}, {"rouyun-jian", "140"}], "map_gates": [{"sword", "rouyun-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对。\n", "你的柔云剑法修为不够，难以施展", "你的内功修为不够，难以施展", "你的轻功修为不够，难以施展", "你的真气不够，难以施展", "你没有激发柔云剑法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIC", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "使出柔云剑法「三环套月」，一招之中另蕴三招，铺天"
      #                 "盖地罩向$n" HIC "！\n" NOR"], "success": []}, "resource_adds": [{"neili", "-150"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}], "affect_by": [], "apply_adds": ["attack", "damage"], "busy_lines": ["me->start_busy(1 + random(3));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # 
      # #define TAO "「" HIC "三环套月" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     object weapon;
      #     string msg;
      # 
      #     if (! target) target = offensive_target(me);
      # 
      #         if (userp(me) && ! me->query("can_perform/rouyun-jian/tao"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #     if (! target || ! me->is_fighting(target))
      #             return notify_fail(TAO "只能在战斗中对对手使用。\n");
      # 
      #     if (! objectp(weapon = me->query_temp("weapon")) ||
      #               (string)weapon->query("skill_type") != "sword")
      #         return notify_fail("你使用的武器不对。\n");
      # 
      #     if (me->query_skill("rouyun-jian", 1) < 140)
      #         return notify_fail("你的柔云剑法修为不够，难以施展" TAO "。\n");
      # 
      #     if (me->query_skill("force") < 180)
      #         return notify_fail("你的内功修为不够，难以施展" TAO "。\n");
      # 
      #     if (me->query_skill("dodge") < 180)
      #         return notify_fail("你的轻功修为不够，难以施展" TAO "。\n");
      # 
      #     if (me->query("neili") < 200)
      #         return notify_fail("你的真气不够，难以施展" TAO "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "rouyun-jian")
      #                 return notify_fail("你没有激发柔云剑法，难以施展" TAO "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIC "$N" HIC "使出柔云剑法「三环套月」，一招之中另蕴三招，铺天"
      #               "盖地罩向$n" HIC "！\n" NOR;
      #         message_combatd(msg, me, target);
      #     me->add("neili", -150);
      # 
      #         me->add_temp("apply/attack", 40);
      #         me->add_temp("apply/damage", 10);
      #           COMBAT_D->do_attack(me, target, weapon, 0);
      # 
      #         me->add_temp("apply/attack", 60);
      #         me->add_temp("apply/damage", 30);
      #     COMBAT_D->do_attack(me, target, weapon, 0);
      # 
      #         me->add_temp("apply/attack", 80);
      #         me->add_temp("apply/damage", 50);
      #     COMBAT_D->do_attack(me, target, weapon, 0);
      # 
      #         me->add_temp("apply/attack", -180);
      #         me->add_temp("apply/damage", -90);
      #     me->start_busy(1 + random(3));
      #     return 1;
      # }
end
