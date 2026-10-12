defmodule Kantele.Combat.Skills.Performs.HuntianBaojian.Powerup do
  @moduledoc """
  exert「powerup」（source huntian-baojian/powerup.c，inherit F_CLEAN_UP）

  门槛（按 `.c` 顺序）：目标为自身 → 真气>=150 → 未在运功。
  扣 100 真气；`attack`=`defense`=**基本内功/2**；持续 基本内功 秒；
  战斗中忙乱 3 轮；到期回收加成。

  前置广播里的「心法名」取自 `.c` 的 `force_name` 数组（4 选 1），插在
  「浑天宝鉴之「…」心法」中间——按仓库约定拆成 `"…之「" <> name <> "」心法…"`
  两段字面量，与 `.c` 的 `+ name +` 拼接逐段对齐。

  差异（TODO(migrate)）：
  - `.c` 的 `target != me` 门槛在 exert 语境下恒真，此处仅保留文案以对齐 `.c`；
  - `apply/attack`、`apply/defense` 与 `set_temp("powerup")` 由引擎 buff 机制承担
    （`Buff{key: "powerup"}` + `apply_temp/2`），到期自投递 `combat/buff-expire`；
  - `.c` 的 `me->receive_damage("qi", 0)` 伤害为 0、无文案，忽略；
  - `.c` 未列「是否已学此招」门槛（`can_perform`），本引擎由 exert 分派统一把关。
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

  # LPC: string *force_name = ({ NOR + HIB "靛沧海", HIY "金晨曦",
  #                             HIR "血穹苍", NOR + CYN "玄宇宙", });
  @force_names ["靛沧海", "金晨曦", "血穹苍", "玄宇宙"]

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

  # LPC: if (target != me) return notify_fail("你只能用浑天宝鉴来提升自己的战斗力。\n");
  # exert 恒以自身为目标，故此门槛恒为 :ok，但保留文案以对齐 .c。
  defp check_target(_character) do
    _ = "你只能用浑天宝鉴来提升自己的战斗力。\n"
    :ok
  end

  # LPC: if ((int)me->query("neili") < 150) return notify_fail("你的内力不够。\n");
  defp check_resources(character) do
    if character.meta.vitals.neili < 150 do
      {:error, "你的内力不够。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_temp("powerup")) return notify_fail("你已经在运功中了。\n");
  defp check_other(character) do
    if Combat.buff_active?(character.meta.combat, @key) do
      {:error, "你已经在运功中了。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character) do
    # LPC: name = force_name[random(sizeof(force_name))];
    #      skill = me->query_skill("force");
    #      me->add("neili", -100); me->receive_damage("qi", 0);
    #      message_combatd(HIW "$N" HIW "微一凝神，运起浑天宝鉴之「" + name +
    #                      HIW "」心法，一股气流顿将你震退数步。\n" NOR, me);
    #      me->add_temp("apply/attack", skill / 2);
    #      me->add_temp("apply/defense", skill / 2);
    #      me->set_temp("powerup", 1);
    #      me->start_call_out((: call_other, __FILE__, "remove_effect",
    #                            me, skill / 2 :), skill);
    #      if (me->is_fighting()) me->start_busy(3);
    name = Enum.at(@force_names, Engine.rand(&:rand.uniform/1, length(@force_names)))
    skill = Stats.skill(character.meta.stats, "force")
    gain = div(skill, 2)
    applies = %{attack: gain, defense: gain}

    vitals = %{character.meta.vitals | neili: max(character.meta.vitals.neili - 100, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    buff = %Buff{key: @key, applies: negate(applies)}

    combat =
      character.meta.combat
      |> Combat.apply_temp(applies)
      |> Combat.add_buff(buff)
      |> start_busy_if_fighting(3)

    character = %{character | meta: %{character.meta | combat: combat}}

    conn =
      Broadcast.publish(
        conn,
        "$N微一凝神，运起浑天宝鉴之「" <> name <> "」心法，一股气流顿将你震退数步。\n",
        n1: character.name
      )

    # LPC: start_call_out(remove_effect, skill) —— 持续 skill 秒
    schedule_expire(buff, skill)

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # 到期自投递（同 `hamagong/powerup.ex` 的写法：foreman 会把 delay_event 转给房间路由）。
  defp schedule_expire(buff, seconds) do
    Process.send_after(
      self(),
      %Event{
        from_pid: self(),
        topic: "combat/buff-expire",
        data: %{key: buff.key, applies: buff.applies, message: expire_message()}
      },
      max(seconds, 1) * 1000
    )
  end

  defp start_busy_if_fighting(combat, rounds) do
    if Combat.fighting?(combat), do: Combat.start_busy(combat, rounds), else: combat
  end

  # 到期回收按负值抵消（与 `Performs.Simple` 的 `{:buff, ...}` 一致）。
  defp negate(applies), do: Map.new(applies, fn {key, value} -> {key, -value} end)

  # LPC remove_effect：tell_object(me, "你的浑天宝鉴运行完毕，将内力收回丹田。\n");
  @doc false
  def expire_message, do: "你的浑天宝鉴运行完毕，将内力收回丹田。\n"
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # inherit F_CLEAN_UP;
  # 
  # string *force_name = ({ NOR + HIB "靛沧海", HIY "金晨曦",
  #                         HIR "血穹苍", NOR + CYN "玄宇宙", }); 
  # 
  # void remove_effect(object me, int amount);
  # 
  # int exert(object me, object target)
  # {
  #         int skill;
  #         string name;
  #         name = force_name[random(sizeof(force_name))];
  # 
  #         if (target != me)
  #                 return notify_fail("你只能用浑天宝鉴来提升自己的战斗力。\n");
  # 
  #         if ((int)me->query("neili") < 150)
  #                 return notify_fail("你的内力不够。\n");
  # 
  #         if ((int)me->query_temp("powerup"))
  #                 return notify_fail("你已经在运功中了。\n");
  # 
  #         skill = me->query_skill("force");
  #         me->add("neili", -100);
  #         me->receive_damage("qi", 0);
  # 
  #         message_combatd(HIW "$N" HIW "微一凝神，运起浑天宝鉴之「" + name +
  #                         HIW "」心法，一股气流顿将你震退数步。\n" NOR, me);
  # 
  #         me->add_temp("apply/attack", skill / 2);
  #         me->add_temp("apply/defense", skill / 2);
  #         me->set_temp("powerup", 1);
  # 
  #         me->start_call_out((: call_other, __FILE__, "remove_effect",
  #                               me, skill / 2 :), skill);
  # 
  #         if (me->is_fighting())
  #                 me->start_busy(3);
  # 
  #         return 1;
  # }
  # 
  # void remove_effect(object me, int amount)
  # {
  #         if (me->query_temp("powerup"))
  #         {
  #                 me->add_temp("apply/attack", -amount);
  #                 me->add_temp("apply/defense", -amount);
  #                 me->delete_temp("powerup");
  #                 tell_object(me, "你的浑天宝鉴运行完毕，将内力收回丹田。\n");
  #         }
  # }
end
