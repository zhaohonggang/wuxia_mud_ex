defmodule Kantele.Combat.Skills.Performs.BlueseaForce.Powerup do
  @moduledoc """
  exert「powerup」（source bluesea-force/exert/powerup.c，inherit F_CLEAN_UP）

  门槛（按 .c 顺序）：目标为自身 → 真气>=100 → 未在运功。
  扣 100 真气；attack=defense=基本内功*2/5；持续 基本内功 秒；
  战斗中 busy 3；到期回收。

  差异（TODO(migrate)）：
  - `apply/attack`、`apply/defense` 临时加成与 `set_temp("powerup")` 由
    引擎 buff 机制承担，本文件为并存的对齐副本。
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

  defp check_gates(character) do
    with :ok <- check_target(character),
         :ok <- check_resources(character),
         :ok <- check_other(character) do
      :ok
    end
  end

  # LPC: if (target != me) return notify_fail("你只能用南海玄功提升自己的战斗力。\n");
  # exert 恒以自身为目标，故此门槛恒为 :ok，但保留文案以对齐 .c。
  defp check_target(_character) do
    _ = "你只能用南海玄功提升自己的战斗力。\n"
    :ok
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 100 -> {:error, "你的内力不够!\n"}
      true -> :ok
    end
  end

  defp check_other(character) do
    # LPC: if ((int)me->query_temp("powerup")) return notify_fail("你已经在运功中了。\n");
    if Combat.buff_active?(character.meta.combat, "powerup") do
      {:error, "你已经在运功中了。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character) do
    # LPC: me->add("neili", -100); me->receive_damage("qi", 0);
    #      message_combatd(HIC "$N" HIC "大喝一声，一股气浪登时如波"
    #                      "涛一般散布开来，直吹得四周飞沙走石！\n" NOR, me);
    #      apply/attack += skill * 2 / 5; apply/defense += skill * 2 / 5;
    #      skill = me->query_skill("force")
    #      if (me->is_fighting()) me->start_busy(3);
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    combat = character.meta.combat

    combat =
      if Combat.fighting?(combat), do: Combat.start_busy(combat, 3), else: combat

    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> Broadcast.publish("$N大喝一声，一股气浪登时如波涛一般散布开来，直吹得四周飞沙走石！\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # LPC remove_effect：tell_object(me, "你的南海玄功运行完毕，将内力收回丹田。\n");
  @doc false
  def expire_message, do: "你的南海玄功运行完毕，将内力收回丹田。\n"

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}], "apply_adds": ["attack", "defense"], "assign_refs": [{"skill", "force"}], "busy_lines": ["if (me->is_fighting()) me->start_busy(3);"], "remote_damage": false, "resource_gates": [{"neili", "100"}], "temp_set": ["powerup"]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // powerup.c
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
  #         return notify_fail("你只能用南海玄功提升自己的战斗力。\n");
  #
  #     if ((int)me->query("neili") < 100)
  #         return notify_fail("你的内力不够!");
  #
  #     if ((int)me->query_temp("powerup"))
  #         return notify_fail("你已经在运功中了。\n");
  #
  #     skill = me->query_skill("force");
  #
  #     me->add("neili", -100);
  #     me->receive_damage("qi", 0);
  #
  #     message_combatd(HIC "$N" HIC "大喝一声，一股气浪登时如波"
  #                         "涛一般散布开来，直吹得四周飞沙走石！\n" NOR, me);
  #
  #     me->add_temp("apply/attack", skill * 2 / 5);
  #     me->add_temp("apply/defense", skill * 2 / 5);
  #     me->set_temp("powerup", 1);
  #
  #     me->start_call_out((: call_other, __FILE__, "remove_effect",
  #                            me, skill * 2 / 5 :), skill);
  #
  #     if (me->is_fighting()) me->start_busy(3);
  #
  #     return 1;
  # }
  #
  # void remove_effect(object me, int amount)
  # {
  #         if ((int)me->query_temp("powerup"))
  #         {
  #             me->add_temp("apply/attack", -amount);
  #             me->add_temp("apply/defense", -amount);
  #             me->delete_temp("powerup");
  #                 tell_object(me, "你的南海玄功运行完毕，将内力收回丹田。\n");
  #         }
  # }
end
