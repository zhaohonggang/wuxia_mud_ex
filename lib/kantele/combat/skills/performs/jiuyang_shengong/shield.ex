defmodule Kantele.Combat.Skills.Performs.JiuyangShengong.Shield do
  @moduledoc """
  exert「shield / 九阳护体」（source jiuyang-shengong/exert/shield.c，inherit F_CLEAN_UP）

  自身护体：消耗 100 内力，按 force 等级给 armor 临时加成；运功期间战斗中忙乱 2。
  定时移除（remove_effect）未做 call_out 自动回收，仅保留文案。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Messages

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_target(character),
         :ok <- check_resources(character),
         :ok <- check_levels(character),
         :ok <- check_state(character) do
      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (target != me) return notify_fail("你只能用九阳神功来提升自己的防御力。\n");
  defp check_target(_character) do
    _msg = "你只能用九阳神功来提升自己的防御力。\n"
    :ok
  end

  defp check_resources(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你的真气不够。\n"}
    else
      :ok
    end
  end

  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "jiuyang-shengong") < 40 do
      {:error, "你的九阳神功等级不够。\n"}
    else
      :ok
    end
  end

  defp check_state(character) do
    if Map.get(character.meta.combat.temp || %{}, :shield) do
      {:error, "你已经在运功中了。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character) do
    _remove = "你的九阳神功运行完毕，将内力收回丹田。\n"
    skill = Stats.skill(character.meta.stats, "force")

    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 100}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    combat = character.meta.combat
    combat = Combat.apply_temp(combat, %{armor: div(skill, 2)})
    combat = %{combat | temp: Map.put(combat.temp || %{}, :shield, 1)}
    combat = if Combat.fighting?(combat), do: Combat.start_busy(combat, 2), else: combat
    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> Broadcast.publish(
      Messages.interpolate(
        "$N默念九阳神功的口诀：他强由他强，清风拂山冈。他横任他横，明月照大江……\n刹那间只见$N全身顿时浮现出一层刚猛的劲气，将$P全全笼罩。\n",
        [n1: character.name]
      )
    )
    |> put_character(character)
    |> assign(:prompt, false)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // shield.c 九阳护体神功
  # 
  # #include <ansi.h>
  # 
  # inherit F_CLEAN_UP;
  # 
  # void remove_effect(object me, int amount);
  # 
  # int exert(object me, object target)
  # {
  #         int skill;
  # 
  #         if (target != me)
  #                 return notify_fail("你只能用九阳神功来提升自己的防御力。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你的真气不够。\n");
  # 
  #         if ((int)me->query_skill("jiuyang-shengong", 1) < 40)
  #                 return notify_fail("你的九阳神功等级不够。\n");
  # 
  #         if ((int)me->query_temp("shield"))
  #                 return notify_fail("你已经在运功中了。\n");
  # 
  #         skill = me->query_skill("force");
  #         me->add("neili", -100);
  #         me->receive_damage("qi", 0);
  # 
  #         message_combatd(HIR "$N" HIR "默念九阳神功的口诀：他"
  #                             "强由他强，清风拂山冈。他横任他横，"
  #                             "明月照大江……\n刹那间只见$N" 
  #                         HIR "全身顿时浮现出一层刚猛的劲气，将$P"
  #                         HIR "全全笼罩。\n" NOR, me);
  # 
  #         me->add_temp("apply/armor", skill / 2);
  #         me->set_temp("shield", 1);
  # 
  #         me->start_call_out((: call_other, __FILE__, "remove_effect", me, skill / 2 :), skill);
  # 
  #         if (me->is_fighting()) me->start_busy(2);
  # 
  #         return 1;
  # }
  # 
  # void remove_effect(object me, int amount)
  # {
  #         if (me->query_temp("shield"))
  #         {
  #                 me->add_temp("apply/armor", -amount);
  #                 me->delete_temp("shield");
  #                 tell_object(me, "你的九阳神功运行完毕，将内力收回丹田。\n");
  #         }
  # }
end
