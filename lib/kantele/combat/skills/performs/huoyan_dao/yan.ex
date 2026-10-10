defmodule Kantele.Combat.Skills.Performs.HuoyanDao.Yan do
  @moduledoc """
  perform「天寰神炎」（source huoyan-dao/yan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"force", "200"}, {"huoyan-dao", "150"}], "map_gates": [{"strike", "huoyan-dao"}], "prepared_gates": [{"strike", "huoyan-dao"}], "resource_gates": [{"max_neili", "2000"}, {"neili", "600"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你必须空手才能施展", "你的内功的修为不够，无法施展", "你的火焰刀修为不够，无法施展", "你的真气不够，无法施展", "你没有激发火焰刀，无法施展", "你没有准备火焰刀，无法施展", "施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIR", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": ["HIR "$N" HIR "一声怒嚎，狂催真气注入单掌，掌缘顿时腾起一道烈炎，接二连三朝$n"
      #                 HIR "劈去。\n" NOR"]}, "resource_adds": [{"neili", "-500"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-500"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["me->start_busy(3 + random(2));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3 + random(2));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define YAN "「" HIR "天寰神炎" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     object weapon;
      #     string msg;
      # 
      #         if (userp(me) && ! me->query("can_perform/huoyan-dao/yan"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(YAN "只能在战斗中对对手使用。\n");
      # 
      #         if (me->query_temp("weapon") ||
      #             me->query_temp("secondary_weapon"))
      #                 return notify_fail("你必须空手才能施展" YAN "。\n");
      # 
      #         if (me->query_skill("force") < 200)
      #                 return notify_fail("你的内功的修为不够，无法施展" YAN "。\n");
      # 
      #         if (me->query_skill("huoyan-dao", 1) < 150)
      #                 return notify_fail("你的火焰刀修为不够，无法施展" YAN "。\n");
      # 
      #         if (me->query("neili") < 600 || me->query("max_neili") < 2000)
      #                 return notify_fail("你的真气不够，无法施展" YAN "。\n");
      # 
      #         if (me->query_skill_mapped("strike") != "huoyan-dao")
      #                 return notify_fail("你没有激发火焰刀，无法施展" YAN "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "huoyan-dao")
      #                 return notify_fail("你没有准备火焰刀，无法施展" YAN "。\n");
      # 
      #         if (me->query_skill_prepared("hand") == "dashou-yin")
      #                 return notify_fail("施展" YAN "时火焰刀不宜和密宗大手印互背！\n");
      # 
      #         if (! living(target))
      #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIR "$N" HIR "一声怒嚎，狂催真气注入单掌，掌缘顿时腾起一道烈炎，接二连三朝$n"
      #               HIR "劈去。\n" NOR;
      #         message_combatd(msg, me, target);
      # 
      #     me->add("neili", -500);
      # 
      #         me->add_temp("apply/attack", 10);
      #           COMBAT_D->do_attack(me, target, weapon, 0);
      # 
      #         me->add_temp("apply/attack", 10);
      #     COMBAT_D->do_attack(me, target, weapon, 0);
      # 
      #         me->add_temp("apply/attack", 10);
      #     COMBAT_D->do_attack(me, target, weapon, 0);
      # 
      #         me->add_temp("apply/attack", 10);
      #     COMBAT_D->do_attack(me, target, weapon, 0);
      # 
      #         me->add_temp("apply/attack", 10);
      #     COMBAT_D->do_attack(me, target, weapon, 0);
      # 
      #         // 消除攻击修正
      #         me->add_temp("apply/attack", -50);
      # 
      #     me->start_busy(3 + random(2));
      # 
      #     return 1;
      # }
end
