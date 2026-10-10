defmodule Kantele.Combat.Skills.Performs.LongchengShendao.Fengyu do
  @moduledoc """
  perform「fengyu」（source longcheng-shendao/fengyu.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"lvl", "longcheng-shendao"}], "level_gates": [{"force", "150"}, {"longcheng-shendao", "120"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "270"}], "var_gates": [{"i", "5"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你不会使用「风雨交加」。\n", "「风雨交加」只能对战斗中的对手使用。\n", "施展「风雨交加」手中必须拿着一把刀！\n", "你的真气不够，无法施展「风雨交加」！\n", "你的内功火候不够，无法施展「风雨交加」！\n", "你的龙城神刀还不到家，无法使用绝技「风雨交加」！\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIC", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "大喝一声，手中的" + weapon->name() + HIC
      #                 "如雨点一般向$n" HIC "打去，$n" HIC "如同小舟一般在刀雨中漂泊不定。\n" NOR", "= HIY "这阵刀势变化莫测，$n" HIY "顿时觉得眼花缭乱，无法抵挡。\n" NOR", "= HIC "$n" HIC "不禁心中凛然，不敢有半点小觑，使出浑身解数抵挡。\n" NOR"], "success": []}, "resource_adds": [{"neili", "-120"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-120"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["me->start_busy(1 + random(5));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(5));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // fengyu.c 风雨交加
      # 
      # #include <ansi.h>
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     object weapon;
      #         string msg;
      #         int count;
      #         int lvl;
      #         int i;
      # 
      #         if (userp(me) && ! me->query("can_perform/longcheng-shendao/fengyu"))
      #                 return notify_fail("你不会使用「风雨交加」。\n");
      # 
      #         if (! target)
      #         {
      #             me->clean_up_enemy();
      #             target = me->select_opponent();
      #         }
      # 
      #     if (! target || ! me->is_fighting(target))
      #         return notify_fail("「风雨交加」只能对战斗中的对手使用。\n");
      # 
      #     if (!objectp(weapon = me->query_temp("weapon")) ||
      #         (string)weapon->query("skill_type") != "blade")
      #         return notify_fail("施展「风雨交加」手中必须拿着一把刀！\n");
      # 
      #     if ((int)me->query("neili") < 270)
      #         return notify_fail("你的真气不够，无法施展「风雨交加」！\n");
      # 
      #     if ((int)me->query_skill("force") < 150)
      #         return notify_fail("你的内功火候不够，无法施展「风雨交加」！\n");
      # 
      #     if ((lvl = (int)me->query_skill("longcheng-shendao", 1)) < 120)
      #         return notify_fail("你的龙城神刀还不到家，无法使用绝技「风雨交加」！\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIC "$N" HIC "大喝一声，手中的" + weapon->name() + HIC
      #               "如雨点一般向$n" HIC "打去，$n" HIC "如同小舟一般在刀雨中漂泊不定。\n" NOR;
      # 
      #         if (lvl / 2 + random(lvl) > target->query_skill("parry") * 2 / 3)
      #         {
      #                 msg += HIY "这阵刀势变化莫测，$n" HIY "顿时觉得眼花缭乱，无法抵挡。\n" NOR;
      #                 count = lvl / 5;
      #                 me->add_temp("apply/attack", count);
      #         } else
      #         {
      #                 msg += HIC "$n" HIC "不禁心中凛然，不敢有半点小觑，使出浑身解数抵挡。\n" NOR;
      #                 count = 0;
      #         }
      # 
      #     message_combatd(msg, me, target);
      #     me->add("neili", -120);
      # 
      #         for (i = 0; i < 5; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      #             COMBAT_D->do_attack(me, target, weapon, 0);
      #         }
      # 
      #     me->start_busy(1 + random(5));
      #         me->add_temp("apply/attack", -count);
      # 
      #     return 1;
      # }
end
