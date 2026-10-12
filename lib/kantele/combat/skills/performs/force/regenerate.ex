defmodule Kantele.Combat.Skills.Performs.Force.Regenerate do
  @moduledoc """
  exert「regenerate」（source force/regenerate.c）

  自我回精：`target != me` 恒不成立（本引擎 exert 恒以自身为目标）→ 保留文案；
  `eff_jing - jing >= 10`，否则「精气旺盛」。
  扣真气 `neili_cost = heal*60/force`（`breakup` ×7/10，下限 20；真气不足时
  取当前真气并按 `neili_cost*force/60` 缩减回精量，再夹到下限 20）；
  回精 `heal`（上限 `eff_jing`）；战斗中忙乱 1。

  差异（TODO(migrate)）：
  - 真实运行为 `Kantele.Combat.Skills.Force.Regenerate`（`skills/force_regenerate.ex`）
    的 `Performs.Simple` spec，本文件为并存的对齐副本（仅供文案对齐）；
  - LPC `eff_jing` 对应本引擎 `vitals.max_jing`；
  - `.c` 的 `if (lvl <= 0) lvl = 1;` 在 E 侧以 `max(..., 1)` 表达。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.SpecialSkills
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast


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

  defp check_gates(character) do
    with :ok <- check_target(character),
         :ok <- check_needs_heal(character),
         :ok <- check_neili(character) do
      :ok
    end
  end

  # LPC: if (target != me) return notify_fail("你只能用内功恢复自己的精力。\n");
  # exert 恒以自身为目标，故此门槛恒为 :ok，但保留文案以对齐 .c。
  defp check_target(_character) do
    _ = "你只能用内功恢复自己的精力。\n"
    :ok
  end

  # LPC: heal = (int)me->query("eff_jing") - (int)me->query("jing");
  #      if (heal < 10) return notify_fail("你现在精气旺盛。\n");
  defp check_needs_heal(character) do
    vitals = character.meta.vitals

    if vitals.max_jing - vitals.jing < 10 do
      {:error, "你现在精气旺盛。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < neili_cost) return notify_fail("你的内力不够。\n");
  defp check_neili(character) do
    {neili_cost, _heal} = plan(character, character.meta.vitals)

    if character.meta.vitals.neili < neili_cost do
      {:error, "你的内力不够。\n"}
    else
      :ok
    end
  end

  # LPC: lvl = me->query_skill("force"); if (lvl <= 0) lvl = 1;
  #      neili_cost = heal * 60 / lvl;
  #      if (me->query("breakup")) neili_cost = neili_cost * 7 / 10;
  #      if (neili_cost < 20) neili_cost = 20;
  #      if (neili_cost > me->query("neili"))
  #      { neili_cost = me->query("neili"); heal = neili_cost * lvl / 60; }
  #      if (neili_cost < 20) neili_cost = 20;
  defp plan(character, vitals) do
    stats = character.meta.stats
    heal = vitals.max_jing - vitals.jing
    lvl = max(Stats.skill(stats, "force"), 1)

    neili_cost = div(heal * 60, lvl)

    neili_cost =
      if SpecialSkills.owned?(character.attributes, "breakup"),
        do: div(neili_cost * 7, 10),
        else: neili_cost

    neili_cost = max(neili_cost, 20)

    {neili_cost, heal} =
      if neili_cost > vitals.neili do
        {vitals.neili, div(vitals.neili * lvl, 60)}
      else
        {neili_cost, heal}
      end

    {max(neili_cost, 20), heal}
  end

  defp apply_effect(conn, character) do
    vitals = character.meta.vitals
    {neili_cost, heal} = plan(character, vitals)

    # LPC: me->add("neili", -neili_cost); me->receive_heal("jing", heal);
    vitals =
      vitals
      |> Map.update!(:neili, &max(&1 - neili_cost, 0))
      |> Vitals.heal(:jing, heal)

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: message_vision("$N深深吸了几口气，精神看起来好多了。\n", me);
    conn =
      Broadcast.publish(conn, "$N深深吸了几口气，精神看起来好多了。\n", n1: character.name)

    # LPC: if (me->is_fighting()) me->start_busy(1);
    combat = character.meta.combat
    combat = if Combat.fighting?(combat), do: Combat.start_busy(combat, 1), else: combat
    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end
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
