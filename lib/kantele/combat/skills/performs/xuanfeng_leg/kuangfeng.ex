defmodule Kantele.Combat.Skills.Performs.XuanfengLeg.Kuangfeng do
  @moduledoc """
  perform「kuangfeng」（source xuanfeng-leg/kuangfeng.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"force", "150"}, {"luoying-shenzhang", "100"}, {"xuanfeng-leg", "100"}], "map_gates": [], "prepared_gates": [{"unarmed", "xuanfeng-leg"}], "resource_gates": [{"neili", "150"}], "var_gates": [{"i", "6"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「狂风绝技」只能在战斗中对对手使用。\n", "「狂风绝技」开始时不能拿着兵器！\n", "你的真气不够！\n", "你的内功水平不够！\n", "你的腿掌功夫还不到家，无法使用狂风绝技！\n", "你没有准备旋风腿法，无法施展狂风绝技。\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "使出桃花岛绝技「狂风绝技」，身法飘忽"
      #                 "不定，有若天仙！\n" NOR"], "success": []}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (random(3) == 0 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(6));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(3) == 0 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(6));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // kuangfeng.c  狂风绝技
      # 
      # #include <ansi.h>
      # #include <skill.h>
      # #include <weapon.h>
      # #include <combat.h>
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     // object weapon;
      #   string msg;
      #     int i;
      # 
      #     if (! target)
      #     {
      #         me->clean_up_enemy();
      #             target = me->select_opponent();
      #     }
      # 
      #     if (! target || !me->is_fighting(target))
      #         return notify_fail("「狂风绝技」只能在战斗中对对手使用。\n");
      # 
      #     if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #         return notify_fail("「狂风绝技」开始时不能拿着兵器！\n");
      # 
      #     if ((int)me->query("neili") < 150)
      #         return notify_fail("你的真气不够！\n");
      # 
      #     if ((int)me->query_skill("force") < 150)
      #         return notify_fail("你的内功水平不够！\n");
      # 
      #     if ((int)me->query_skill("luoying-shenzhang", 1) < 100 ||
      #         me->query_skill("xuanfeng-leg",1) < 100)
      #         return notify_fail("你的腿掌功夫还不到家，无法使用狂风绝技！\n");
      # 
      #     if (me->query_skill_prepared("unarmed") != "xuanfeng-leg")
      #         return notify_fail("你没有准备旋风腿法，无法施展狂风绝技。\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIY "$N" HIY "使出桃花岛绝技「狂风绝技」，身法飘忽"
      #               "不定，有若天仙！\n" NOR;
      #     message_combatd(msg, me);
      #     me->add("neili", -100);
      # 
      #     for (i = 0; i < 6; i++)
      #     {
      #         if (! me->is_fighting(target))
      #             break;
      #                 if (random(3) == 0 && ! target->is_busy())
      #                         target->start_busy(1);
      #         COMBAT_D->do_attack(me, target, 0, 0);
      #     }
      # 
      #     me->start_busy(1 + random(6));
      #     return 1;
      # }
end
