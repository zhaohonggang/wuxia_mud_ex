defmodule Kantele.Combat.Skills.Performs.XuedaoDafa.Resurrect do
  @moduledoc """
  exert「浴血重生」（source xuedao-dafa/resurrect.c，由 translate_perform.py 生成，inherit F_CLEAN_UP）

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
      Stats.skill(stats, "xuedao-dafa") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 1000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | max_neili: vitals.max_neili - 1}
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
  #   %{"add_costs": [{"max_neili", "-1"}], "assign_refs": [{"skill", "xuedao-dafa"}], "busy_lines": ["me->start_busy(3);"], "level_gates": [{"xuedao-dafa", "120"}], "remote_damage": false, "resource_gates": [{"max_neili", "1000"}, {"neili", "200"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // resurrect.c 浴血重生
  # 
  # #include <ansi.h>
  # 
  # #define R "「" HIR "浴血重生" NOR "」"
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
  #         if (userp(me) && ! me->query("can_perform/xuedao-dafa/resurrect"))
  #                 return notify_fail("你所学的内功中没有这种功能。\n");
  # 
  #         if ((int)me->query_skill("xuedao-dafa", 1) < 120)
  #                 return notify_fail("你的血刀大法不够深厚，难以施展" R "。\n");
  # 
  #         if ((int)me->query("max_neili") < 1000) 
  #                 return notify_fail("你的内力修为不足，难以施展" R "。\n");
  # 
  #         if ((int)me->query("neili") < 200) 
  #                 return notify_fail("你现在的真气不够，难以施展" R "。\n");
  # 
  #         my = me->query_entire_dbase();
  #         if ((rp = (my["max_qi"] - my["eff_qi"])) < 1)
  #                 return (SKILL_D("force") + "/recover")->exert(me, target);
  # 
  #         if (rp >= my["max_qi"] / 10)
  #                 rp = my["max_qi"] / 10;
  # 
  #         skill = me->query_skill("xuedao-dafa", 1);
  #         msg = HIR "$N" HIR "深深吸入一口气，脸色由红转白，复又由白翻"
  #               "红，伤势恢复了不少。\n" NOR;
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
  #         if (random(10) < 3)
  #         {
  #                 tell_object(me, HIC "由于你过度的催动真元，导致你的内"
  #                                 "力有所损耗。\n" NOR);
  #                 me->add("max_neili", -1);
  #         }
  #         me->start_busy(3);
  #         return 1;
  # }
end
