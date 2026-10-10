defmodule Kantele.Combat.Skills.Performs.JiuyangShengong.Roar do
  @moduledoc """
  exert「roar」（source jiuyang-shengong/roar.c，由 translate_perform.py 骨架生成，inherit F_CLEAN_UP）

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
      #   %{"assign_refs": [{"skill", "force"}], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "100"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你的内力不够。\n", "这里不能攻击别人! \n"], "color_codes": ["HIY", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "damage_formula": %{"formula": "skill - ((int)ob[i]->query("max_neili") / 10)"}, "receive_damage_calls": [%{"formula": "damage * 3", "kind": "damage", "part": "qi", "source": "me"}, %{"formula": "damage * 2", "kind": "wound", "part": "jing", "source": "me"}, %{"formula": "10", "kind": "damage", "part": "qi", "source": None}], "resource_adds": [{"neili", "-100"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": false, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(5);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(5);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // roar.c 天地长吟
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
      #     if ((int)me->query("neili") < 100)
      #         return notify_fail("你的内力不够。\n");
      # 
      #     skill = me->query_skill("force");
      # 
      #     me->add("neili", -100);
      #     me->receive_damage("qi", 10);
      # 
      #     if (environment(me)->query("no_fight"))
      #         return notify_fail("这里不能攻击别人! \n");
      # 
      #     me->start_busy(5);
      #     message_combatd(HIY "$N" HIY "猛然深吸一口气，仰天长吟，声音洪亮无比，气势恢弘，以地"
      #                         "动山摇之势向周围扩散开去。\n" NOR, me);
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
      #                 me->want_kill(ob[i]);
      #                 me->fight_ob(ob[i]);
      #                 ob[i]->kill_ob(me);
      # 
      #         damage = skill - ((int)ob[i]->query("max_neili") / 10);
      #         if (damage > 0)
      #                 {
      #                         ob[i]->set("last_damage_from", me);
      #             ob[i]->receive_damage("qi", damage * 3, me);
      #             if ((int)ob[i]->query("neili") < skill * 2)
      #                 ob[i]->receive_wound("jing", damage * 2, me);
      #                 tell_object(ob[i], "你只觉得胸口一阵苦闷，顿时倒退几步，一股鲜血从口中喷出。\n");
      #         }
      #     }
      #     return 1;
      # }
end
