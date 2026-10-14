defmodule Kantele.Combat.Skills.Performs.BlueseaForce.Shield do
  @moduledoc """
  exert「shield」护体神功（source bluesea-force/exert/shield.c，inherit F_CLEAN_UP）

  门槛（按 .c 顺序）：目标为自身 → 真气>=100 → 南海玄功>=50 → 未在运功。
  扣 100 真气；armor=基本内功/2；持续 基本内功 秒；
  战斗中 busy 2；到期回收。

  差异（TODO(migrate)）：
  - `apply/armor` 临时加成与 `set_temp("shield")` 由引擎 buff 机制承担，
    本文件为并存的对齐副本。
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

  defp check_gates(character) do
    with :ok <- check_target(character),
         :ok <- check_resources(character),
         :ok <- check_levels(character),
         :ok <- check_other(character) do
      :ok
    end
  end

  # LPC: if (target != me) return notify_fail("你只能用南海玄功来提升自己的防御力。\n");
  # exert 恒以自身为目标，故此门槛恒为 :ok，但保留文案以对齐 .c。
  defp check_target(_character) do
    _ = "你只能用南海玄功来提升自己的防御力。\n"
    :ok
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 100 -> {:error, "你的内力不够。\n"}
      true -> :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "bluesea-force") < 50 -> {:error, "你的南海玄功修为不够。\n"}
      true -> :ok
    end
  end

  defp check_other(character) do
    # LPC: if ((int)me->query_temp("shield")) return notify_fail("你已经在运功中了。\n");
    if Combat.buff_active?(character.meta.combat, "shield") do
      {:error, "你已经在运功中了。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character) do
    # LPC: me->add("neili", -100); me->receive_damage("qi", 0);
    #      message_combatd(HIW "$N" HIW "冷哼一声，默运玄功，运"
    #                      "用罡气护住了全身。\n" NOR, me);
    #      apply/armor += skill / 2; skill = me->query_skill("force")
    #      if (me->is_fighting()) me->start_busy(2);
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    combat = character.meta.combat

    combat =
      if Combat.fighting?(combat), do: Combat.start_busy(combat, 2), else: combat

    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> Broadcast.publish("$N冷哼一声，默运玄功，运用罡气护住了全身。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # LPC remove_effect：tell_object(me, "你的南海玄功运行完毕，将内力收回丹田。\n");
  @doc false
  def expire_message, do: "你的南海玄功运行完毕，将内力收回丹田。\n"

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}], "apply_adds": ["armor"], "assign_refs": [{"skill", "force"}], "busy_lines": ["if (me->is_fighting()) me->start_busy(2);"], "level_gates": [{"bluesea-force", "50"}], "remote_damage": false, "resource_gates": [{"neili", "100"}], "temp_set": ["shield"]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // shield.c 护体神功
  # //
  #
  # #include <ansi.h>
  #
  # inherit F_CLEAN_UP;
  #
  # void remove_effect(object me, int amount);
  #
  # int exert(object me, object target)
  # {
  #     int skill;
  #
  #     if (target != me)
  #         return notify_fail("你只能用南海玄功来提升自己的防御力。\n");
  #
  #     if ((int)me->query("neili") < 100)
  #         return notify_fail("你的内力不够。\n");
  #
  #     if ((int)me->query_skill("bluesea-force", 1) < 50)
  #         return notify_fail("你的南海玄功修为不够。\n");
  #
  #     if ((int)me->query_temp("shield"))
  #         return notify_fail("你已经在运功中了。\n");
  #
  #     skill = me->query_skill("force");
  #     me->add("neili", -100);
  #     me->receive_damage("qi", 0);
  #
  #     message_combatd(HIW "$N" HIW "冷哼一声，默运玄功，运"
  #                         "用罡气护住了全身。\n" NOR, me);
  #
  #     me->add_temp("apply/armor", skill / 2);
  #     me->set_temp("shield", 1);
  #
  #     me->start_call_out((: call_other, __FILE__, "remove_effect", me, skill / 2 :), skill);
  #
  #     if (me->is_fighting()) me->start_busy(2);
  #
  #     return 1;
  # }
  #
  # void remove_effect(object me, int amount)
  # {
  #         if (me->query_temp("shield"))
  #         {
  #             me->add_temp("apply/armor", -amount);
  #             me->delete_temp("shield");
  #             tell_object(me, "你的南海玄功运行完毕，将内力收回丹田。\n");
  #         }
  # }
end
