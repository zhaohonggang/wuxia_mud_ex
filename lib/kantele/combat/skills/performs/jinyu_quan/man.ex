defmodule Kantele.Combat.Skills.Performs.JinyuQuan.Man do
  @moduledoc """
  perform「金玉满堂」（source jinyu-quan/man.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"damage", "cuff"}], "level_gates": [{"jinyu-quan", "80"}], "map_gates": [{"cuff", "jinyu-quan"}], "prepared_gates": [{"cuff", "jinyu-quan"}], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的金玉拳法不够娴熟，难以施展", "你没有激发金玉拳法，难以施展", "你没有准备金玉拳法，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "双拳纷飞，气势如虹，顿时幻出一片拳影，似乎$n"
      #                 HIY"的全身都被拳影所笼罩。\n" NOR", "= CYN "可是$p" CYN "识破了$P"
      #                          CYN "这一招，斜斜一跃避开。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 45,
      #                                              HIR "结果只听“砰砰砰砰”几声闷响，$p"
      #                                              HIR "前胸被$P" HIR "轰中数拳，登时呕出"
      #                                              "一口鲜血！\n" NOR)"]}, "damage_formula": %{"formula": "me->query_skill("cuff")"}, "resource_adds": [{"neili", "-150"}, {"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}, {"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define MAN "「" HIY "金玉满堂" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      # //      object weapon;
      #         int damage;
      #         string msg;
      # 
      #         if (userp(me) && ! me->query("can_perform/jinyu-quan/man"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(MAN "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(MAN "只能空手施展。\n");
      # 
      #         if ((int)me->query_skill("jinyu-quan", 1) < 80)
      #                 return notify_fail("你的金玉拳法不够娴熟，难以施展" MAN "。\n");
      # 
      #         if (me->query_skill_mapped("cuff") != "jinyu-quan")
      #                 return notify_fail("你没有激发金玉拳法，难以施展" MAN "。\n");
      # 
      #         if (me->query_skill_prepared("cuff") != "jinyu-quan")
      #                 return notify_fail("你没有准备金玉拳法，难以施展" MAN "。\n");
      # 
      #         if (me->query("neili") < 200)
      #                 return notify_fail("你现在的真气不够，难以施展" MAN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIY "$N" HIY "双拳纷飞，气势如虹，顿时幻出一片拳影，似乎$n"
      #               HIY"的全身都被拳影所笼罩。\n" NOR;
      # 
      #         if (random(me->query_skill("cuff")) > target->query_skill("dodge") / 2)
      #         {
      #                 me->start_busy(2);
      #                 damage = me->query_skill("cuff");
      #                 damage = damage / 2 + random(damage / 2);
      #                 me->add("neili", -150);
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 45,
      #                                            HIR "结果只听“砰砰砰砰”几声闷响，$p"
      #                                            HIR "前胸被$P" HIR "轰中数拳，登时呕出"
      #                                            "一口鲜血！\n" NOR);
      #         } else
      #         {
      #                 me->start_busy(3);
      #                 me->add("neili", -50);
      #                 msg += CYN "可是$p" CYN "识破了$P"
      #                        CYN "这一招，斜斜一跃避开。\n" NOR;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
