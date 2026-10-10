defmodule Kantele.Combat.Skills.Performs.MurongJian.Xing do
  @moduledoc """
  perform「剑转七星」（source murong-jian/xing.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"dodge", "120"}, {"murong-jian", "80"}], "map_gates": [{"sword", "murong-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": [{"i", "7"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你的慕容剑法不够娴熟，难以施展", "你没有激发慕容剑法，难以施展", "你的轻功修为不够，无法施展", "你目前的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIM", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIM "$N" HIM "使出慕容家绝技「" HIW "剑转七星" HIM "」，手中"
      #                 + weapon->name() + HIM "暗合北斗七星方位，忽伸忽缩，变化莫测！\n" NOR"], "success": []}, "resource_adds": [{"neili", "-210"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-210"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (! target->is_busy() && random(2) == 1)", "target->start_busy(1);", "me->start_busy(3 + random(5));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (! target->is_busy() && random(2) == 1)
      #   - target->start_busy(1);
      #   - me->start_busy(3 + random(5));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define ZHUAN "「" HIW "剑转七星" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     object weapon;
      #     string msg;
      #     int i;
      # 
      #         if (userp(me) && ! me->query("can_perform/murong-jian/xing"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #     if (! target) target = offensive_target(me);
      # 
      #     if (! target || ! me->is_fighting(target))
      #                 return notify_fail(ZHUAN "只能对战斗中的对手使用。\n");
      # 
      #     if (! objectp(weapon = me->query_temp("weapon"))
      #            || (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你所使用的武器不对，难以施展" ZHUAN "。\n");
      # 
      #     if ((int)me->query_skill("murong-jian", 1) < 80)
      #         return notify_fail("你的慕容剑法不够娴熟，难以施展" ZHUAN "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "murong-jian")
      #                 return notify_fail("你没有激发慕容剑法，难以施展" ZHUAN "。\n");
      # 
      #     if ((int)me->query_skill("dodge") < 120)
      #         return notify_fail("你的轻功修为不够，无法施展" ZHUAN "！\n");
      # 
      #     if (me->query("neili") < 200)
      #         return notify_fail("你目前的真气不够，难以施展" ZHUAN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIM "$N" HIM "使出慕容家绝技「" HIW "剑转七星" HIM "」，手中"
      #               + weapon->name() + HIM "暗合北斗七星方位，忽伸忽缩，变化莫测！\n" NOR;
      # 
      #     me->add("neili", -210);
      # 
      #         message_vision(msg, me, target);
      # 
      #         for (i = 0; i < 7; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      # 
      #                 if (! target->is_busy() && random(2) == 1)
      #                         target->start_busy(1);
      # 
      #                 COMBAT_D->do_attack(me, target, weapon, 13);
      #         }
      # 
      #     me->start_busy(3 + random(5));
      # 
      #         return 1;
      # }
end
