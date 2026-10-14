defmodule Kantele.Combat.Skills.Performs.LuohanFumogong.Powerup do
  @moduledoc """
  exert「powerup / 罗汉伏魔神功加力」（source luohan-fumogong/powerup.c，inherit F_CLEAN_UP）

  自身加力：门槛（按 .c 顺序）→ 少林派或喝过玄冰碧火酒（道具标记未建模，暂免检）→
  仅自身 → 真气>=150 → 未在运功中（`powerup`）。
  广播（按「有酒且少林派」/「少林派」/「其余」三条互斥文案）后按 skill 给
  `apply/attack`、`apply/defense`（各 `skill/3`）临时加成，置 `powerup` 标记，
  扣真气 100；持续 `skill` 秒后由 `remove_effect` 回收（本引擎以 buff 到期回执承担）；
  战斗中忙乱 3 轮。

  差异（TODO(migrate)）：
  - `.c` 的 `userp(me) && fam != "少林派" && ! me->query("skybook/item/xuanbingjiu")`
    含未建模的门派/任务道具门槛；道具是**或**条件，单独按门派判定会误拦「非少林派但持有
    该酒」的玩家 → 整条暂免检（与既有 `Kantele.Combat.Skills.LuohanFumogong` 的取舍一致），
    比较与文案保留以对齐 `.c`；
  - `.c` 的 `target != me` 在 exert 语境下恒为自身，`check_target/1` 恒 `:ok`，仅保留文案；
  - `.c` 的 `me->receive_damage("qi", 0)` 伤害为 0、无文案，忽略；
  - `.c` 的三条文案在 `NOR + HIB`/`NOR + 颜色宏` 处**断段**（有 `+`），故 E 侧用
    `Enum.join([...], "")` 保持两段，不能用 `<>`（会被合并成一段）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Combat.Buff
  alias Kantele.Character.Family
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast

  @key "powerup"
  @move_name "罗汉伏魔神功"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_known(character),
         :ok <- check_target(character),
         :ok <- check_neili(character),
         :ok <- check_state(character) do
      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && fam != "少林派" && ! me->query("skybook/item/xuanbingjiu"))
  #              return notify_fail("你所学的内功中没有这种功能。\n");
  # 门派（`fam`）与任务道具（`skybook/item/xuanbingjiu`，喝过玄冰碧火酒）门槛本引擎未建模
  # → 暂免检（与既有 `Kantele.Combat.Skills.LuohanFumogong` 的取舍一致）；比较与文案保留
  # 以对齐 .c（道具是「或」条件，单独按门派判定会误拦「非少林派但持有该酒」的玩家）。
  defp check_known(character) do
    fam = Family.name(Map.get(character.meta, :family, %{}))
    _msg = "你所学的内功中没有这种功能。\n"

    # 门派分支仅为对齐 .c 的 `少林派` 字面量，不据此拦截。
    case fam do
      "少林派" -> :ok
      _other -> :ok
    end
  end

  # LPC: if (target != me) return notify_fail("你只能用罗汉伏魔神功来提升自己的战斗力。\n");
  # exert 恒以自身为目标，故此门槛恒为 :ok，但保留文案以对齐 .c。
  defp check_target(_character) do
    _msg = "你只能用#{@move_name}来提升自己的战斗力。\n"
    :ok
  end

  # LPC: if ((int)me->query("neili") < 150) return notify_fail("你的内力不够。\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 150 do
      {:error, "你的内力不够。\n"}
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

  defp apply_effect(conn, character) do
    # LPC: fam = me->query("family/family_name"); skill = me->query_skill("luohan-fumogong", 1);
    #      me->add("neili", -100); me->receive_damage("qi", 0);
    #      me->add_temp("apply/attack", skill / 3);
    #      me->add_temp("apply/defense", skill / 3);
    #      me->set_temp("powerup", 1);
    #      me->start_call_out((: call_other, __FILE__, "remove_effect", me, skill / 3 :), skill);
    #      if (me->is_fighting()) me->start_busy(3);
    fam = Family.name(Map.get(character.meta, :family, %{}))
    # `skybook/item/xuanbingjiu`（喝过玄冰碧火酒）是 set() 属性仓库（`meta.env`）里的任务
    # 道具标记，本引擎中不可得 → 「有酒且少林派」分支实际不可达，保留以对齐 .c。
    env = Map.get(character.meta, :env, %{}) || %{}
    has_item = Map.get(env, "skybook/item/xuanbingjiu") != nil
    skill = Stats.skill(character.meta.stats, "luohan-fumogong")
    gain = div(skill, 3)
    applies = %{attack: gain, defense: gain}

    vitals = %{character.meta.vitals | neili: max(character.meta.vitals.neili - 100, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    buff = %Buff{key: @key, applies: negate(applies), duration: skill}

    combat =
      character.meta.combat
      |> Combat.apply_temp(applies)
      |> Combat.add_buff(buff)
      |> start_busy_if_fighting(3)

    character = %{character | meta: %{character.meta | combat: combat}}

    conn = Broadcast.publish(conn, run_text(has_item, fam), n1: character.name)

    # LPC: start_call_out(remove_effect, skill) —— 持续 skill 秒
    schedule_expire(buff, skill)

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # LPC 三条互斥文案（`NOR + HIB`/`NOR + HIR` 处有 `+` → 断段，故用 Enum.join 保持两段）
  defp run_text(has_item, fam) do
    cond do
      # LPC: if (me->query("skybook/item/xuanbingjiu") && fam == "少林派")
      #        message_combatd(HIY "$N" HIY "高呼一声佛号，运起罗汉伏魔神"
      #                        "功，全身皮肤一半呈现" NOR + HIB "靛青" HIY
      #                        "色，另一半却为" HIR "血红" HIY "色。\n" NOR, me);
      has_item and fam == "少林派" ->
        Enum.join(
          [
            "$N高呼一声佛号，运起罗汉伏魔神功，全身皮肤一半呈现",
            "靛青色，另一半却为血红色。\n"
          ],
          ""
        )

      # LPC: else if (fam == "少林派") message_combatd(HIY "$N" HIY "高呼一声佛号，运起罗汉伏魔神"
      #                        "功，全身真气澎湃，衣衫随之鼓胀。\n" NOR, me);
      fam == "少林派" ->
        "$N高呼一声佛号，运起罗汉伏魔神功，全身真气澎湃，衣衫随之鼓胀。\n"

      # LPC: else message_combatd(HIY "$N" HIY "微一凝神，运起罗汉伏魔神功，"
      #                        "全身肌肤竟交替呈现出" NOR + HIB "靛青" HIY
      #                        "与" HIR "血红" HIY "两色。\n" NOR, me);
      true ->
        Enum.join(
          [
            "$N微一凝神，运起罗汉伏魔神功，全身肌肤竟交替呈现出",
            "靛青与血红两色。\n"
          ],
          ""
        )
    end
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

  # LPC remove_effect：tell_object(me, "你的罗汉伏魔神功运行完毕，将内力收回丹田。\n");
  @doc false
  def expire_message, do: "你的#{@move_name}运行完毕，将内力收回丹田。\n"
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
  #         string fam;
  #         fam = me->query("family/family_name");
  # 
  #         // 要求只有喝过玄冰碧火酒或是少林派玩家才能施展
  #         if (userp(me)
  #            && fam != "少林派"
  #            && ! me->query("skybook/item/xuanbingjiu"))
  #                 return notify_fail("你所学的内功中没有这种功能。\n");
  # 
  #         if (target != me)
  #                 return notify_fail("你只能用罗汉伏魔神功来提升自己的战斗力。\n");
  # 
  #         if ((int)me->query("neili") < 150)
  #                 return notify_fail("你的内力不够。\n");
  # 
  #         if ((int)me->query_temp("powerup"))
  #                 return notify_fail("你已经在运功中了。\n");
  # 
  #         skill = me->query_skill("luohan-fumogong", 1);
  #         me->add("neili", -100);
  #         me->receive_damage("qi", 0);
  # 
  #         if (me->query("skybook/item/xuanbingjiu")
  #            && fam == "少林派")
  #             message_combatd(HIY "$N" HIY "高呼一声佛号，运起罗汉伏魔神"
  #                                 "功，全身皮肤一半呈现" NOR + HIB "靛青" HIY
  #                                 "色，另一半却为" HIR "血红" HIY "色。\n"
  #                                 NOR, me);
  #         else
  # 
  #         if (fam == "少林派")
  #             message_combatd(HIY "$N" HIY "高呼一声佛号，运起罗汉伏魔神"
  #                                 "功，全身真气澎湃，衣衫随之鼓胀。\n"
  #                                 NOR, me);
  # 
  #         else
  #             message_combatd(HIY "$N" HIY "微一凝神，运起罗汉伏魔神功，"
  #                                 "全身肌肤竟交替呈现出" NOR + HIB "靛青" HIY
  #                                 "与" HIR "血红" HIY "两色。\n" NOR, me);
  # 
  # 
  #         me->add_temp("apply/attack", skill / 3);
  #         me->add_temp("apply/defense", skill / 3);
  #         me->set_temp("powerup", 1);
  # 
  # 
  #         me->start_call_out((: call_other, __FILE__, "remove_effect",
  #                               me, skill / 3 :), skill);
  # 
  #         if (me->is_fighting())
  #                 me->start_busy(3);
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
  #                 tell_object(me, "你的罗汉伏魔神功运行完毕，将内力收回丹田。\n");
  #         }
  # }
end
