defmodule Kantele.Combat.Skills.Performs.LingsheZhangfa.Qianshe do
  @moduledoc """
  perform「qianshe」（source lingshe-zhangfa/qianshe.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"lvl", "lingshe-zhangfa"}], "level_gates": [{"force", "150"}, {"lingshe-zhangfa", "120"}], "map_gates": [{"staff", "lingshe-zhangfa"}], "prepared_gates": [], "resource_gates": [{"neili", "100"}], "var_gates": [{"i", "5"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你还不会使用「千蛇出洞」。\n", "「千蛇出洞」只能对战斗中的对手使用。\n", "你必须手持一把杖才能施展「千蛇出洞」！\n", "你的内功火候不够，难以施展「千蛇出洞」！\n", "你的真气不够，无法施展「千蛇出洞」！\n", "你的灵蛇杖法还不到家，无法使用千蛇出洞！\n", "你没有激发灵蛇杖法，无法使用千蛇出洞！\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "大喝一声，扑身上前，手中的" + weapon->name() +
      #                 HIW "化作万道光芒，一齐射向$n" HIW "！\n" NOR", "= HIY "$n" HIY "见$N" HIY "把" + weapon->name() +
      #                          HIY "使得活灵活现，犹如真物一般，实在是难以抵挡，只有后退。\n" NOR"], "success": []}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "staff"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (random(2) && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(5));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(2) && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(5));
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
      #         object weapon;
      #         string msg;
      #         int count;
      #         int lvl;
      #         int i;
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (userp(me) && ! me->query("can_perform/lingshe-zhangfa/qianshe"))
      #                 return notify_fail("你还不会使用「千蛇出洞」。\n");
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail("「千蛇出洞」只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "staff")
      #                 return notify_fail("你必须手持一把杖才能施展「千蛇出洞」！\n");
      # 
      #         if ((int)me->query_skill("force") < 150)
      #                 return notify_fail("你的内功火候不够，难以施展「千蛇出洞」！\n");
      # 
      #         if ((int)me->query("neili") < 100)
      #                 return notify_fail("你的真气不够，无法施展「千蛇出洞」！\n");
      # 
      #         if ((lvl = (int)me->query_skill("lingshe-zhangfa", 1)) < 120)
      #                 return notify_fail("你的灵蛇杖法还不到家，无法使用千蛇出洞！\n");
      # 
      #         if (me->query_skill_mapped("staff") != "lingshe-zhangfa")
      #                 return notify_fail("你没有激发灵蛇杖法，无法使用千蛇出洞！\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIW "$N" HIW "大喝一声，扑身上前，手中的" + weapon->name() +
      #               HIW "化作万道光芒，一齐射向$n" HIW "！\n" NOR;
      # 
      #         if (lvl / 2 + random(lvl) > target->query_skill("parry") * 2 / 3)
      #         {
      #                 msg += HIY "$n" HIY "见$N" HIY "把" + weapon->name() +
      #                        HIY "使得活灵活现，犹如真物一般，实在是难以抵挡，只有后退。\n" NOR;
      #                 count = lvl / 6;
      #                 me->add_temp("apply/attack", count);
      #         } else
      #                 count = 0;
      # 
      #         message_combatd(msg, me, target);
      #         me->add("neili", -100);
      # 
      #         for (i = 0; i < 5; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      #                 if (random(2) && ! target->is_busy())
      #                         target->start_busy(1);
      #                 COMBAT_D->do_attack(me, target, weapon, 0);
      #         }
      # 
      #         me->add_temp("apply/attack", -count);
      #         me->start_busy(1 + random(5));
      #         return 1;
      # }
end
