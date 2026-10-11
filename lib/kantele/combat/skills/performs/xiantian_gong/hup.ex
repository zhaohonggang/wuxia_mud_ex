defmodule Kantele.Combat.Skills.Performs.XiantianGong.Hup do
  @moduledoc """
  exert「五气朝元」（source xiantian-gong/hup.c，由 translate_perform.py 生成，inherit F_CLEAN_UP）

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
      Stats.skill(stats, "xiantian-gong") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
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
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 3)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"assign_refs": [{"skill", "force"}], "busy_lines": ["me->start_busy(3);"], "level_gates": [{"xiantian-gong", "200"}], "remote_damage": false, "resource_gates": [{"max_neili", "1000"}, {"neili", "200"}]}

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
