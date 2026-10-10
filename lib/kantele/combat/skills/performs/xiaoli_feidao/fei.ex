defmodule Kantele.Combat.Skills.Performs.XiaoliFeidao.Fei do
  @moduledoc """
  perform「fei」（source xiaoli-feidao/fei.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"skill", "xiaoli-feidao"}], "level_gates": [{"xiaoli-feidao", "100"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "100"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["小李飞刀只能在战斗中对对手使用。\n", "你现在手中并没有拿着飞刀。\n", "你的小李飞刀不够娴熟。\n", "你内力不够了。\n"], "color_codes": ["HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": ["HIW "忽然间只见$N" HIW "手中寒光一闪，正是小李飞刀，例无虚发！\n\n"
      #                NOR + HIR "一股鲜血从$n" HIR "咽喉中喷出……\n" NOR"]}, "reset_action": true, "resource_adds": [{"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": true}, "weapon_type": "throwing"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(random(5));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(random(5));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // shan.c
      # 
      # #include <ansi.h>
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int skill;
      #         // int n, i;
      #         // string pmsg;
      #         string msg;
      #         object weapon;
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail("小李飞刀只能在战斗中对对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("handing")) ||
      #             (string)weapon->query("skill_type") != "throwing")
      #                 return notify_fail("你现在手中并没有拿着飞刀。\n");
      # 
      #         if ((skill = me->query_skill("xiaoli-feidao", 1)) < 100)
      #                 return notify_fail("你的小李飞刀不够娴熟。\n");
      # 
      #         if ((int)me->query("neili") < 100)
      #                 return notify_fail("你内力不够了。\n");
      # 
      #         me->add("neili", -50);
      #         weapon->add_amount(-1);
      # 
      #         msg= HIW "忽然间只见$N" HIW "手中寒光一闪，正是小李飞刀，例无虚发！\n\n"
      #              NOR + HIR "一股鲜血从$n" HIR "咽喉中喷出……\n" NOR;
      #         message_combatd(msg, me, target);
      # 
      # 
      #         me->start_busy(random(5));
      #         target->die(me);
      #         me->reset_action();
      #         return 1;
      # }
end
