defmodule Kantele.Combat.Skills.Performs.HujiaDaofa.Cang do
  @moduledoc """
  perform「八方藏刀势」（source hujia-daofa/cang.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"count", "hujia-daofa"}], "level_gates": [{"force", "250"}, {"hujia-daofa", "180"}], "map_gates": [{"blade", "hujia-daofa"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": [{"i", "8"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的内功火候不够，难以施展", "你的胡家刀法还不到家，难以施展", "你没有激发胡家刀法，难以施展", "你的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIC", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "轻舒猿臂，施出「战八方藏刀式」，手中的" + weapon->name() +
      #                 HIW "吞吞吐吐，变化莫测，笼罩了$n" HIW "周身要害！\n" NOR", "= HIY "$n" HIY "见来招实在是变幻莫测，不由得心"
      #                          "生惧意，招式登时出了破绽！\n" NOR", "= HIC "$n" HIC "心底微微一惊，打起精神小心接招。\n" NOR"], "success": []}, "resource_adds": [{"neili", "-220"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-220"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (random(3) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(8));"], "remote_damage": false, "set_flags": [], "temp_set": []}
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
      # 
      # #define CANG "「" HIW "八方藏刀势" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     object weapon;
      #         string msg;
      #         int count;
      #         int i;
      # 
      #         if (userp(me) && ! me->query("can_perform/hujia-daofa/cang"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target)
      #         {
      #             me->clean_up_enemy();
      #             target = me->select_opponent();
      #         }
      # 
      #     if (! target || ! me->is_fighting(target))
      #         return notify_fail(CANG "只能对战斗中的对手使用。\n");
      # 
      #     if (! objectp(weapon = me->query_temp("weapon")) ||
      #         (string)weapon->query("skill_type") != "blade")
      #                 return notify_fail("你使用的武器不对，难以施展" CANG "。\n");
      # 
      #     if ((int)me->query_skill("force") < 250)
      #         return notify_fail("你的内功火候不够，难以施展" CANG "。\n");
      # 
      #     if ((int)me->query_skill("hujia-daofa", 1) < 180)
      #         return notify_fail("你的胡家刀法还不到家，难以施展" CANG "。\n");
      # 
      #         if (me->query_skill_mapped("blade") != "hujia-daofa")
      #                 return notify_fail("你没有激发胡家刀法，难以施展" CANG "。\n");
      # 
      #     if ((int)me->query("neili") < 200)
      #         return notify_fail("你的真气不够，难以施展" CANG "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIW "$N" HIW "轻舒猿臂，施出「战八方藏刀式」，手中的" + weapon->name() +
      #               HIW "吞吞吐吐，变化莫测，笼罩了$n" HIW "周身要害！\n" NOR;
      # 
      #         if (random(me->query_skill("blade")) > target->query_skill("parry") / 2)
      #         {
      #                 msg += HIY "$n" HIY "见来招实在是变幻莫测，不由得心"
      #                        "生惧意，招式登时出了破绽！\n" NOR;
      #                 count = me->query_skill("hujia-daofa", 1) / 4;
      #         } else
      #         {
      #                 msg += HIC "$n" HIC "心底微微一惊，打起精神小心接招。\n" NOR;
      #                 count = 0;
      #         }
      # 
      #     message_combatd(msg, me, target);
      #     me->add("neili", -220);
      #         me->add_temp("apply/attack", count);
      # 
      #         for (i = 0; i < 8; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      #                 if (random(3) == 1 && ! target->is_busy())
      #                         target->start_busy(1);
      #             COMBAT_D->do_attack(me, target, weapon, 0);
      #         }
      # 
      #         me->add_temp("apply/attack", -count);
      #     me->start_busy(1 + random(8));
      #     return 1;
      # }
end
