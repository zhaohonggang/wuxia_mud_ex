defmodule Kantele.Combat.Skills.Performs.DuguJiujian.Jue do
  @moduledoc """
  perform「总诀式」（source dugu-jiujian/jue.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"skill", "dugu-jiujian"}], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "85"}], "var_gates": [{"jing_cost", "30"}, {"skill", "60"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你周围过于嘈杂，难以演练", "你使用的武器不对，难以演练", "你的独孤九剑等级不够，难以演练", "你的基本剑法等级有限，难以演练", "你现在真气不足，难以演练", "你现在精神不佳，难以演练", "你实战经验不足，难以演练"], "color_codes": ["HIC", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "使出独孤九剑之「" HIW "总诀式"
      #                 HIC "」，将手中" + weapon->name() + HIC "随"
      #                 "意挥舞击刺。\n" NOR"], "success": []}, "improve_skill": ["improve_skill("], "receive_damage_calls": [%{"formula": "jing_cost", "kind": "damage", "part": "jing", "source": None}], "resource_adds": [{"neili", "-50 - random(30)"}], "resource_queries": ["jing", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(random(3));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # 
      # #define JUE "「" HIC "总诀式" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me)
      # {
      #         string msg;
      #         object weapon;
      #         int skill, jing_cost;
      #         int improve;
      # 
      #         skill = me->query_skill("dugu-jiujian", 1);
      # 
      #         if (skill < 60)
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         jing_cost = 80 - (int)me->query("int");
      #         if (jing_cost < 30) jing_cost = 30;
      # 
      #         if (environment(me)->query("no_fight") && me->query("doing") != "scheme")
      #                 return notify_fail("你周围过于嘈杂，难以演练" JUE "。\n");
      # 
      #         if (me->is_fighting())
      #                 return notify_fail(JUE "不能在战斗中演练。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你使用的武器不对，难以演练" JUE "。\n");
      # 
      #         if (! skill || skill < 60)
      #                 return notify_fail("你的独孤九剑等级不够，难以演练" JUE "。\n");
      # 
      #         if (me->query_skill("sword", 1) < skill)
      #                 return notify_fail("你的基本剑法等级有限，难以演练" JUE "。\n");
      # 
      #         if (me->query("neili") < 85)
      #                 return notify_fail("你现在真气不足，难以演练" JUE "。\n");
      # 
      #         if (me->query("jing") < -jing_cost)
      #                 return notify_fail("你现在精神不佳，难以演练" JUE "。\n");
      # 
      #         if (! me->can_improve_skill("dugu-jiujian"))
      #                 return notify_fail("你实战经验不足，难以演练" JUE "。\n");
      # 
      #         msg = HIC "$N" HIC "使出独孤九剑之「" HIW "总诀式"
      #               HIC "」，将手中" + weapon->name() + HIC "随"
      #               "意挥舞击刺。\n" NOR;
      #         message_combatd(msg, me);
      # 
      #         me->add("neili", -50 - random(30));
      #         me->receive_damage("jing", jing_cost);
      # 
      #         improve = 10 + random(me->query("int")) / 2;
      # 
      #         tell_object(me, HIY "你对「基本剑法」和「独孤九剑」"
      #                         "有了新的领悟。\n" NOR);
      #         me->improve_skill("sword", improve);
      #         me->improve_skill("dugu-jiujian", improve);
      #         me->start_busy(random(3));
      #         return 1;
      # }
end
