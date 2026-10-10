defmodule Kantele.Combat.Skills.Performs.BiyanDao.Luo do
  @moduledoc """
  perform「瀑落九霄」（source biyan-dao/luo.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"biyan-dao", "80"}, {"force", "120"}], "map_gates": [{"blade", "biyan-dao"}], "prepared_gates": [], "resource_gates": [{"neili", "80"}], "var_gates": [{"i", "5"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的武器不对，难以施展", "你碧烟刀法不够娴熟，难以施展", "你没有激发碧烟刀法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIC", "HIW", "NOR", "RED"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "大喝一声，手中" + weapon->name() + HIW
      #                 "一振，便如飞瀑一般向$n" HIW "席卷而去！\n" NOR"], "success": []}, "resource_adds": [{"neili", "-80"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-80"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1 + random(3));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define LUO "「" HIW "瀑落九霄" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         // int damage;
      #         string msg;
      #         object weapon;
      #         int i;
      # 
      #         if (userp(me) && ! me->query("can_perform/biyan-dao/luo"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(LUO "只能在战斗中对对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "blade")
      #                 return notify_fail("你的武器不对，难以施展" LUO "。\n");
      # 
      #         if ((int)me->query_skill("biyan-dao", 1) < 80 )
      #                 return notify_fail("你碧烟刀法不够娴熟，难以施展" LUO "。\n");
      # 
      #         if ((int)me->query_skill("force") < 120 )
      #                 return notify_fail(RED"你内功火候不够，难以施展" LUO "。\n");
      # 
      #         if (me->query_skill_mapped("blade") != "biyan-dao")
      #                 return notify_fail("你没有激发碧烟刀法，难以施展" LUO "。\n");
      # 
      #         if ((int)me->query("neili") < 80)
      #                 return notify_fail(HIC"你现在真气不够，难以施展" LUO "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIW "$N" HIW "大喝一声，手中" + weapon->name() + HIW
      #               "一振，便如飞瀑一般向$n" HIW "席卷而去！\n" NOR;
      #         message_combatd(msg, me, target);
      # 
      #         for (i = 0; i < 5; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      #             COMBAT_D->do_attack(me, target, weapon, 0);
      #         }
      # 
      #         me->add("neili", -80);
      #         me->start_busy(1 + random(3));
      #         return 1;
      # }
end
