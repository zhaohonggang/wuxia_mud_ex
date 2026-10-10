defmodule Kantele.Combat.Skills.Performs.Force.Tianmo do
  @moduledoc """
  exert「天魔解体大法」（source force/tianmo.c，由 translate_perform.py 骨架生成，inherit F_CLEAN_UP）

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
      #   %{"assign_refs": [{"skill", "force"}], "level_gates": [{"force", "300"}, {"martial-cognize", "300"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"con", "30"}, {"neili", "8000"}, {"str", "30"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你已经在运功中了。\n", "你的资质不适合使用", "你的内力不够!", "你还没有入魔，无法使用", "你的修行还不够,无法使用"], "color_codes": ["NOR", "RED"], "combat_messages": %{"fail": [], "other": [], "success": []}, "receive_damage_calls": [%{"formula": "skill + shen_lvl + random(1000)", "kind": "damage", "part": "qi", "source": None}, %{"formula": "skill + shen_lvl + random(1000)", "kind": "wound", "part": "qi", "source": None}, %{"formula": "skill + shen_lvl + random(1000)", "kind": "damage", "part": "jing", "source": None}, %{"formula": "skill + shen_lvl + random(1000)", "kind": "wound", "part": "jing", "source": None}], "resource_queries": ["neili"], "resource_sets": [{"neili", "0"}], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": ["attack", "con", "damage", "dex", "dodge", "force", "int", "parry", "str", "unarmed_damage"], "busy_lines": ["if (me->is_fighting()) me->start_busy(3);"], "remote_damage": false, "set_flags": [{"neili", "0"}], "temp_set": ["tianmo"]}
      #   - if (me->is_fighting()) me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // 天魔解体大法
      # //此buff下，不能yun heal，不能吃先天丹，无法中先天故事
      # 
      # #include <ansi.h>
      # #define TIANMO "「" RED "天魔解体大法" NOR "」"
      # 
      # inherit F_CLEAN_UP;
      # 
      # int exert(object me, object target)
      # {
      #     int shen, shen_lvl;
      #     int skill, count;
      #     int i;
      #     string *skills;
      # 
      #     shen = me->query("shen");
      #     shen_lvl = to_int(pow(to_float(-shen), 1.0 / 3));
      #     skill = me->query_skill("force", 1);
      #     count = (shen_lvl + skill) / 4;
      #     skills = keys(me->query_skill_map());
      # 
      #     if (me->query_temp("tianmo"))
      #         return notify_fail("你已经在运功中了。\n");
      # 
      #     if (me->query("str") < 30 && me->query("con") < 30)
      #         return notify_fail("你的资质不适合使用" TIANMO "。\n");
      # 
      #     if ((int)me->query("neili") < 8000)
      #         return notify_fail("你的内力不够!");
      # 
      #     if (me->query("shen") > -10000000)
      #         return notify_fail("你还没有入魔，无法使用" TIANMO "。\n");
      # 
      #     if ((int)me->query_skill("martial-cognize", 1) < 300 ||
      #         (int)me->query_skill("force", 1) < 300)
      #         return notify_fail("你的修行还不够,无法使用" TIANMO "。\n");
      # 
      #     me->set("neili", 0);
      #     me->receive_damage("qi", skill + shen_lvl + random(1000));
      #     me->receive_wound("qi", skill + shen_lvl + random(1000));
      #     me->receive_damage("jing", skill + shen_lvl + random(1000));
      #     me->receive_wound("jing", skill + shen_lvl + random(1000));
      # 
      #     message_combatd(RED "$N蓦地大叫一声，喷出一口鲜血，"
      #                         "正是天下闻名的 " TIANMO "。\n" NOR, me);
      # 
      #     me->add_temp("apply/str", me->query("str"));
      #     me->add_temp("apply/int", me->query("int"));
      #     me->add_temp("apply/con", me->query("con"));
      #     me->add_temp("apply/dex", me->query("dex"));
      #     //me->add_temp("apply/dodge", me->query("dex"));
      #     //me->add_temp("apply/parry", me->query("dex"));
      #     //me->add_temp("apply/force", me->query("con"));
      #     me->add_temp("apply/attack", count);
      #     me->add_temp("apply/damage", me->query("str") * 3);
      #     me->add_temp("apply/unarmed_damage", me->query("str") * 3);
      # 
      #     for (i = 0; i < sizeof(skills); i++)
      #     {
      #         me->add_temp("apply/" + skills[i], count / 2);
      #     }
      # 
      #     me->set_temp("tianmo", 1);
      # 
      #     if (me->is_fighting()) me->start_busy(3);
      # 
      #     return 1;
      # }
end
