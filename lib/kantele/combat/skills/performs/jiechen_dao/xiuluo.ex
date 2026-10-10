defmodule Kantele.Combat.Skills.Performs.JiechenDao.Xiuluo do
  @moduledoc """
  perform「xiuluo」（source jiechen-dao/xiuluo.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"i", "force"}], "level_gates": [{"blade", "180"}, {"hunyuan-yiqi", "140"}, {"jiechen-dao", "180"}], "map_gates": [{"blade", "jiechen-dao"}, {"force", "hunyuan-yiqi"}], "prepared_gates": [], "resource_gates": [{"max_neili", "3000"}, {"neili", "1000"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「修罗焰」攻击只能对战斗中的对手使用。\n", "你先找把刀再说吧！\n", "你必须使用戒尘刀来施展「修罗焰」。\n", "你的戒尘刀火候还嫌不够，这「修罗焰」绝技不用也罢。\n", "你的基本刀法还不够娴熟，使不出「修罗焰」绝技。\n", "你的心意气混元功等级不够，使不出「修罗焰」绝技。\n", "你的身体还不够强壮，强使「修罗焰」绝技是引火自焚！\n", "你现在这内功平平无奇，如何使得出「修罗焰」绝技来！？\n", "你的内力修为不够，这「修罗焰」绝技不用也罢。\n", "以你目前的内力来看，这「修罗焰」绝技不用也罢。\n"], "buff_delete": ["xiuluo"], "color_codes": ["HIR", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "resource_adds": [{"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-300"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["me->start_busy(1+random(3));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1+random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #        int i, jiali, count; 
      #         // string msg;
      #        object weapon;
      # 
      #        if( !target ) target = offensive_target(me);
      #        if( !target
      #                 || !target->is_character()
      #                 || !me->is_fighting(target)
      #                 || !living(target))
      #                 return notify_fail("「修罗焰」攻击只能对战斗中的对手使用。\n");
      #        if (! objectp(weapon = me->query_temp("weapon")) ||
      #           (string)weapon->query("skill_type") != "blade")
      #                 return notify_fail("你先找把刀再说吧！\n");
      # 
      #         if (me->query_skill_mapped("blade") != "jiechen-dao")
      #                 return notify_fail("你必须使用戒尘刀来施展「修罗焰」。\n");
      # 
      #         if(me->query_skill("jiechen-dao", 1) < 180 )
      #                 return notify_fail("你的戒尘刀火候还嫌不够，这「修罗焰」绝技不用也罢。\n");
      # 
      #         if(me->query_skill("blade", 1) < 180 )
      #                 return notify_fail("你的基本刀法还不够娴熟，使不出「修罗焰」绝技。\n");
      # 
      #         if( (int)me->query_skill("hunyuan-yiqi", 1) < 140 )
      #                 return notify_fail("你的心意气混元功等级不够，使不出「修罗焰」绝技。\n");
      # 
      #         if( (int)me->query_con() < 34)
      #                 return notify_fail("你的身体还不够强壮，强使「修罗焰」绝技是引火自焚！\n");
      # 
      #         if ( me->query_skill_mapped("force") != "hunyuan-yiqi")
      #            return notify_fail("你现在这内功平平无奇，如何使得出「修罗焰」绝技来！？\n");
      # 
      #         if (me->query("max_neili") < 3000)
      #            return notify_fail("你的内力修为不够，这「修罗焰」绝技不用也罢。\n");
      # 
      #         if (me->query("neili") < 1000)
      #            return notify_fail("以你目前的内力来看，这「修罗焰」绝技不用也罢。\n");
      # 
      #         me->add("neili", -300);
      # 
      #         message_vision(HIR "\n突然$N将手中武器从右手交到左手，运出十二分真力，脸色顿时通红，\n"
      #                            "宛如修罗降世。刀刃在内力的催动下立刻攻势大胜，\n"
      #                            "向着$n直劈而下！\n" NOR, me, target);
      # 
      #         i = me->query_skill("force") / 2 * (3+random(4));
      #         jiali = me->query("jiali");
      # 
      #         me->set("jiali", i);
      #         me->add_temp("apply/attack", jiali/2);
      # 
      #         count = 4;
      #         count += random(4);
      #         while (count --)
      #         {
      # 
      #               COMBAT_D->do_attack(me, target, me->query_temp("weapon"), 0);
      #         }
      # 
      #         me->add_temp("apply/attack", -jiali/2);
      #         me->set("jiali", jiali);
      #         if(!me->query_temp("xiuluo")) me->add("neili", -300);
      #         else me->delete_temp("xiuluo");
      # 
      #         me->start_busy(1+random(3));
      #         return 1;
      # }
end
