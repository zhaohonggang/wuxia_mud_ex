defmodule Kantele.Combat.Skills.Performs.Force.Recover do
  @moduledoc """
  exert「recover」（source force/recover.c，由 translate_perform.py 生成，inherit ?）

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
    with :ok <- check_resources(character),
         :ok <- check_other(character) do
      :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 20 -> {:error, "你现在气力充沛。\n"}
      true -> :ok
    end
  end

  defp check_other(character) do
    # TODO(migrate) 其它门槛检查需人工核对（自动提取的文案仅供参考）
    stats = character.meta.stats

    cond do
      false -> {:error, "你只能用内功调匀自己的气息。\n"}
      true -> :ok
    end
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
  #   %{"assign_refs": [{"n", "force"}], "busy_lines": ["me->start_busy(1);"], "remote_damage": false, "resource_gates": [{"neili", "20"}], "var_gates": [{"n", "20"}, {"q", "10"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // recover.c
  # 
  # int exert(object me, object target)
  # {
  #     int n, q;
  # 
  #     if (me != target)
  #         return notify_fail("你只能用内功调匀自己的气息。\n");
  # 
  #     if ((int)me->query("neili") < 20)
  #         return notify_fail("你的内力不够。\n");
  # 
  #     q = (int)me->query("eff_qi") - (int)me->query("qi");
  #     if (q < 10)
  #         return notify_fail("你现在气力充沛。\n");
  #     n = 100 * q / me->query_skill("force");
  #         if (me->query("breakup"))
  #                 n = n * 7 / 10;
  #     if (n < 20)
  #         n = 20;
  #     if (me->query("special_skill/self"))
  #         n = n * 7 / 10;
  # 
  #     if ((int)me->query("neili") < n)
  #         {
  #         q = q * (int)me->query("neili") / n;
  #         n = (int)me->query("neili");
  #     }
  # 
  #     me->add("neili", -n);
  #     me->receive_heal("qi", q);
  # 
  #         message_vision("$N深深吸了几口气，脸色看起来好多了。\n", me);
  # 
  #         if (me->is_fighting() && ! me->query("special_skill/self"))
  #                 me->start_busy(1);
  # 
  #     return 1;
  # }
end
