defmodule Kantele.Combat.Skills.Performs.ShiguBifa.Shiyi do
  @moduledoc """
  perform「诗意纵横」（source shigu-bifa/shiyi.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"skill", "shigu-bifa"}], "level_gates": [{"force", "150"}], "map_gates": [{"dagger", "shigu-bifa"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": [{"i", "4"}, {"skill", "120"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你的内功修为不够，难以施展", "你的石鼓打穴笔法修为有限，难以施展", "你现在的真气不足，难以施展", "你没有激发石鼓打穴笔法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "纵步上前，手中" + weapon->name() + HIW "大开大"
      #                 "合，招数连绵不绝，荡气回肠，瞬间向$n" HIW "攻出数招！\n" NOR"], "success": []}, "resource_adds": [{"neili", "-80"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "dagger"}
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
      # #define SHIYI "「" HIW "诗意纵横" NOR "」"
      # 
      # inherit F_SSERVER;
      #  
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         string msg;
      #         int skill, i;
      # 
      #         if (userp(me) && ! me->query("can_perform/shigu-bifa/shiyi"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      #  
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         if (! me->is_fighting(target))
      #                 return notify_fail(SHIYI "只能对战斗中的对手使用。\n");
      # 
      #         weapon = me->query_temp("weapon");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "dagger")
      #                 return notify_fail("你所使用的武器不对，难以施展" SHIYI "。\n");
      # 
      #         skill = me->query_skill("shigu-bifa", 1);
      # 
      #         if (me->query_skill("force") < 150)
      #                 return notify_fail("你的内功修为不够，难以施展" SHIYI "。\n");
      # 
      #         if (skill < 120)
      #                 return notify_fail("你的石鼓打穴笔法修为有限，难以施展" SHIYI "。\n");
      # 
      #         if (me->query("neili") < 200)
      #                 return notify_fail("你现在的真气不足，难以施展" SHIYI "。\n");
      # 
      #         if (me->query_skill_mapped("dagger") != "shigu-bifa")
      #                 return notify_fail("你没有激发石鼓打穴笔法，难以施展" SHIYI "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIW "$N" HIW "纵步上前，手中" + weapon->name() + HIW "大开大"
      #               "合，招数连绵不绝，荡气回肠，瞬间向$n" HIW "攻出数招！\n" NOR;
      #         message_combatd(msg, me, target);
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
