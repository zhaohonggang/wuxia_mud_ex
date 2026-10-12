defmodule Kantele.Combat.Skills.Performs.ChangshengJue.Powerup do
  @moduledoc """
  exert「powerup」（source changsheng-jue/powerup.c，由 translate_perform.py 生成，inherit F_CLEAN_UP）

  门槛（按 .c 顺序）：目标为自身 → 真气>=100 → 未在运功。
  扣 100 真气；attack=parry=dodge=基本内功*2/5；持续 基本内功 秒；
  战斗中 busy 3；到期回收。

  差异（TODO(migrate)）：
  - `apply/attack`、`apply/parry`、`apply/dodge` 临时加成与 `set_temp("powerup")` 由
    引擎 buff 机制承担（真实运行为 `Kantele.Combat.Skills.ChangshengJue.Powerup`
    的 `Performs.Simple` spec），本文件为并存的对齐副本。
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
    skill = Stats.skill(character.meta.stats, "force")

    with :ok <- check_gates(character) do
      apply_effect(conn, character, skill)
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

  # LPC: if (target != me) return notify_fail("你只能用长生决来提升自己的战斗力。\n");
  # exert 恒以自身为目标，故此门槛恒为 :ok，但保留文案以对齐 .c。
  defp check_target(_character) do
    _ = "你只能用长生决来提升自己的战斗力。\n"
    :ok
  end

  # LPC: if ((int) me->query("neili") < 100)
  defp check_resources(character) do
    vitals = character.meta.vitals

    if vitals.neili < 100 do
      {:error, "你的内力不够。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int) me->query_temp("powerup"))
  defp check_other(character) do
    if Combat.buff_active?(character.meta.combat, "powerup") do
      {:error, "你已经在运功中了。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character, skill) do
    # LPC: me->add("neili", -100); me->receive_damage("qi", 0);
    #      message_combatd(HIW "$N" HIW "微一凝神，运起长生决，将真气"
    #                      "凝聚在丹田之中，沿奇经八脉遍布全身！\n" NOR, me);
    #      apply/attack += skill * 2 / 5; apply/parry += skill * 2 / 5;
    #      apply/dodge += skill * 2 / 5; me->set_temp("powerup", 1);
    #      me->start_call_out(remove_effect(me, skill * 2), skill);
    #      if (me->is_fighting()) me->start_busy(3);
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    combat = character.meta.combat

    combat =
      if Combat.fighting?(combat), do: Combat.start_busy(combat, 3), else: combat

    # LPC: add_temp 是 skill * 2 / 5；remove_effect 回收的 amount 是 skill * 2
    #      （.c 自身不对称）。引擎 Buff.applies 精确抵消施加值，不复制该缺陷。
    bonus = div(skill * 2, 5)

    combat = Combat.apply_temp(combat, %{attack: bonus, parry: bonus, dodge: bonus})

    combat =
      Combat.add_buff(combat, %Kantele.Character.Combat.Buff{
        key: "powerup",
        applies: %{attack: -bonus, parry: -bonus, dodge: -bonus},
        duration: skill
      })

    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> Broadcast.publish("$N微一凝神，运起长生决，将真气凝聚在丹田之中，沿奇经八脉遍布全身！\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # LPC remove_effect：tell_object(me, "你的长生决运行完毕，将内力收回丹田。\n");
  @doc false
  def expire_message, do: "你的长生决运行完毕，将内力收回丹田。\n"

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
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
  #                 return notify_fail("你只能用长生决来提升自己的战斗力。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你的内力不够。\n");
  # 
  #         if ((int)me->query_temp("powerup"))
  #                 return notify_fail("你已经在运功中了。\n");
  # 
  #         skill = me->query_skill("force");
  #         me->add("neili", -100);
  #         me->receive_damage("qi", 0);
  # 
  #         message_combatd(HIW "$N" HIW "微一凝神，运起长生决，将真气"
  #                         "凝聚在丹田之中，沿奇经八脉遍布全身！\n" NOR, me);
  # 
  #         me->add_temp("apply/attack", skill * 2 / 5);
  #         me->add_temp("apply/parry", skill * 2 / 5);
  #         me->add_temp("apply/dodge", skill * 2 / 5);
  #         me->set_temp("powerup", 1);
  # 
  #         me->start_call_out( (: call_other, __FILE__, "remove_effect", me, skill * 2 :), skill);
  # 
  #         if (me->is_fighting()) me->start_busy(3);
  # 
  #         return 1;
  # }
  # 
  # void remove_effect(object me, int amount)
  # {
  #         if ((int)me->query_temp("powerup"))
  #         {
  #                 me->add_temp("apply/attack", - amount);
  #                 me->add_temp("apply/parry", - amount);
  #                 me->add_temp("apply/dodge", - amount);
  #                 me->delete_temp("powerup");
  #                 tell_object(me, "你的长生决运行完毕，将内力收回丹田。\n");
  #         }
  # }
end
