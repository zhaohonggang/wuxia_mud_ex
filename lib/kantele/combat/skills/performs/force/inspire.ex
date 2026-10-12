defmodule Kantele.Combat.Skills.Performs.Force.Inspire do
  @moduledoc """
  exert「inspire」（source force/inspire.c）

  自我振奋，门槛（按 `.c` 顺序）：已打通任督（`breakup`）→ 非战斗 →
  已激发内功 → 该内功>=200 → `eff_jing < max_jing` → 真气>=200 →
  `eff_jing >= max_jing/4`。
  起手广播并设 `short_desc`，随后进入 LPC 的 `start_busy` 异步循环 `inspiring/1`：
  每轮 `receive_curing("jing", 5+force/6)` 并扣真气 100；无内功/真气不足时中断，
  精满时播收功文案；`halt_inspiring/1` 为手动中断回调。

  差异（TODO(migrate)）：
  - 真实运行为 `Kantele.Combat.Skills.Force.Inspire`（`skills/force_inspire.ex`）的
    `Performs.Simple` spec（单次回复版），本文件为并存的对齐副本（仅供文案对齐）；
  - `inspiring/1`、`halt_inspiring/1` 是 LPC `start_busy` 回调，引擎未建模该异步循环，
    故以 `inspiring_messages/4` 等 `@doc false` 函数原样保留分支与文案，未被调用；
  - `.c` 的 `userp(me) && ...` 中「玩家」判定引擎未建模，只保留其余条件；
  - `to_chinese(force)` 折算为映射 id 原样（引擎未维护内功 id→中文名 表）；
  - LPC `eff_jing`/`max_jing` 对应本引擎 `vitals.max_jing`/`vitals.base_jing`；
  - `set_short_desc` 对应 `character.meta.short_desc`。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.SpecialSkills
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast

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
    with :ok <- check_breakup(character),
         :ok <- check_not_fighting(character),
         :ok <- check_has_force(character),
         :ok <- check_force_level(character),
         :ok <- check_needs_inspire(character),
         :ok <- check_neili(character),
         :ok <- check_not_critical(character) do
      :ok
    end
  end

  # LPC: if (userp(me) && ! me->query("breakup"))
  #        return notify_fail("你所学的内功中没有这种功能。\n");
  defp check_breakup(character) do
    if SpecialSkills.owned?(character.attributes, "breakup") do
      :ok
    else
      {:error, "你所学的内功中没有这种功能。\n"}
    end
  end

  # LPC: if (me->is_fighting()) return notify_fail("现在你正在战斗中？还是等打完了再说吧！\n");
  defp check_not_fighting(character) do
    if Combat.fighting?(character.meta.combat) do
      {:error, "现在你正在战斗中？还是等打完了再说吧！\n"}
    else
      :ok
    end
  end

  # LPC: force = me->query_skill_mapped("force");
  #      if (! stringp(force)) return notify_fail("先激发你的特殊内功。\n");
  defp check_has_force(character) do
    if Stats.mapped(character.meta.stats, "force") == nil do
      {:error, "先激发你的特殊内功。\n"}
    else
      :ok
    end
  end

  # LPC: if (userp(me) && (int)me->query_skill(force, 1) < 200)
  #        return notify_fail("你的" + to_chinese(force) + "修为还不够。\n");
  # C 侧 "你的" + to_chinese(force) + "修为还不够。\n" 被显式 `+` 切成两段，E 侧同粒度。
  defp check_force_level(character) do
    force = Stats.mapped(character.meta.stats, "force")

    if Stats.skill(character.meta.stats, force) < 200 do
      {:error, "你的" <> to_chinese(force) <> "修为还不够。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("eff_jing") >= (int)me->query("max_jing"))
  #        return notify_fail("你现在精神饱满，有什么好激励的？\n");
  defp check_needs_inspire(character) do
    vitals = character.meta.vitals

    if vitals.max_jing >= vitals.base_jing do
      {:error, "你现在精神饱满，有什么好激励的？\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 200) return notify_fail("你的真气不够。\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你的真气不够。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("eff_jing") < (int)me->query("max_jing") / 4)
  #        return notify_fail("你的精损伤太重，现在难以振奋自己。\n");
  defp check_not_critical(character) do
    vitals = character.meta.vitals

    if vitals.max_jing < div(vitals.base_jing, 4) do
      {:error, "你的精损伤太重，现在难以振奋自己。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character) do
    # LPC: message_vision(HIW "$N" HIW "盘膝坐下，闭目冥神，缓缓的呼吸吐纳。\n" NOR, me);
    conn =
      Broadcast.publish(conn, "$N盘膝坐下，闭目冥神，缓缓的呼吸吐纳。\n", n1: character.name)

    # LPC: me->set_temp("pending/inspiring", 1);
    #      me->set_short_desc("正坐在地下运功疗伤。");
    character =
      character
      |> put_in([:meta, :temp], Map.put(character.meta.temp, :pending_inspiring, true))
      |> put_in([:meta, :short_desc], "正坐在地下运功疗伤。")

    # LPC: me->start_busy((:call_other, __FILE__, "inspiring"), (:call_other, __FILE__, "halt_inspiring"));
    # 引擎未建模异步 busy 循环（真实实现为单次回复），首轮扣 100 真气。
    vitals = character.meta.vitals
    vitals = %{vitals | neili: max(vitals.neili - 100, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # LPC: int inspiring(object me) —— `start_busy` 驱动的振奋循环回调。
  # 引擎未建模该异步循环（真实实现为单次回复），此处按 `.c` 分支原样保留文案；
  # `roll` 对应 `random(10)`。
  @doc false
  def inspiring_messages(has_force?, neili_ok?, roll, force_name) do
    cond do
      # 没有特殊内功了？
      not has_force? ->
        ["你一时难以定夺如何运用内力，只好先暂停疗伤。\n", "$N叹了口气，摇摇晃晃的站了起来。\n"]

      # 需要继续振奋，但真气不济
      not neili_ok? ->
        ["你觉得真气不济，难以在经脉中继续运转振奋。\n", "$N叹了口气，摇摇晃晃的站了起来。\n"]

      roll == 0 ->
        # LPC: tell_object(me, "你运用" + to_chinese(force) + "沿着诸大穴慢慢运转，振奋精神。\n");
        ["你运用" <> to_chinese(force_name) <> "沿着诸大穴慢慢运转，振奋精神。\n"]

      roll == 1 ->
        ["你将内力纳入丹田，再上行冲顶，透泥宫，顿觉精神爽快。\n"]

      roll == 2 ->
        ["你运转内力，缓缓呼吸吐纳，额头上渗出点点汗珠，随即化作白雾蒸腾而起。\n"]

      true ->
        []
    end
  end

  # LPC: 恢复完毕 —— message_vision(HIY "$N" HIY "缓缓睁开双目，精光四射，神清意爽。\n" NOR, me);
  @doc false
  def inspiring_done_message, do: "$N缓缓睁开双目，精光四射，神清意爽。\n"

  # LPC: int halt_inspiring(object me) —— 手动中断回调（引擎未建模）。
  @doc false
  def halt_inspiring_messages do
    [
      "你将真气收回丹田，微微喘息，站了起来。\n",
      "猛的吸一口气，突然站了起来。\n"
    ]
  end

  # LPC: to_chinese(force) —— 引擎未维护内功 id→中文名 表，保留 id 原样
  # （同 `sanku_shengong/dispel.ex` 的对齐副本约定）。
  defp to_chinese(name), do: name
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // inspire.c
  # 
  # #include <ansi.h>
  # 
  # int exert(object me, object target)
  # {
  #         string force;
  # 
  #         if (userp(me) && ! me->query("breakup"))
  #                 return notify_fail("你所学的内功中没有这种功能。\n");
  # 
  #         if (me->is_fighting())
  #                 return notify_fail("现在你正在战斗中？还是等打完了再说吧！\n");
  # 
  #         force = me->query_skill_mapped("force");
  # 
  #         if (! stringp(force))
  #                 return notify_fail("先激发你的特殊内功。\n");
  # 
  #         if (userp(me) && (int)me->query_skill(force, 1) < 200)
  #                 return notify_fail("你的" + to_chinese(force) + "修为还不够。\n");
  # 
  #         if ((int)me->query("eff_jing") >= (int)me->query("max_jing"))
  #                 return notify_fail("你现在精神饱满，有什么好激励的？\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你的真气不够。\n");
  # 
  #         if ((int)me->query("eff_jing") < (int)me->query("max_jing") / 4)
  #                 return notify_fail("你的精损伤太重，现在难以振奋自己。\n");
  # 
  #         message_vision(HIW "$N" HIW "盘膝坐下，闭目冥神，缓缓的呼吸吐纳。\n" NOR, me);
  # 
  #         me->set_temp("pending/inspiring", 1);
  #         me->set_short_desc("正坐在地下运功疗伤。");
  # 
  #         me->start_busy((:call_other, __FILE__, "inspiring" :),
  #                        (:call_other, __FILE__, "halt_inspiring" :));
  #         return 1;
  # }
  # 
  # // 振奋中
  # int inspiring(object me)
  # {
  #         string force;
  #         int recover_points;
  # 
  #         force = me->query_skill_mapped("force");
  #         if (! stringp(force))
  #         {
  #                 // 没有特殊内功了？
  #                 tell_object(me, "你一时难以定夺如何运用内力，只好先暂停疗伤。\n");
  #                 me->set_temp("pending/inspiring", 0);
  #                 me->set_short_desc(0);
  #                 message_vision("$N叹了口气，摇摇晃晃的站了起来。\n", me);
  #                 return 0;
  #         }
  # 
  #         if (me->query("eff_jing") < me->query("max_jing"))
  #         {
  #                 // 需要继续疗伤
  #                 if (me->query("neili") < 100)
  #                 {
  #                         tell_object(me, "你觉得真气不济，难以在经脉中继续运转振奋。\n");
  #                         me->set_temp("pending/healing", 0);
  #                         me->set_short_desc(0);
  #                         message_vision("$N叹了口气，摇摇晃晃的站了起来。\n", me);
  #                         return 0;
  #                 }
  # 
  #                 recover_points = 5 + (int)me->query_skill("force") / 6;
  #                 me->receive_curing("jing", recover_points);
  #                 me->add("neili", -100);
  #                 switch (random(10))
  #                 {
  #                 case 0:
  #                         tell_object(me, "你运用" + to_chinese(force) + "沿着"
  #                                     "诸大穴慢慢运转，振奋精神。\n");
  #                         break;
  #                 case 1:
  #                         tell_object(me, "你将内力纳入丹田，再上行冲顶，透泥宫"
  #                                     "，顿觉精神爽快。\n");
  #                         break;
  #                 case 2:
  #                         tell_object(me, "你运转内力，缓缓呼吸吐纳，额头上渗出"
  #                                         "点点汗珠，随即化作白雾蒸腾而起。\n");
  #                         break;
  #                 }
  # 
  #                 return 1;
  #         }
  # 
  #         // 恢复完毕
  #         me->set_temp("pending/exercise", 0);
  #         me->set_short_desc(0);
  #         message_vision(HIY "$N" HIY "缓缓睁开双目，精光四射，神清意爽。\n" NOR,
  #                        me);
  #         return 0;
  # }
  # 
  # // 停止疗伤
  # int halt_inspiring(object me)
  # {
  #         tell_object(me, "你将真气收回丹田，微微喘息，站了起来。\n");
  #         tell_room(environment(me), me->name() + "猛的吸一口气，突然站了起来。\n", me);
  #         me->set_temp("pending/inspiring", 0);
  #         me->set_short_desc(0);
  #         return 1;
  # }
end
