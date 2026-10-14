defmodule Kantele.Combat.Skills.Performs.Longxiang.Shield do
  @moduledoc """
  exert「shield / 龙象护体」（source longxiang/shield.c，inherit F_CLEAN_UP）

  自身护体：门槛（按 .c 顺序）：仅自身 → 内力>=100 → 龙象般若功>=60 →
  未在运功中。扣内力 100 后广播，按 force 等级给 armor 临时加成 `force/2`，
  置 `shield` 标记；战斗中忙乱 2。定时移除（remove_effect）未做 call_out 自动回收，
  仅保留其文案。

  差异（TODO(migrate)）：
  - `target != me` 在框架 exert 中恒为自身，`check_target/1` 恒为 :ok，仅保留文案；
  - `.c` 的 `me->query_temp("shield")` 以 `combat.temp[:shield]` 代理；
  - `me->receive_damage("qi", 0)` 为零值空操作，略去。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_target(character),
         :ok <- check_resources(character),
         :ok <- check_level(character),
         :ok <- check_state(character) do
      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (target != me) return notify_fail("你只能用龙象般若功来提升自己的防御力。\n");
  defp check_target(_character) do
    # 框架 exert 的 target 即自身
    _msg = "你只能用龙象般若功来提升自己的防御力。\n"
    :ok
  end

  # LPC: if ((int)me->query("neili") < 100) return notify_fail("你的内力不够。\n");
  defp check_resources(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你的内力不够。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("longxiang", 1) < 60)
  #         return notify_fail("你的龙象般若功修为不够。\n");
  defp check_level(character) do
    if Stats.skill(character.meta.stats, "longxiang") < 60 do
      {:error, "你的龙象般若功修为不够。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_temp("shield")) return notify_fail("你已经在运功中了。\n");
  defp check_state(character) do
    if Map.get(character.meta.combat.temp || %{}, :shield) do
      {:error, "你已经在运功中了。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character) do
    # LPC: remove_effect: tell_object(me, "你的龙象般若功运行完毕，将内力收回丹田。\n");
    _remove = "你的龙象般若功运行完毕，将内力收回丹田。\n"
    skill = Stats.skill(character.meta.stats, "force")

    # LPC: me->add("neili", -100); me->receive_damage("qi", 0);
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 100}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: message_combatd(HIW "$N" HIW "大喝一声，眼中神光四射，"
    #                         "只见一股白雾蒸腾而起，笼罩了$N" HIW "的全身！\n" NOR, me);
    conn =
      Broadcast.publish(
        conn,
        "$N大喝一声，眼中神光四射，只见一股白雾蒸腾而起，笼罩了$N的全身！\n",
        n1: character.name
      )

    # LPC: me->add_temp("apply/armor", skill / 2); me->set_temp("shield", 1);
    combat = character.meta.combat
    combat = Combat.apply_temp(combat, %{armor: div(skill, 2)})
    combat = %{combat | temp: Map.put(combat.temp || %{}, :shield, 1)}

    # LPC: if (me->is_fighting()) me->start_busy(2);
    combat = if Combat.fighting?(combat), do: Combat.start_busy(combat, 2), else: combat
    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

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
  #         return notify_fail("你只能用龙象般若功来提升自己的防御力。\n");
  # 
  #     if ((int)me->query("neili") < 100)
  #         return notify_fail("你的内力不够。\n");
  # 
  #     if ((int)me->query_skill("longxiang", 1) < 60)
  #         return notify_fail("你的龙象般若功修为不够。\n");
  # 
  #     if ((int)me->query_temp("shield"))
  #         return notify_fail("你已经在运功中了。\n");
  # 
  #     skill = me->query_skill("force");
  #     me->add("neili", -100);
  #     me->receive_damage("qi", 0);
  # 
  #     message_combatd(HIW "$N" HIW "大喝一声，眼中神光四射，"
  #                         "只见一股白雾蒸腾而起，笼罩了$N"
  #                         HIW "的全身！\n" NOR, me);
  # 
  #     me->add_temp("apply/armor", skill / 2);
  #     me->set_temp("shield", 1);
  # 
  #     me->start_call_out((: call_other, __FILE__,
  #                            "remove_effect", me, skill / 2:), skill);
  # 
  #     if (me->is_fighting()) me->start_busy(2);
  # 
  #     return 1;
  # }
  # 
  # void remove_effect(object me, int amount)
  # {
  #     me->add_temp("apply/armor", -amount);
  #     me->delete_temp("shield");
  #     tell_object(me, "你的龙象般若功运行完毕，将内力收回丹田。\n");
  # }
end
