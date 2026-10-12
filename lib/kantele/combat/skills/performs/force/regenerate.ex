defmodule Kantele.Combat.Skills.Performs.Force.Regenerate do
  @moduledoc """
  exert「regenerate」（source force/regenerate.c，由 translate_perform.py 生成，inherit ?）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat

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
    with :ok <- check_weapon(character),
         :ok <- check_other(character) do
      :ok
    end
  end

  defp check_weapon(character) do
    # TODO(migrate) 武器检查需人工核对（自动提取的文案仅供参考）：
    :ok

  end

  defp check_other(character) do
    # TODO(migrate) 其它门槛（战斗/临时状态/道具等）需人工核对：
    #   {:error, "你只能用内功恢复自己的精力。\n"}
    #   {:error, "你现在精气旺盛。\n"}
    :ok

  end

  defp apply_effect(conn, character) do
    # 无条件攻击方效果：消耗/Busy/Apply/暗器数量 + 前置广播
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"assign_refs": [{"lvl", "force"}], "busy_lines": ["if (me->is_fighting()) me->start_busy(1);"], "remote_damage": false, "var_gates": [{"heal", "10"}, {"neili_cost", "20"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // regenerate.c
  # 
  # //inherit SSERVER;
  # 
  # int exert(object me, object target)
  # {
  #         int neili_cost;
  #         int lvl;
  #         int heal;
  # 
  #     if (target != me)
  #         return notify_fail("你只能用内功恢复自己的精力。\n");
  # 
  #     heal = (int)me->query("eff_jing") - (int)me->query("jing");
  #     if (heal < 10)
  #         return notify_fail("你现在精气旺盛。\n");
  # 
  #         lvl = me->query_skill("force");
  #         if (lvl <= 0) lvl = 1;
  #         neili_cost = heal * 60 / lvl;
  #         if (me->query("breakup"))
  #                 neili_cost = neili_cost * 7 / 10;
  #         if (neili_cost < 20) neili_cost = 20;
  #         if (neili_cost > me->query("neili"))
  #         {
  #                 neili_cost = me->query("neili");
  #                 heal = neili_cost * lvl / 60;
  #         }
  #         if (neili_cost < 20) neili_cost = 20;
  # 
  #     if ((int)me->query("neili") < neili_cost)
  #         return notify_fail("你的内力不够。\n");
  # 
  #     me->add("neili", -neili_cost);
  #     me->receive_heal("jing", heal);
  # 
  #         message_vision("$N深深吸了几口气，精神看起来好多了。\n", me);
  # 
  #         if (me->is_fighting()) me->start_busy(1);
  # 
  #     return 1;
  # }
end
