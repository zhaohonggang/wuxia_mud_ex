defmodule Kantele.Combat.Skills.Performs.LuohanFumogong.Fireice do
  @moduledoc """
  exert「冰火九重天」（source luohan-fumogong/fireice.c，inherit F_CLEAN_UP）

  自身增益：门槛（按 .c 顺序）→ 喝过玄冰碧火酒（未建模，暂免检）→ 仅自身 →
  未在施展中（`fireice`）→ 罗汉伏魔功>=180 → 内力上限>=4000 → 真气>=500。
  广播后按 skill 给 `apply/unarmed_damage`、`apply/damage`（各 `skill/5`）与
  `apply/armor`（`skill*2/5`）临时加成，置 `fireice` 标记，扣真气 300；
  持续 `skill` 秒后由 `remove_effect` 回收（本引擎以 buff 到期回执承担）；
  战斗中忙乱 3 轮。

  差异（TODO(migrate)）：
  - `.c` 的 `target != me` 在 exert 语境下恒为自身，`check_target/1` 恒 `:ok`，仅保留文案；
  - `.c` 的 `userp(me) && ! me->query("skybook/item/xuanbingjiu")`（喝过玄冰碧火酒）
    是未建模的任务道具标记 → 暂免检（与既有 `Kantele.Combat.Skills.LuohanFumogong`
    的「门派/物品门槛未建模」取舍一致），文案保留；
  - `.c` 的 `me->receive_damage("qi", 0)` 伤害为 0、无文案，忽略；
  - `remove_effect` 的 `add_temp("apply/armor", -amount * 2)`（`amount = skill/5`）与
    加成的 `skill * 2 / 5` **整除口径不同**（`.c` 原样，如 skill=183 时 73 加、72 减，
    会留 1 点残差），此处照搬以对齐 `.c`。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Combat.Buff
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast

  @key "fireice"
  @move_name "「冰火九重天」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_known(character),
         :ok <- check_target(character),
         :ok <- check_state(character),
         :ok <- check_levels(character),
         :ok <- check_max_neili(character),
         :ok <- check_neili(character) do
      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("skybook/item/xuanbingjiu"))
  #              return notify_fail("你所学的内功中没有这种功能。\n");
  # `skybook/item/xuanbingjiu`（喝过玄冰碧火酒）为任务道具标记，本引擎未建模 → 暂免检。
  defp check_known(_character) do
    _msg = "你所学的内功中没有这种功能。\n"
    :ok
  end

  # LPC: if (target != me) return notify_fail("你只能用" FIREICE "来提升自己的战斗力。\n");
  # exert 恒以自身为目标，故此门槛恒为 :ok，但保留文案以对齐 .c。
  defp check_target(_character) do
    _msg = "你只能用#{@move_name}来提升自己的战斗力。\n"
    :ok
  end

  # LPC: if ((int)me->query_temp("fireice")) return notify_fail("你现在正在施展" FIREICE "。\n");
  defp check_state(character) do
    if Combat.buff_active?(character.meta.combat, @key) do
      {:error, "你现在正在施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("luohan-fumogong", 1) < 180)
  #              return notify_fail("你罗汉伏魔功火候不足，难以施展" FIREICE "。\n");
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "luohan-fumogong") < 180 do
      {:error, "你罗汉伏魔功火候不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("max_neili") < 4000)
  #              return notify_fail("你的内力修为不足，难以施展" FIREICE "。\n");
  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 4000 do
      {:error, "你的内力修为不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 500)
  #              return notify_fail("你现在的内力不足，难以施展" FIREICE "。\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你现在的内力不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character) do
    # LPC: skill = me->query_skill("luohan-fumogong", 1);
    #      me->add("neili", -300); me->receive_damage("qi", 0);
    #      me->add_temp("apply/unarmed_damage", skill / 5);
    #      me->add_temp("apply/damage", skill / 5);
    #      me->add_temp("apply/armor", skill * 2 / 5);
    #      me->set_temp("fireice", 1);
    #      me->start_call_out((: call_other, __FILE__, "remove_effect", me, skill / 5 :), skill);
    #      if (me->is_fighting()) me->start_busy(3);
    skill = Stats.skill(character.meta.stats, "luohan-fumogong")

    applies = %{
      unarmed_damage: div(skill, 5),
      damage: div(skill, 5),
      armor: div(skill * 2, 5)
    }

    # remove_effect 按 `-amount`（amount = skill/5）与 `-amount * 2` 抵消 —— 与加成的
    # `skill * 2 / 5` 整除口径不同，故不用 negate/1 而显式给出（见 moduledoc）。
    removal = %{
      unarmed_damage: -div(skill, 5),
      damage: -div(skill, 5),
      armor: -(div(skill, 5) * 2)
    }

    vitals = %{character.meta.vitals | neili: max(character.meta.vitals.neili - 300, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    buff = %Buff{key: @key, applies: removal, duration: skill}

    combat =
      character.meta.combat
      |> Combat.apply_temp(applies)
      |> Combat.add_buff(buff)
      |> start_busy_if_fighting(3)

    character = %{character | meta: %{character.meta | combat: combat}}

    # LPC: message_combatd(HIC "$N" HIC "纵声长啸，运转「" HIW "冰" HIR "火" HIW "九重天"
    #            HIC "」真气，聚力" "于掌间，光华流动，煞为壮观。\n" NOR, me);
    conn =
      Broadcast.publish(
        conn,
        "$N纵声长啸，运转「冰火九重天」真气，聚力于掌间，光华流动，煞为壮观。\n",
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

  # LPC remove_effect：tell_object(me, "你的" FIREICE "运行完毕，将内力收回丹田。\n");
  @doc false
  def expire_message, do: "你的#{@move_name}运行完毕，将内力收回丹田。\n"
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # inherit F_CLEAN_UP;
  # 
  # #define FIREICE "「" HIW "冰" HIR "火" HIW "九重天" NOR "」"
  # 
  # void remove_effect(object me, int amount);
  # 
  # int exert(object me, object target)
  # {
  #         int skill;
  #         string fam;
  #         fam = me->query("family/family_name");
  # 
  #         if (userp(me) && ! me->query("skybook/item/xuanbingjiu"))
  #                 return notify_fail("你所学的内功中没有这种功能。\n");
  # 
  #         if (target != me)
  #                 return notify_fail("你只能用" FIREICE "来提升自己的战斗力。\n");
  # 
  #         if ((int)me->query_temp("fireice"))
  #                 return notify_fail("你现在正在施展" FIREICE "。\n");
  # 
  #         if ((int)me->query_skill("luohan-fumogong", 1) < 180)
  #                 return notify_fail("你罗汉伏魔功火候不足，难以施展" FIREICE "。\n");
  # 
  #         if ((int)me->query("max_neili") < 4000)
  #                 return notify_fail("你的内力修为不足，难以施展" FIREICE "。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你现在的内力不足，难以施展" FIREICE "。\n");
  # 
  #         skill = me->query_skill("luohan-fumogong", 1);
  #         me->add("neili", -300);
  #         me->receive_damage("qi", 0);
  # 
  #         message_combatd(HIC "$N" HIC "纵声长啸，运转「" HIW "冰"
  #                         HIR "火" HIW "九重天" HIC "」真气，聚力"
  #                         "于掌间，光华流动，煞为壮观。\n" NOR, me);
  # 
  #         me->add_temp("apply/unarmed_damage", skill / 5);
  #         me->add_temp("apply/damage", skill / 5);
  #         me->add_temp("apply/armor", skill * 2 / 5);
  #         me->set_temp("fireice", 1);
  # 
  #         me->start_call_out((: call_other, __FILE__, "remove_effect",
  #                               me, skill / 5 :), skill);
  # 
  #         if (me->is_fighting())
  #                 me->start_busy(3);
  # 
  #         return 1;
  # }
  # 
  # void remove_effect(object me, int amount)
  # {
  #         if (me->query_temp("fireice"))
  #         {
  #                 me->add_temp("apply/unarmed_damage", -amount);
  #                 me->add_temp("apply/damage", -amount);
  #                 me->add_temp("apply/armor", -amount * 2);
  #                 me->delete_temp("fireice");
  #                 tell_object(me, "你的" FIREICE "运行完毕，将内力收回丹田。\n");
  #         }
  # }
end
