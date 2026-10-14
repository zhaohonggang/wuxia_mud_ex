defmodule Kantele.Combat.Skills.Performs.NeverDefeated.Shield do
  @moduledoc """
  exert「shield / 不败神功护体」（对照 `kungfu/skill/never-defeated/exert/shield.c`）

  门槛（按 .c 顺序）：仅自身 → 真气>=100 → 不败神功>=50 → 未在运护体中。
  广播后扣 100 真气，按**内功等级**给 armor +`等级/2` 临时加成，置 `shield` 标记；
  战斗中忙乱 2；`内功` 秒后到期移除加成并提示。

  差异（TODO(migrate)）：
  - `target != me` 在框架 exert 中恒为自身，`check_target/1` 恒为 :ok，仅保留文案；
  - `.c` 的 `skill = me->query_skill("force")`（内功等级），非不败神功等级；
    加成 `skill/2`、时长 `skill` 秒、移除量同为 `skill/2`；
  - `me->query_temp("shield")` + `set_temp("shield", 1)` +
    `start_call_out(remove_effect, skill/2)` 折算为
    `Combat.Buff{key: "shield", applies: %{armor: -skill/2}}` + `Combat.add_buff` +
    `combat/buff-expire` 定时回收（`Combat.buff_active?/2` 判门槛），
    `remove_effect` 的 `tell_object` 文案作为到期提示；
  - `me->receive_damage("qi", 0)` 为无效果调用，略去；
  - 本式的 `@key` 为 `"shield"`，与同目录 `powerup` 的 `"powerup"` 相互独立。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Combat.Buff
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast

  @key "shield"

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

  # LPC: if (target != me) return notify_fail("你只能用不败神功来提升自己的防御力。\n");
  defp check_target(_character) do
    # 框架 exert 的 target 即自身
    _msg = "你只能用不败神功来提升自己的防御力。\n"
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

  # LPC: if ((int)me->query_skill("never-defeated",1) < 50)
  #      return notify_fail("你的不败神功修为不够。\n");
  defp check_level(character) do
    if Stats.skill(character.meta.stats, "never-defeated") < 50 do
      {:error, "你的不败神功修为不够。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_temp("shield")) return notify_fail("你已经在运功中了。\n");
  defp check_state(character) do
    if Combat.buff_active?(character.meta.combat, @key) do
      {:error, "你已经在运功中了。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character) do
    # LPC: skill = me->query_skill("force");
    skill = Stats.skill(character.meta.stats, "force")
    amount = div(skill, 2)

    # LPC: message_combatd(HIC "$N" HIC "双臂轻轻一展，一股劲气登时笼罩全身！\n" NOR, me);
    conn =
      Broadcast.publish(conn, "$N双臂轻轻一展，一股劲气登时笼罩全身！\n", n1: character.name)

    # LPC: me->add("neili", -100);
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 100}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: me->add_temp("apply/armor", skill / 2);
    #      me->set_temp("shield", 1);
    #      me->start_call_out((: call_other, __FILE__, "remove_effect", me, skill / 2 :), skill);
    combat = character.meta.combat
    combat = Combat.apply_temp(combat, %{armor: amount})

    buff = %Buff{key: @key, applies: %{armor: -amount}, duration: skill}
    combat = Combat.add_buff(combat, buff)

    # LPC: if (me->is_fighting()) me->start_busy(2);
    combat =
      if Combat.fighting?(combat) do
        Combat.start_busy(combat, 2)
      else
        combat
      end

    character = %{character | meta: %{character.meta | combat: combat}}
    schedule_expire(buff)

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # LPC: remove_effect 的 tell_object(me, "你的不败神功运行完毕，将内力收回丹田。\n");
  defp expire_message, do: "你的不败神功运行完毕，将内力收回丹田。\n"

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
  #         return notify_fail("你只能用不败神功来提升自己的防御力。\n");
  # 
  #     if ((int)me->query("neili") < 100)
  #         return notify_fail("你的内力不够。\n");
  # 
  #     if ((int)me->query_skill("never-defeated",1) < 50)
  #         return notify_fail("你的不败神功修为不够。\n");
  # 
  #     if ((int)me->query_temp("shield"))
  #         return notify_fail("你已经在运功中了。\n");
  # 
  #     skill = me->query_skill("force");
  #     me->add("neili", -100);
  #     me->receive_damage("qi", 0);
  # 
  #     message_combatd(HIC "$N" HIC "双臂轻轻一展，一股劲气登时笼罩全身！\n" NOR, me);
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
  #             tell_object(me, "你的不败神功运行完毕，将内力收回丹田。\n");
  #         }
  # }
end
