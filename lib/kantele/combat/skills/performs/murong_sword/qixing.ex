defmodule Kantele.Combat.Skills.Performs.MurongSword.Qixing do
  @moduledoc """
  perform「qixing」（source murong-sword/qixing.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"force", "150"}, {"sword", "150"}], "map_gates": [{"sword", "murong-sword"}], "prepared_gates": [], "resource_gates": [{"neili", "220"}], "var_gates": [{"i", "7"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「北斗七星剑」只能对战斗中的对手使用。\n", "施展「北斗七星剑」手中必须拿着一把剑！\n", "你的真气不够，无法施展「北斗七星剑」！\n", "你的内功火候不够，无法施展「北斗七星剑」！\n", "你的慕容剑法还不到家，无法使用绝技「北斗七星剑」！\n", "你没有激发慕容剑法，无法使用「北斗七星剑」！\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIM", "NOR"], "combat_messages": %{"fail": [], "other": ["HIM "$N" HIM "使出慕容家绝技「北斗七星剑」，手中" + weapon->name() +
      #                 HIM "暗合北斗七星方位，忽伸忽缩，变化莫测！\n" NOR"], "success": []}, "resource_adds": [{"neili", "-140"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-140"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1 + random(7));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(7));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // beidou.c  北斗七星剑
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
      #         return notify_fail("「北斗七星剑」只能对战斗中的对手使用。\n");
      # 
      #     if (! objectp(weapon = me->query_temp("weapon")) ||
      #         (string)weapon->query("skill_type") != "sword")
      #         return notify_fail("施展「北斗七星剑」手中必须拿着一把剑！\n");
      # 
      #     if ((int)me->query("neili") < 220)
      #         return notify_fail("你的真气不够，无法施展「北斗七星剑」！\n");
      # 
      #     if ((int)me->query_skill("force") < 150)
      #         return notify_fail("你的内功火候不够，无法施展「北斗七星剑」！\n");
      # 
      #     if ((int)me->query_skill("sword") < 150)
      #         return notify_fail("你的慕容剑法还不到家，无法使用绝技「北斗七星剑」！\n");
      # 
      #         if (me->query_skill_mapped("sword") != "murong-sword")
      #                 return notify_fail("你没有激发慕容剑法，无法使用「北斗七星剑」！\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIM "$N" HIM "使出慕容家绝技「北斗七星剑」，手中" + weapon->name() +
      #               HIM "暗合北斗七星方位，忽伸忽缩，变化莫测！\n" NOR;
      # 
      #     message_combatd(msg, me);
      #     me->add("neili", -140);
      # 
      #         for (i = 0; i < 7; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      #             COMBAT_D->do_attack(me, target, weapon, 0);
      #         }
      # 
      #     me->start_busy(1 + random(7));
      # 
      #     return 1;
      # }
end
