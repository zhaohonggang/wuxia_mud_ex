defmodule Kantele.Combat.Skills.Performs.WuchangZhang.Wuchang do
  @moduledoc """
  perform「wuchang」（source wuchang-zhang/wuchang.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"force", "200"}, {"wuchang-zhang", "150"}], "map_gates": [{"staff", "wuchang-zhang"}], "prepared_gates": [], "resource_gates": [{"neili", "100"}], "var_gates": [{"i", "5"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「无常五化」只能对战斗中的对手使用。\n", "施展「无常五化」时必须拿着一把杖！\n", "你的真气不够，无法施展「无常五化」！\n", "你的内功火候不够，难以施展「无常五化」！\n", "你的无常杖法还不到家，无法使用「无常五化」！\n", "你没有激发无常杖法，不能使用「无常五化」！\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "将手中的" + weapon->name() +
      #                HIY "一荡，化作无数杖影扫向$n" HIY "！\n" NOR"], "success": []}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "staff"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (random(3) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(5));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(3) == 1 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(5));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // wuchang.c 无常五化
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
      #         return notify_fail("「无常五化」只能对战斗中的对手使用。\n");
      # 
      #     if (! objectp(weapon = me->query_temp("weapon")) ||
      #         (string)weapon->query("skill_type") != "staff")
      #         return notify_fail("施展「无常五化」时必须拿着一把杖！\n");
      # 
      #     if ((int)me->query("neili") < 100)
      #         return notify_fail("你的真气不够，无法施展「无常五化」！\n");
      # 
      #     if ((int)me->query_skill("force") < 200)
      #         return notify_fail("你的内功火候不够，难以施展「无常五化」！\n");
      # 
      #     if ((int)me->query_skill("wuchang-zhang", 1) < 150)
      #         return notify_fail("你的无常杖法还不到家，无法使用「无常五化」！\n");
      # 
      #         if (me->query_skill_mapped("staff") != "wuchang-zhang")
      #                 return notify_fail("你没有激发无常杖法，不能使用「无常五化」！\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIY "$N" HIY "将手中的" + weapon->name() +
      #              HIY "一荡，化作无数杖影扫向$n" HIY "！\n" NOR;
      #     message_combatd(msg, me, target);
      # 
      #     me->add("neili", -100);
      # 
      #         for (i = 0; i < 5; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      #                 if (random(3) == 1 && ! target->is_busy())
      #                         target->start_busy(1);
      #             COMBAT_D->do_attack(me, target, weapon, 0);
      #         }
      # 
      #     me->start_busy(1 + random(5));
      #     return 1;
      # }
end
