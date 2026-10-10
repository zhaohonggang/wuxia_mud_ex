defmodule Kantele.Combat.Skills.Performs.LiuyunZhang.Die do
  @moduledoc """
  perform「流云叠影」（source liuyun-zhang/die.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "liuyun-zhang"}, {"dp", "dodge"}], "level_gates": [{"dodge", "150"}, {"liuyun-zhang", "100"}], "map_gates": [{"strike", "liuyun-zhang"}], "prepared_gates": [{"strike", "liuyun-zhang"}], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你流云掌不够娴熟，难以施展", "你没有激发流云掌，难以施展", "你没有准备流云掌，难以施展", "你的轻功修为不够，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("liuyun-zhang", 1) +
      #                me->query_skill("dodge", 1) / 2", "dp_formula": "target->query_skill("dodge")"}, "color_codes": ["CYN", "HIC", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": ["CYN "$n" CYN "看破$N" CYN "毫无攻击之意，于"
      #                         "是大胆反攻，将$N" CYN "这招尽数化解。\n" NOR"], "other": ["HIC "\n$N" HIC "身法陡然变快，双掌不断拍出，招式如影"
      #                 "如幻，虚实难测，试图扰乱$n" HIC "的攻势。" NOR", "HIY "$n" HIY "只见$N" HIY "双掌飘忽不定，毫"
      #                         "无破绽，竟被困在$N" HIY "的掌风之中。\n" NOR"], "success": []}, "resource_adds": [{"neili", "-30"}, {"neili", "-80"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-30"}, {"neili", "-80"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy(ap / 45 + 1);", "me->start_busy(1);", "me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy(ap / 45 + 1);
      #   - me->start_busy(1);
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define DIE "「" HIW "流云叠影" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         string msg;
      #         int ap, dp;
      # 
      #         if (userp(me) && ! me->query("can_perform/liuyun-zhang/die"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(DIE "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(DIE "只能空手施展。\n");
      # 
      #         if (target->is_busy())
      #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
      # 
      #         if ((int)me->query_skill("liuyun-zhang", 1) < 100)
      #                 return notify_fail("你流云掌不够娴熟，难以施展" DIE "。\n");
      # 
      #         if (me->query_skill_mapped("strike") != "liuyun-zhang")
      #                 return notify_fail("你没有激发流云掌，难以施展" DIE "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "liuyun-zhang")
      #                 return notify_fail("你没有准备流云掌，难以施展" DIE "。\n");
      # 
      #         if (me->query_skill("dodge") < 150)
      #                 return notify_fail("你的轻功修为不够，难以施展" DIE "。\n");
      # 
      #         if ((int)me->query("neili") < 200)
      #                 return notify_fail("你现在的真气不够，难以施展" DIE "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         ap = me->query_skill("liuyun-zhang", 1) +
      #              me->query_skill("dodge", 1) / 2;
      # 
      #         dp = target->query_skill("dodge");
      # 
      #         msg = HIC "\n$N" HIC "身法陡然变快，双掌不断拍出，招式如影"
      #               "如幻，虚实难测，试图扰乱$n" HIC "的攻势。" NOR;
      # 
      #         message_sort(msg, me, target);
      # 
      #         if (random(ap) > dp / 2)
      #         {
      #         msg = HIY "$n" HIY "只见$N" HIY "双掌飘忽不定，毫"
      #                       "无破绽，竟被困在$N" HIY "的掌风之中。\n" NOR;
      # 
      #                 target->start_busy(ap / 45 + 1);
      #                    me->start_busy(1);
      #                 me->add("neili", -80);
      #         } else
      #         {
      #                 msg = CYN "$n" CYN "看破$N" CYN "毫无攻击之意，于"
      #                       "是大胆反攻，将$N" CYN "这招尽数化解。\n" NOR;
      # 
      #                 me->start_busy(2);
      #                 me->add("neili", -30);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
