defmodule Kantele.Combat.Skills.Performs.ShenlongBashi.Xian do
  @moduledoc """
  perform「xian」（source shenlong-bashi/xian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"damage", "force"}], "level_gates": [{"force", "80"}, {"shenlong-bashi", "100"}], "map_gates": [{"hand", "shenlong-bashi"}], "prepared_gates": [], "resource_gates": [{"neili", "150"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["神龙初现只能对战斗中的对手使用。\n", "你的神龙八式手法还不够娴熟，不能使用神龙初现。\n", "你的内功火候不够，不能使用神龙初现。\n", "你现在真气不够，不能使用神龙初现。\n", "你没有激发神龙八式手法，不能使用神龙初现。\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIG", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIG "$N" HIG "脚下轻浮，踉踉跄跄，似倒非倒，跌跌撞撞的冲向$n"
      #                 HIG "，同时伸手就是一招，诡秘之极。\n" NOR", "= CYN "可是$p" CYN "看破了$P" CYN "的企图，巧妙的挡住了$P"
      #                          CYN "的进攻。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 35,
      #                                              HIR "$p" HIR "左遮右挡，却没能挡住$P" HIR "这看似无赖"
      #                                      "的招数，结果被$P" HIR "重重的击中，哇的吐了一口鲜血。\n" NOR)"]}, "damage_formula": %{"formula": "(int)me->query_skill("force")"}, "resource_adds": [{"neili", "-125"}, {"neili", "-30"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-125"}, {"neili", "-30"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "target->start_busy(1);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - target->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // xian.c 神龙初现
      # 
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      # //      object weapon;
      #         int damage;
      #         string msg;
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail("神龙初现只能对战斗中的对手使用。\n");
      # 
      #         if ((int)me->query_skill("shenlong-bashi", 1) < 100)
      #                 return notify_fail("你的神龙八式手法还不够娴熟，不能使用神龙初现。\n");
      # 
      #         if ((int)me->query_skill("force") < 80)
      #                 return notify_fail("你的内功火候不够，不能使用神龙初现。\n");
      # 
      #         if ((int)me->query("neili") < 150)
      #                 return notify_fail("你现在真气不够，不能使用神龙初现。\n");
      # 
      #         if (me->query_skill_mapped("hand") != "shenlong-bashi")
      #                 return notify_fail("你没有激发神龙八式手法，不能使用神龙初现。\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIG "$N" HIG "脚下轻浮，踉踉跄跄，似倒非倒，跌跌撞撞的冲向$n"
      #               HIG "，同时伸手就是一招，诡秘之极。\n" NOR;
      # 
      #         me->start_busy(2);
      #         if (random(me->query_skill("hand")) > target->query_skill("parry") / 2)
      #         {
      #                 damage = (int)me->query_skill("force");
      #                 damage = damage / 2 + random(damage / 2);
      # 
      #                 target->start_busy(1);
      #                 me->add("neili", -125);
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 35,
      #                                            HIR "$p" HIR "左遮右挡，却没能挡住$P" HIR "这看似无赖"
      #                                    "的招数，结果被$P" HIR "重重的击中，哇的吐了一口鲜血。\n" NOR);
      #         } else
      #         {
      #                 msg += CYN "可是$p" CYN "看破了$P" CYN "的企图，巧妙的挡住了$P"
      #                        CYN "的进攻。\n" NOR;
      #                 me->add("neili", -30);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
