defmodule Kantele.Combat.Skills.Performs.MiaojiaNeigong.Powerup do
  @moduledoc """
  exert「powerup / 苗家加力」（对照 `kungfu/skill/miaojia-neigong/powerup.c`）

  门槛（按 .c 顺序）：仅自身 → 真气>=100 → 未在运功中。
  广播后扣 100 真气，按苗家内功等级给 attack/defense 各 +`等级/3` 临时加成，
  置 `powerup` 标记；战斗中忙乱 `1 + random(3)`；`苗家内功` 秒后到期移除加成并提示。

  差异（TODO(migrate)）：
  - `target != me` 在框架 exert 中恒为自身，`check_target/1` 恒为 :ok，仅保留文案；
  - `me->query_temp("powerup")` + `set_temp("powerup", 1)` +
    `start_call_out(remove_effect, skill)` 折算为
    `Combat.Buff{key: "powerup", applies: %{attack: -skill/3, defense: -skill/3}}` +
    `Combat.add_buff` + `combat/buff-expire` 定时回收（`Combat.buff_active?/2` 判门槛），
    `remove_effect` 的 `tell_object` 文案作为到期提示；
  - `me->receive_damage("qi", 0)` 为无效果调用，略去。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Combat.Buff
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine

  @key "powerup"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    rng = &:rand.uniform/1

    with :ok <- check_target(character),
         :ok <- check_resources(character),
         :ok <- check_state(character) do
      apply_effect(conn, character, rng)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (target != me) return notify_fail("你只能用苗家内功提升自己的战斗力。\n");
  defp check_target(_character) do
    # 框架 exert 的 target 即自身
    _msg = "你只能用苗家内功提升自己的战斗力。\n"
    :ok
  end

  # LPC: if ((int)me->query("neili") < 100) return notify_fail("你的内力不够了。");
  defp check_resources(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你的内力不够了。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_temp("powerup")) return notify_fail("你已经在运功中了。\n");
  defp check_state(character) do
    if Combat.buff_active?(character.meta.combat, @key) do
      {:error, "你已经在运功中了。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character, rng) do
    # LPC: skill = me->query_skill("miaojia-neigong", 1);
    skill = Stats.skill(character.meta.stats, "miaojia-neigong")
    amount = div(skill, 3)

    # LPC: message_combatd(YEL "$N" YEL "运起苗家内功，气劲迸发，全身上下便犹如蒙上"
    #                        "了一层淡淡的金纸。\n" NOR, me);（合并为单段）
    conn =
      Broadcast.publish(
        conn,
        "$N运起苗家内功，气劲迸发，全身上下便犹如蒙上了一层淡淡的金纸。\n",
        n1: character.name
      )

    # LPC: me->add("neili", -100);
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 100}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: me->add_temp("apply/attack", skill / 3);
    #      me->add_temp("apply/defense", skill / 3);
    #      me->set_temp("powerup", 1);
    #      me->start_call_out((: call_other, __FILE__, "remove_effect", me, skill / 3 :), skill);
    combat = character.meta.combat
    combat = Combat.apply_temp(combat, %{attack: amount, defense: amount})
    buff = %Buff{key: @key, applies: %{attack: -amount, defense: -amount}, duration: skill}
    combat = Combat.add_buff(combat, buff)

    # LPC: if (me->is_fighting()) me->start_busy(1 + random(3));
    combat =
      if Combat.fighting?(combat) do
        Combat.start_busy(combat, 1 + Engine.rand(rng, 3))
      else
        combat
      end

    character = %{character | meta: %{character.meta | combat: combat}}
    schedule_expire(buff)

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # LPC: remove_effect 的 tell_object(me, "你的苗家内功运行完毕，将内力收回丹田。\n");
  defp expire_message, do: "你的苗家内功运行完毕，将内力收回丹田。\n"

  defp schedule_expire(buff) do
    Process.send_after(
      self(),
      %Event{
        from_pid: self(),
        topic: "combat/buff-expire",
        data: %{key: buff.key, applies: buff.applies, message: expire_message()}
      },
      max(buff.duration, 1) * 1000
    )
  end
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
  #         int skill;
  # 
  #         if (target != me)
  #                 return notify_fail("你只能用苗家内功提升自己的战斗力。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你的内力不够了。");
  # 
  #         if ((int)me->query_temp("powerup"))
  #                 return notify_fail("你已经在运功中了。\n");
  # 
  #         skill = me->query_skill("miaojia-neigong", 1);
  # 
  #         me->add("neili", -100);
  #         me->receive_damage("qi", 0);
  # 
  #         message_combatd(YEL "$N" YEL "运起苗家内功，气劲迸发，全身上下便犹如蒙上"
  #                         "了一层淡淡的金纸。\n" NOR, me);
  # 
  #         me->add_temp("apply/attack", skill / 3);
  #         me->add_temp("apply/defense", skill / 3);
  #         me->set_temp("powerup", 1);
  # 
  #         me->start_call_out((: call_other, __FILE__, "remove_effect",
  #                            me, skill / 3 :), skill);
  # 
  #         if (me->is_fighting()) me->start_busy(1 + random(3));
  # 
  #         return 1;
  # }
  # 
  # void remove_effect(object me, int amount)
  # {
  #         if ((int)me->query_temp("powerup"))
  #         {
  #                 me->add_temp("apply/attack", -amount);
  #                 me->add_temp("apply/defense", -amount);
  #                 me->delete_temp("powerup");
  #                 tell_object(me, "你的苗家内功运行完毕，将内力收回丹田。\n");
  #         }
  # }
end
