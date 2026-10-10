defmodule Kantele.Combat.Skills.Performs.RuyiDao.Ruyi do
  @moduledoc """
  perform「如意六刀」（source ruyi-dao/ruyi.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"force", "150"}, {"ruyi-dao", "100"}], "map_gates": [{"blade", "ruyi-dao"}], "prepared_gates": [], "resource_gates": [{"neili", "250"}], "var_gates": [{"i", "6"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的武器不对，难以施展", "你的真气不够，难以施展", "你的内功火候不够，难以施展", "你的如意刀法还不到家，难以施展", "你没有激发如意刀法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIC", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "使出逍遥绝技「如意六刀」，身法忽然奇快无比，变幻莫测！\n" NOR"], "success": []}, "resource_adds": [{"neili", "-120"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-120"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1 + random(6));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(6));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define RUYI "「" HIC "如意六刀" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     object weapon;
      #         string msg;
      #         int i;
      # 
      #         if (userp(me) && ! me->query("can_perform/ruyi-dao/ruyi"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target)
      #         {
      #             me->clean_up_enemy();
      #             target = me->select_opponent();
      #         }
      # 
      #     if (! target || ! me->is_fighting(target))
      #         return notify_fail(RUYI "只能对战斗中的对手使用。\n");
      # 
      #     if (!objectp(weapon = me->query_temp("weapon")) ||
      #         (string)weapon->query("skill_type") != "blade")
      #                 return notify_fail("你的武器不对，难以施展" RUYI "。\n");
      # 
      #     if ((int)me->query("neili") < 250)
      #         return notify_fail("你的真气不够，难以施展" RUYI "。\n");
      # 
      #     if ((int)me->query_skill("force") < 150)
      #         return notify_fail("你的内功火候不够，难以施展" RUYI "。\n");
      # 
      #     if (me->query_skill("ruyi-dao", 1) < 100)
      #         return notify_fail("你的如意刀法还不到家，难以施展" RUYI "。\n");
      # 
      #         if (me->query_skill_mapped("blade") != "ruyi-dao")
      #                 return notify_fail("你没有激发如意刀法，难以施展" RUYI "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIC "$N" HIC "使出逍遥绝技「如意六刀」，身法忽然奇快无比，变幻莫测！\n" NOR;
      #     message_combatd(msg, me);
      #     me->add("neili", -120);
      # 
      #         for (i = 0; i < 6; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      #             COMBAT_D->do_attack(me, target, weapon, 0);
      #         }
      # 
      #     me->start_busy(1 + random(6));
      # 
      #     return 1;
      # }
end
