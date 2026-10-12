defmodule Kantele.Combat.Skills.Performs.HuntianQigong.Shield do
  @moduledoc """
  exert「shield」（source huntian-qigong/shield.c，inherit F_CLEAN_UP）

  门槛（按 `.c` 顺序）：目标为自身 → 真气>=100 → 混天气功>=200 → 未在运功。
  扣 100 真气；持续 混天气功+占验+叫化 秒；战斗中忙乱 2 轮；到期回收。

  差异（TODO(migrate)）：
  - `.c` 的 `target != me` 门槛在 exert 语境下恒真，此处仅保留文案以对齐 `.c`；
  - `.c` 以 `add_temp("str", …)`/`add_temp("dex", …)` 提升先天属性（非 `apply/*`
    临时键），本引擎未建模 str/dex 临时属性，故本 buff 无数值加成，仅保留状态与
    到期回收（与 `Kantele.Combat.Skills.HuntianQigong.Shield` 的既有取舍一致）；
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

  @key "shield"

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

  # LPC: if (target != me) return notify_fail("你只能用混天气功来提升自己的防御力。\n");
  # exert 恒以自身为目标，故此门槛恒为 :ok，但保留文案以对齐 .c。
  defp check_target(_character) do
    _ = "你只能用混天气功来提升自己的防御力。\n"
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

  # LPC: if ((int)me->query_skill("huntian-qigong", 1) < 200)
  #              return notify_fail("你的混天气功修为不够。\n");
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "huntian-qigong") < 200 do
      {:error, "你的混天气功修为不够。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_temp("shield")) return notify_fail("你已经在运功中了。\n");
  defp check_other(character) do
    if Combat.buff_active?(character.meta.combat, @key) do
      {:error, "你已经在运功中了。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character) do
    # LPC: skill = me->query_skill("huntian-qigong", 1) +
    #              me->query_skill("checking", 1) +
    #              me->query_skill("begging", 1);
    #      me->add("neili", -100); me->receive_damage("qi", 0);
    #      message_combatd(HIW "$N" HIW "使出混天气功绝学「混元天罡」，一股白气"
    #                      "自顶心泥丸发散而下，全身弥漫在白色薄雾中！\n" NOR, me);
    #      me->add_temp("str", skill / 40);
    #      me->add_temp("dex", skill / 40);
    #      me->set_temp("shield", 1);
    #      me->start_call_out((: call_other, __FILE__, "remove_effect", me, skill / 40 :), skill);
    #      if (me->is_fighting()) me->start_busy(2);
    stats = character.meta.stats

    skill =
      Stats.skill(stats, "huntian-qigong") + Stats.skill(stats, "checking") +
        Stats.skill(stats, "begging")

    vitals = %{character.meta.vitals | neili: max(character.meta.vitals.neili - 100, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    # str/dex 临时属性未建模，buff 无数值加成，仅承担「运功中」状态与到期回收。
    buff = %Buff{key: @key, applies: %{}}

    combat =
      character.meta.combat
      |> Combat.add_buff(buff)
      |> start_busy_if_fighting(2)

    character = %{character | meta: %{character.meta | combat: combat}}

    conn =
      Broadcast.publish(
        conn,
        "$N使出混天气功绝学「混元天罡」，一股白气自顶心泥丸发散而下，全身弥漫在白色薄雾中！\n",
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

  # LPC remove_effect：tell_object(me, "你的混天气功运行完毕，白色的薄雾渐渐散去。\n");
  @doc false
  def expire_message, do: "你的混天气功运行完毕，白色的薄雾渐渐散去。\n"
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // shield.c 护体神功
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
  #                 return notify_fail("你只能用混天气功来提升自己的防御力。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你的内力不够。\n");
  # 
  #         if ((int)me->query_skill("huntian-qigong", 1) < 200)
  #                 return notify_fail("你的混天气功修为不够。\n");
  # 
  #         if ((int)me->query_temp("shield"))
  #                 return notify_fail("你已经在运功中了。\n");
  # 
  #         skill = me->query_skill("huntian-qigong", 1) +
  #                 me->query_skill("checking", 1) +
  #                 me->query_skill("begging", 1);
  #         me->add("neili", -100);
  #         me->receive_damage("qi", 0);
  # 
  #         message_combatd(HIW "$N" HIW "使出混天气功绝学「混元天罡」，一股白气"
  #                         "自顶心泥丸发散而下，全身弥漫在白色薄雾中！\n" NOR, me);
  # 
  # 
  #         me->add_temp("str", skill / 40);
  #         me->add_temp("dex", skill / 40);
  #         me->set_temp("shield", 1);
  # 
  #         me->start_call_out((: call_other, __FILE__, "remove_effect", me, skill / 40 :), skill);
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
  #                 me->add_temp("str", -amount);
  #                 me->add_temp("dex", -amount);
  #                 me->delete_temp("shield");
  #                 tell_object(me, "你的混天气功运行完毕，白色的薄雾渐渐散去。\n");
  #         }
  # }
end
