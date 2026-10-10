defmodule Kantele.Combat.Skills.Performs.XiantianGong.Hup do
  @moduledoc """
  exert「五气朝元」（source xiantian-gong/hup.c，由 translate_perform.py 骨架生成，inherit F_CLEAN_UP）

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
      #   %{"assign_refs": [{"skill", "force"}], "level_gates": [{"xiantian-gong", "200"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"max_neili", "1000"}, {"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所学的内功中没有这种功能。\n", "你先天功不够深厚，难以施展", "你的内力修为不足，难以施展", "你现在的真气不够，难以施展"], "color_codes": ["HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "缓缓吐出一口气，顿时气脉通畅，脸色渐渐的变"
      #                 "得平和。\n" NOR"], "success": []}, "resource_adds": [{"neili", "-neili_cost"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": false, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // hup.c 五气朝元
      # 
      # #include <ansi.h>
      # 
      # #define HUP "「" HIR "五气朝元" NOR "」"
      # 
      # inherit F_CLEAN_UP;
      # 
      # int exert(object me, object target)
      # {
      #         int skill;
      #         string msg;
      #         mapping my;
      #         int rp;
      #         int neili_cost;
      # 
      #         if (userp(me) && ! me->query("can_perform/xiantian-gong/hup"))
      #                 return notify_fail("你所学的内功中没有这种功能。\n");
      # 
      #         if ((int)me->query_skill("xiantian-gong", 1) < 200)
      #                 return notify_fail("你先天功不够深厚，难以施展" HUP "。\n");
      # 
      #         if ((int)me->query("max_neili") < 1000) 
      #                 return notify_fail("你的内力修为不足，难以施展" HUP "。\n");
      # 
      #         if ((int)me->query("neili") < 200) 
      #                 return notify_fail("你现在的真气不够，难以施展" HUP "。\n");
      # 
      #         my = me->query_entire_dbase();
      #         if ((rp = (my["max_qi"] - my["eff_qi"])) < 1)
      #                 return (SKILL_D("force") + "/recover")->exert(me, target);
      # 
      #         if (rp >= my["max_qi"] / 10)
      #                 rp = my["max_qi"] / 10;
      # 
      #         skill = me->query_skill("force");
      #         msg = HIW "$N" HIW "缓缓吐出一口气，顿时气脉通畅，脸色渐渐的变"
      #               "得平和。\n" NOR;
      #         message_combatd(msg, me);
      # 
      #         neili_cost = rp + 100;
      #         if (neili_cost > my["neili"])
      #         {
      #                 neili_cost = my["neili"];
      #                 rp = neili_cost - 100;
      #         }
      #         me->receive_curing("qi", rp);
      #         me->receive_healing("qi", rp * 3 / 2);
      #         me->add("neili", -neili_cost);
      # 
      #         me->start_busy(3);
      #         return 1;
      # }
end
