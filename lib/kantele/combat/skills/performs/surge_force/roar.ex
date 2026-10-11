defmodule Kantele.Combat.Skills.Performs.SurgeForce.Roar do
  @moduledoc """
  exert「roar」（source surge-force/roar.c，由 translate_perform.py 生成，inherit F_CLEAN_UP）

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
      Stats.skill(stats, "surge-force") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 100 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 5)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}], "assign_refs": [{"skill", "force"}], "busy_lines": ["me->start_busy(5);"], "level_gates": [{"surge-force", "100"}], "remote_damage": false, "resource_gates": [{"neili", "100"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // roar.c 黯然吟
  # 
  # #include <ansi.h>
  # 
  # inherit F_CLEAN_UP;
  # 
  # int exert(object me, object target)
  # {
  #     object *ob;
  #     int i, skill, damage;
  # 
  #         if (me->query_skill("surge-force", 1) < 100)
  #                 return notify_fail("你黯然一声长叹，结果吓跑了几只老鼠！\n");
  # 
  #     if ((int)me->query("neili") < 100)
  #         return notify_fail("你的内力不够。\n");
  # 
  #     if (environment(me)->query("no_fight"))
  #         return notify_fail("这里不能攻击别人! \n");
  # 
  #     skill = me->query_skill("force");
  # 
  #     me->add("neili", -100);
  #     me->receive_damage("qi", 10);
  # 
  #     me->start_busy(5);
  #     message_combatd(HIR "$N" HIR "仰天长啸，声浪一波一波的荡开"
  #                         "去，令人发耳欲聩，意乱情迷！\n" NOR, me);
  # 
  #     ob = all_inventory(environment(me));
  #     for (i = 0; i < sizeof(ob); i++)
  #         {
  #         if (! ob[i]->is_character() || ob[i] == me)
  #             continue;
  # 
  #         if (skill / 2 + random(skill / 2) < (int)ob[i]->query("con") * 2)
  #             continue;
  # 
  #                 if ((int)ob[i]->query_condition("die_guard"))
  #                         continue;
  # 
  #                 me->want_kill(ob[i]);
  #                 me->fight_ob(ob[i]);
  #                 ob[i]->kill_ob(me);
  # 
  #         damage = skill - ((int)ob[i]->query("max_neili") / 10);
  #         if (damage > 0)
  #                 {
  #             ob[i]->receive_damage("jing", damage * 2, me);
  #             if ((int)ob[i]->query("neili") < skill * 2)
  #                 ob[i]->receive_wound("jing", damage, me);
  #                 tell_object(ob[i], "你听了脑子轰的一下......\n");
  #         }
  #     }
  #     return 1;
  # }
end
