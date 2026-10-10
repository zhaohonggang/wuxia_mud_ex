defmodule Kantele.Combat.Skills.Performs.ZijinbaguaDao.Bagua do
  @moduledoc """
  perform「bagua」（source zijinbagua-dao/bagua.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"count", "zijinbagua-dao"}], "level_gates": [{"force", "220"}, {"zijinbagua-dao", "200"}], "map_gates": [{"blade", "zijinbagua-dao"}], "prepared_gates": [], "resource_gates": [{"max_neili", "2000"}, {"neili", "400"}], "var_gates": [{"i", "5"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「八卦阵芒」只能对战斗中的对手使用。\n", "你的兵器不对。\n", "你的内力修为不够。\n", "你的真气不够！\n", "你的内功火候不够！\n", "你的紫金八卦刀还不到家，无法使用「八卦阵芒」！\n", "你没有激发紫金八卦刀，无法使用「八卦阵芒」！\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIR", "HIY", "MAG", "NOR"], "combat_messages": %{"fail": [], "other": ["MAG "$N" MAG "一声暴喝，手中的" + weapon->name() +
      #                 MAG "刀芒陡长，顿时只见万股凌厉的刀芒按照八卦阵的"
      #                 "方位直涌$n" MAG "！\n\n" NOR", "= HIY "$n" HIY "心底微微一惊，打起精神小心接招。\n" NOR"], "success": ["= HIR "$n" HIR "见来招实在是变幻莫测，不由得心"
      #                          "生惧意，招式登时出了破绽！\n" NOR"]}, "resource_adds": [{"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-300"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (random(3) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(6));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(3) == 1 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(6));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // bagua.c 八卦阵
      # 
      # #include <ansi.h>
      # 
      # inherit F_SSERVER;
      #  
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         string msg;
      #         int count;
      #         int i;
      #  
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail("「八卦阵芒」只能对战斗中的对手使用。\n");
      #  
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "blade")
      #                 return notify_fail("你的兵器不对。\n");
      # 
      #         if ((int)me->query("max_neili") < 2000)
      #                 return notify_fail("你的内力修为不够。\n");
      # 
      #         if ((int)me->query("neili") < 400)
      #                 return notify_fail("你的真气不够！\n");
      # 
      #         if ((int)me->query_skill("force") < 220)
      #                 return notify_fail("你的内功火候不够！\n");
      # 
      #         if ((int)me->query_skill("zijinbagua-dao", 1) < 200)
      #                 return notify_fail("你的紫金八卦刀还不到家，无法使用「八卦阵芒」！\n");
      # 
      #         if (me->query_skill_mapped("blade") != "zijinbagua-dao")
      #                 return notify_fail("你没有激发紫金八卦刀，无法使用「八卦阵芒」！\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = MAG "$N" MAG "一声暴喝，手中的" + weapon->name() +
      #               MAG "刀芒陡长，顿时只见万股凌厉的刀芒按照八卦阵的"
      #               "方位直涌$n" MAG "！\n\n" NOR;
      # 
      #         if (random(me->query_skill("blade")) > target->query_skill("parry") / 2)
      #         {
      #                 msg += HIR "$n" HIR "见来招实在是变幻莫测，不由得心"
      #                        "生惧意，招式登时出了破绽！\n" NOR;
      #                 count = me->query_skill("zijinbagua-dao", 1) / 6;
      #         } else
      #         {
      #                 msg += HIY "$n" HIY "心底微微一惊，打起精神小心接招。\n" NOR;
      #                 count = 0;
      #         }
      # 
      #         message_combatd(msg, me, target);
      #         me->add("neili", -300);
      #         me->add_temp("apply/attack", count);
      # 
      #         for (i = 0; i < 5 + random(3) ; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      #                 if (random(3) == 1 && ! target->is_busy())
      #                         target->start_busy(1);
      #                 COMBAT_D->do_attack(me, target, weapon, 0);
      #         }
      # 
      #         me->add_temp("apply/attack", -count);
      #         me->start_busy(1 + random(6));
      #         return 1;
      # }
end
