defmodule Kantele.Combat.Skills.Performs.Force.Recover do
  @moduledoc """
  exert「recover」（source force/recover.c）

  自我调息：`target != me` 恒不成立（本引擎 exert 恒以自身为目标）→ 保留文案；
  真气>=20；`eff_qi - qi >= 10`，否则「气力充沛」。
  扣真气 `n = 100*q/force`（`breakup` 与 `special_skill/self` 各 ×7/10，下限 20；
  真气不足时按 `neili/n` 比例缩减回气量）；回气 `q`（上限 `eff_qi`）；
  战斗中且无 `special_skill/self` 忙乱 1。

  差异（TODO(migrate)）：
  - 真实运行为 `Kantele.Combat.Skills.Force.Recover`（`skills/force_recover.ex`）
    的 `Performs.Simple` spec，本文件为并存的对齐副本（仅供文案对齐）；
  - LPC `eff_qi` 对应本引擎 `vitals.max_qi`（`Vitals.wound/3` 削减 `max_*`，
    `base_*` 对应 LPC 的 `max_qi`）；
  - spec 版把 busy 简化为「战斗中一律忙乱 1」，此处按 `.c` 保留 `self` 判定。
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
         :ok <- check_neili(character),
         :ok <- check_needs_heal(character) do
      :ok
    end
  end

  # LPC: if (me != target) return notify_fail("你只能用内功调匀自己的气息。\n");
  # exert 恒以自身为目标，故此门槛恒为 :ok，但保留文案以对齐 .c。
  defp check_target(_character) do
    _ = "你只能用内功调匀自己的气息。\n"
    :ok
  end

  # LPC: if ((int)me->query("neili") < 20)
  defp check_neili(character) do
    if character.meta.vitals.neili < 20 do
      {:error, "你的内力不够。\n"}
    else
      :ok
    end
  end

  # LPC: q = (int)me->query("eff_qi") - (int)me->query("qi");
  #      if (q < 10) return notify_fail("你现在气力充沛。\n");
  defp check_needs_heal(character) do
    vitals = character.meta.vitals

    if vitals.max_qi - vitals.qi < 10 do
      {:error, "你现在气力充沛。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character) do
    vitals = character.meta.vitals
    stats = character.meta.stats

    # LPC: q = eff_qi - qi; n = 100 * q / me->query_skill("force");
    #      if (me->query("breakup")) n = n * 7 / 10;
    #      if (n < 20) n = 20;
    #      if (me->query("special_skill/self")) n = n * 7 / 10;
    q = vitals.max_qi - vitals.qi
    force_lvl = max(Stats.skill(stats, "force"), 1)
    n = div(100 * q, force_lvl)
    n = if SpecialSkills.owned?(character.attributes, "breakup"), do: div(n * 7, 10), else: n
    n = max(n, 20)
    n = if SpecialSkills.owned?(character.attributes, "self"), do: div(n * 7, 10), else: n

    # LPC: if ((int)me->query("neili") < n) { q = q * neili / n; n = neili; }
    {q, n} =
      if vitals.neili < n do
        {div(q * vitals.neili, n), vitals.neili}
      else
        {q, n}
      end

    # LPC: me->add("neili", -n); me->receive_heal("qi", q);
    vitals =
      vitals
      |> Map.update!(:neili, &max(&1 - n, 0))
      |> Vitals.heal(:qi, q)

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: message_vision("$N深深吸了几口气，脸色看起来好多了。\n", me);
    conn =
      Broadcast.publish(conn, "$N深深吸了几口气，脸色看起来好多了。\n", n1: character.name)

    # LPC: if (me->is_fighting() && ! me->query("special_skill/self")) me->start_busy(1);
    combat = character.meta.combat

    combat =
      if Combat.fighting?(combat) and not SpecialSkills.owned?(character.attributes, "self") do
        Combat.start_busy(combat, 1)
      else
        combat
      end

    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end
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
