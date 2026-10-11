defmodule Kantele.Combat.Skills.Performs.Force.Tianmo do
  @moduledoc """
  exert「天魔解体大法」（source force/tianmo.c，由 translate_perform.py 生成，inherit F_CLEAN_UP）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  @impl true
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

  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对
  defp check_gates(character) do
    with :ok <- check_levels(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 300 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "martial-cognize") < 300 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 8000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: 0}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 3)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"apply_adds": ["attack", "con", "damage", "dex", "dodge", "force", "int", "parry", "str", "unarmed_damage"], "assign_refs": [{"skill", "force"}], "busy_lines": ["if (me->is_fighting()) me->start_busy(3);"], "level_gates": [{"force", "300"}, {"martial-cognize", "300"}], "remote_damage": false, "resource_gates": [{"con", "30"}, {"neili", "8000"}, {"str", "30"}], "set_flags": [{"neili", "0"}], "temp_set": ["tianmo"]}

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
