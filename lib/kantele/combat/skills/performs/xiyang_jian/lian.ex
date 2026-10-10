defmodule Kantele.Combat.Skills.Performs.XiyangJian.Lian do
  @moduledoc """
  perform「lian」（source xiyang-jian/lian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"force", "100"}, {"xiyang-jian", "80"}], "map_gates": [{"sword", "xiyang-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "100"}], "var_gates": [{"i", "5"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「连环剑」只能对战斗中的对手使用。\n", "必须拿剑才能施展「连环剑」！\n", "你的真气不够，无法施展「连环剑」！\n", "你的内功火候不够，难以施展「连环剑」！\n", "你的西洋剑术还不到家，无法使用连环剑！\n", "你没有激发西洋剑术，无法使用连环剑！\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIC", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "\n$N" HIC "狂喝一声，只见上一剑、下一剑、左一剑、右一剑、当中一剑，一起刺向$n"
      #                 HIC "！\n" NOR"], "success": []}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (random(3) == 0 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(5));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(3) == 0 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(5));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // lian.c 西洋连环剑
      # 
      # #include <ansi.h>
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     object weapon;
      #         string msg;
      #         int i;
      # 
      #         if (! target)
      #         {
      #             me->clean_up_enemy();
      #             target = me->select_opponent();
      #         }
      # 
      #     if (! target || ! me->is_fighting(target))
      #         return notify_fail("「连环剑」只能对战斗中的对手使用。\n");
      # 
      #     if (! objectp(weapon = me->query_temp("weapon")) ||
      #         (string)weapon->query("skill_type") != "sword")
      #         return notify_fail("必须拿剑才能施展「连环剑」！\n");
      # 
      #     if ((int)me->query("neili") < 100)
      #         return notify_fail("你的真气不够，无法施展「连环剑」！\n");
      # 
      #     if ((int)me->query_skill("force") < 100)
      #         return notify_fail("你的内功火候不够，难以施展「连环剑」！\n");
      # 
      #     if ((int)me->query_skill("xiyang-jian", 1) < 80)
      #         return notify_fail("你的西洋剑术还不到家，无法使用连环剑！\n");
      # 
      #         if (me->query_skill_mapped("sword") != "xiyang-jian")
      #                 return notify_fail("你没有激发西洋剑术，无法使用连环剑！\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIC "\n$N" HIC "狂喝一声，只见上一剑、下一剑、左一剑、右一剑、当中一剑，一起刺向$n"
      #               HIC "！\n" NOR;
      #     message_combatd(msg, me, target);
      #     me->add("neili", -100);
      # 
      #         for (i = 0; i < 5; i++)
      #         {
      #                 if (random(3) == 0 && ! target->is_busy())
      #                         target->start_busy(1);
      # 
      #             COMBAT_D->do_attack(me, target, weapon, 0);
      #         }
      # 
      #     me->start_busy(1 + random(5));
      #     return 1;
      # }
end
