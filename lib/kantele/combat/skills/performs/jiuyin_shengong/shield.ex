defmodule Kantele.Combat.Skills.Performs.JiuyinShengong.Shield do
  @moduledoc """
  exert「shield / 九阴神功护体神功」（source jiuyin-shengong/exert/shield.c，inherit F_CLEAN_UP）

  自身护体：消耗 100 内力，按 force 等级给 armor 临时加成（skill/2）；运功期间战斗中忙乱 2。
  门槛：jiuyin-shengong 等级 >= 200。
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

  # LPC: if (target != me) return notify_fail("你只能用九阴神功来提升自己的防御力。\n");
  defp check_target(_character) do
    _msg = "你只能用九阴神功来提升自己的防御力。\n"
    :ok
  end

  defp check_resources(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你的内力不够。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("jiuyin-shengong", 1) < 200)
  #          return notify_fail("你的九阴神功修为不够。\n");
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "jiuyin-shengong") < 200 do
      {:error, "你的九阴神功修为不够。\n"}
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
    _remove = "你的九阴神功运行完毕，将内力收回丹田。\n"
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
        "$N身子一晃，衣袖一波波的不住激荡，劲气逼人！\n",
        [n1: character.name]
      )
    )
    |> put_character(character)
    |> assign(:prompt, false)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // shield.c 九阴神功护体神功
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
  #         return notify_fail("你只能用九阴神功来提升自己的防御力。\n");
  # 
  #     if ((int)me->query("neili") < 100)
  #         return notify_fail("你的内力不够。\n");
  # 
  #     if ((int)me->query_skill("jiuyin-shengong", 1) < 200)
  #         return notify_fail("你的九阴神功修为不够。\n");
  # 
  #     if ((int)me->query_temp("shield"))
  #         return notify_fail("你已经在运功中了。\n");
  # 
  #     skill = me->query_skill("force");
  #     me->add("neili", -100);
  #     me->receive_damage("qi", 0);
  # 
  #     message_combatd(HIW "$N" HIW "身子一晃，衣袖一波波的"
  #                         "不住激荡，劲气逼人！\n" NOR,
  #                     me);
  # 
  #     me->add_temp("apply/armor", skill / 2);
  #     me->set_temp("shield", 1);
  # 
  #     me->start_call_out((
  #                            : call_other, __FILE__, "remove_effect", me, skill / 2
  #                            :),
  #                        skill);
  # 
  #     if (me->is_fighting())
  #         me->start_busy(2);
  # 
  #     return 1;
  # }
  # 
  # void remove_effect(object me, int amount)
  # {
  #     if (me->query_temp("shield"))
  #     {
  #         me->add_temp("apply/armor", -amount);
  #         me->delete_temp("shield");
  #         tell_object(me, "你的九阴神功运行完毕，将内力收回丹田。\n");
  #     }
  # }
end
