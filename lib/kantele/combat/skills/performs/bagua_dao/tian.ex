defmodule Kantele.Combat.Skills.Performs.BaguaDao.Tian do
  @moduledoc """
  perform「天刀八势」（source bagua-dao/tian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"count", "bagua-dao"}], "level_gates": [{"bagua-dao", "200"}, {"nei-bagua", "200"}, {"wai-bagua", "200"}], "map_gates": [{"blade", "bagua-dao"}], "prepared_gates": [], "resource_gates": [{"max_neili", "3000"}, {"neili", "500"}], "var_gates": [{"i", "8"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你的八卦刀法不够娴熟，难以施展", "你的外八卦神功不够娴熟，难以施展", "你的内八卦神功不够娴熟，难以施展", "你的内功修为不足，难以施展", "你现在真气不够，难以施展", "你没有激发八卦刀法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "buff_delete": ["pfm_tiandao"], "color_codes": ["HIY", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "resource_adds": [{"neili", "-250"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-250"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (random(3) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(8));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(3) == 1 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(8));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define TIAN "「" HIY "天刀八势" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      # //      int damage;
      # //      string msg;
      #         object weapon;
      #         int i, count;
      # 
      #         if (userp(me) && ! me->query("can_perform/bagua-dao/tian"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(TIAN "只能在战斗中对对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "blade")
      #                 return notify_fail("你所使用的武器不对，难以施展" TIAN "。\n");
      # 
      #         if ((int)me->query_skill("bagua-dao", 1) < 200)
      #                 return notify_fail("你的八卦刀法不够娴熟，难以施展" TIAN "。\n");
      # 
      #         if ((int)me->query_skill("wai-bagua", 1) < 200)
      #                 return notify_fail("你的外八卦神功不够娴熟，难以施展" TIAN "。\n");
      # 
      #         if ((int)me->query_skill("nei-bagua", 1) < 200)
      #                 return notify_fail("你的内八卦神功不够娴熟，难以施展" TIAN "。\n");
      # 
      #         if ((int)me->query("max_neili") < 3000)
      #                 return notify_fail("你的内功修为不足，难以施展" TIAN "。\n");
      # 
      #         if ((int)me->query("neili") < 500)
      #                 return notify_fail("你现在真气不够，难以施展" TIAN "。\n");
      # 
      #         if (me->query_skill_mapped("blade") != "bagua-dao")
      #                 return notify_fail("你没有激发八卦刀法，难以施展" TIAN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         message_combatd(HIY "$N" HIY "蓦地一振手中" + weapon->name() +
      #                         HIY "，发出万千龙吟，霎时刀光滚滚，向四面涌出"
      #                         "，笼罩$n" HIY "全身。\n" NOR, me, target);
      # 
      #         count = me->query_skill("bagua-dao", 1) / 6;
      # 
      #         me->add("neili", -250);
      #         me->add_temp("apply/attack", count);
      # 
      #         for (i = 0; i < 8; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      # 
      #                 if (random(3) == 1 && ! target->is_busy())
      #                         target->start_busy(1);
      # 
      #                 me->add_temp("pfm_tiandao", 1);
      #                 COMBAT_D->do_attack(me, target, weapon, 0);
      #         }
      # 
      #         me->add_temp("apply/attack", -count);
      #         me->delete_temp("pfm_tiandao");
      #         me->start_busy(1 + random(8));
      #         return 1;
      # }
end
