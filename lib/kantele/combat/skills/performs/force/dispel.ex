defmodule Kantele.Combat.Skills.Performs.Force.Dispel do
  @moduledoc """
  exert「dispel」（source force/dispel.c）

  排除异常症状。门槛：真气>=300（`write` + `return 1`，非 `notify_fail`）。
  随后按 `me == target` 分两路：
  - 自身：播「深吸一口气，又缓缓的吐了出来」+「你默运…开始排除身体中的异常症状」，
    扣真气 100；
  - 他人：目标非战斗中/非忙乱（各自文案），播「深吸一口气，将手掌粘到$n的背后」
    + 双方提示，扣真气 250。
  最后遍历目标异常：任一条件被驱散成功即播「你调息完毕，将内力收回丹田」
  （他人路另有目标提示与「将手掌从$n背后收了回来」）并按分支忙乱；
  全部失败（`still_ill`）播「你调息良久/你运功良久」失败文案；
  无异常则播「结果你没发现…有任何异常」文案。

  差异（TODO(migrate)）：
  - 真实运行为 `Kantele.Combat.Skills.Force.Dispel`（`skills/force_dispel.ex`）的
    `Performs.Simple` spec（仅自身路），本文件为并存的对齐副本（仅供文案对齐）；
  - 本引擎 exert 无目标参数，故以敌列表首个引用快照代理「他人」；无目标即走自身路；
  - 引擎未实现逐条件驱散抗性（LPC `dispel_condition`），`still_ill` 分支当前不可达，
    但按 `.c` 保留完整文案；
  - 敌列表仅存引用快照，`target->is_fighting()` / `is_busy()` 无据可查，保守放行；
  - `tell_object(target, ...)` 无跨进程等价物，以房间广播替代；
  - `to_chinese(force)` 折算为映射 id 原样（引擎未维护内功 id→中文名 表）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    if character.meta.vitals.neili < 300 do
      # LPC: if (me->query("neili") < 300) { write("你的内力不足，无法运满一个周天。\n"); return 1; }
      conn
      |> render(CommandView, "text", %{text: "你的内力不足，无法运满一个周天。\n"})
      |> assign(:prompt, false)
    else
      case other_target(character) do
        {:ok, target} -> other_dispel(conn, character, target)
        :error -> self_dispel(conn, character)
      end
    end
  end

  # 本引擎 exert 无目标参数，以敌列表首个非自身引用快照代理 `target`（见 moduledoc）。
  defp other_target(character) do
    case character.meta.combat.enemies do
      [%{id: id} = target | _] when id != character.id -> {:ok, target}
      _ -> :error
    end
  end

  # LPC: if (me == target) { ... me->add("neili", -100); }
  defp self_dispel(conn, character) do
    force_name = force_name(character)

    # LPC: message_vision(HIW "$N" HIW "深吸一口气，又缓缓的吐了出来。\n" NOR, me);
    conn =
      Broadcast.publish(conn, "$N深吸一口气，又缓缓的吐了出来。\n", n1: character.name)

    # LPC: tell_object(me, YEL "你默运" + force_name + YEL "，开始排除身体中的异常症状。\n" NOR);
    # C 侧被 `+ force_name +` 切成两段，E 侧同粒度。
    conn =
      render(conn, CommandView, "text", %{
        text: "你默运" <> force_name <> "，开始排除身体中的异常症状。\n"
      })

    # LPC: me->add("neili", -100);
    character = deduct_neili(character, 100)

    self_outcome(conn, character)
  end

  defp self_outcome(conn, character) do
    case dispel_outcome(conditions(character)) do
      :cleared ->
        # LPC: tell_object(me, WHT "你调息完毕，将内力收回丹" "田。\n" NOR);
        #      me->start_busy(1 + random(2));
        conn
        |> render(CommandView, "text", %{text: "你调息完毕，将内力收回丹田。\n"})
        |> assign(:prompt, false)
        |> put_character(start_busy(clear_conditions(character), 1 + :rand.uniform(2)))

      :still_ill ->
        # LPC: tell_object(me, MAG "你调息良久，没有一点效果。\n" NOR);
        #      message_vision(HIG "$N" HIG "脸色变了变，有些不" "太自然。\n" NOR, me);
        #      me->start_busy(3 + random(3));
        # 引擎未实现逐条件驱散抗性，该分支当前不可达（见 moduledoc）。
        conn
        |> render(CommandView, "text", %{text: "你调息良久，没有一点效果。\n"})
        |> Broadcast.publish("$N脸色变了变，有些不太自然。\n", n1: character.name)
        |> assign(:prompt, false)
        |> put_character(start_busy(character, 3 + :rand.uniform(3)))

      :no_anomaly ->
        # LPC: tell_object(me, "结果你没发现自己有任何异常。\n");
        #      message_vision(WHT "$N" WHT "眉角微微一动，随即恢" "复正常。\n" NOR, me);
        #      me->start_busy(1);
        conn
        |> render(CommandView, "text", %{text: "结果你没发现自己有任何异常。\n"})
        |> Broadcast.publish("$N眉角微微一动，随即恢复正常。\n", n1: character.name)
        |> assign(:prompt, false)
        |> put_character(start_busy(character, 1))
    end
  end

  # LPC: else { ... me->add("neili", -250); }
  defp other_dispel(conn, character, target) do
    force_name = force_name(character)
    target_name = Map.get(target, :name)

    with :ok <- check_not_fighting(character),
         :ok <- check_target_not_fighting(target),
         :ok <- check_target_not_busy(target) do
      # LPC: message_vision(HIW "$N" HIW "深吸一口气，将手掌粘到$n" HIW "的背后。\n" NOR, me, target);
      conn =
        Broadcast.publish(conn, "$N深吸一口气，将手掌粘到$n的背后。\n",
          n1: character.name,
          n2: target_name
        )

      # LPC: tell_object(me, YEL "你默运" + force_name + YEL "，开始帮助" + target->name() +
      #            YEL "排除身体中的异常症状。\n" NOR);
      # C 侧被 `+ force_name +` 与 `+ target->name() +` 切成三段，E 侧同粒度。
      conn =
        render(conn, CommandView, "text", %{
          text: "你默运" <> force_name <> "，开始帮助" <> target_name <> "排除身体中的异常症状。\n"
        })

      # LPC: tell_object(target, YEL + me->name() + YEL "正在运功帮助你排除身体中的异常症状。\n" NOR);
      # 无跨进程 tell_object，以房间广播替代（见 moduledoc）。
      conn =
        Broadcast.publish(conn, "$N正在运功帮助你排除身体中的异常症状。\n",
          n1: character.name,
          n2: target_name
        )

      # LPC: me->add("neili", -250);
      character = deduct_neili(character, 250)

      other_outcome(conn, character, target_name)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp other_outcome(conn, character, target_name) do
    case dispel_outcome(conditions(character)) do
      :cleared ->
        # LPC: tell_object(me, WHT "你调息完毕，将内力收回" "丹田。\n" NOR);
        #      tell_object(target, WHT "你觉得内息一畅，看来是" + me->name() + "收功了。\n");
        #      me->start_busy(2 + random(3)); target->start_busy(1 + random(2));
        #      message_vision(WHT "$N" WHT "将手掌从$n" WHT "背后" "收了回来。\n" NOR, me, target);
        conn
        |> render(CommandView, "text", %{text: "你调息完毕，将内力收回丹田。\n"})
        |> Broadcast.publish(
          "你觉得内息一畅，看来是" <> character.name <> "收功了。\n",
          n1: character.name,
          n2: target_name
        )
        |> Broadcast.publish("$N将手掌从$n背后收了回来。\n",
          n1: character.name,
          n2: target_name
        )
        |> assign(:prompt, false)
        |> put_character(start_busy(clear_conditions(character), 2 + :rand.uniform(3)))

      :still_ill ->
        # LPC: tell_object(me, MAG "你运功良久，没能发挥半点作用。\n" NOR);
        #      tell_object(target, MAG "你觉得内息一阵紊乱，说不出" "的难受。\n看来" + me->name() +
        #            "是不能给予你帮助了。\n" NOR);
        #      message_vision(HIG "$N将手掌从$n背后收了回来，脸色" "说不出的难看。\n" NOR, me, target);
        #      me->start_busy(6 + random(6)); target->start_busy(4 + random(4));
        # 引擎未实现逐条件驱散抗性，该分支当前不可达（见 moduledoc）。
        conn
        |> render(CommandView, "text", %{text: "你运功良久，没能发挥半点作用。\n"})
        |> Broadcast.publish(
          "你觉得内息一阵紊乱，说不出的难受。\n看来" <>
            character.name <> "是不能给予你帮助了。\n",
          n1: character.name,
          n2: target_name
        )
        |> Broadcast.publish("$N将手掌从$n背后收了回来，脸色说不出的难看。\n",
          n1: character.name,
          n2: target_name
        )
        |> assign(:prompt, false)
        |> put_character(start_busy(character, 6 + :rand.uniform(6)))

      :no_anomaly ->
        # LPC: tell_object(me, "结果你没发现" + target->name() + "有任何异常。\n");
        #      tell_object(target, "你觉得内息一畅，看来是" + me->name() +
        #            "收功了，大概你本来没有什" "么异常吧。\n");
        #      message_vision(WHT "$N" WHT "将手掌从$n" WHT "背后收了" "回来。\n" NOR, me, target);
        #      me->start_busy(2); target->start_busy(1);
        conn
        |> render(CommandView, "text", %{
          text: "结果你没发现" <> target_name <> "有任何异常。\n"
        })
        |> Broadcast.publish(
          "你觉得内息一畅，看来是" <> character.name <> "收功了，大概你本来没有什么异常吧。\n",
          n1: character.name,
          n2: target_name
        )
        |> Broadcast.publish("$N将手掌从$n背后收了回来。\n",
          n1: character.name,
          n2: target_name
        )
        |> assign(:prompt, false)
        |> put_character(start_busy(character, 2))
    end
  end

  # LPC: if (me->is_fighting(target)) { write("你们正打得热闹呢，还有心思干这个？\n"); return 1; }
  defp check_not_fighting(character) do
    if Combat.fighting?(character.meta.combat) do
      {:error, "你们正打得热闹呢，还有心思干这个？\n"}
    else
      :ok
    end
  end

  # LPC: if (target->is_fighting()) { write("对方正在打架，还是等他打完了再说吧。\n"); return 1; }
  # 引用快照无该状态，保守放行（见 moduledoc）。
  defp check_target_not_fighting(target) do
    if Map.get(target, :fighting) == true do
      {:error, "对方正在打架，还是等他打完了再说吧。\n"}
    else
      :ok
    end
  end

  # LPC: if (target->is_busy()) { write("对方现在正忙着呢，等他空了些再说吧。\n"); return 1; }
  # 引用快照无该状态，保守放行（见 moduledoc）。
  defp check_target_not_busy(target) do
    if Map.get(target, :busy, 0) > 0 do
      {:error, "对方现在正忙着呢，等他空了些再说吧。\n"}
    else
      :ok
    end
  end

  # LPC: still_ill = 0; conditions = target->query_condition();
  #      if (conditions) { for (...) switch(target->dispel_condition(me, cnds[i]))
  #        { case 0: continue; case -1: still_ill = 1; continue; } <成功分支：return 1> }
  #      if (still_ill) { <失败分支> } else { <无异常分支> }
  # 引擎以 `character.meta.conditions` 存异常，未实现逐条件驱散抗性，
  # 故：无异常 → :no_anomaly；有异常 → 视为全部驱散成功 :cleared。
  defp dispel_outcome(conds) do
    if map_size(conds) == 0, do: :no_anomaly, else: :cleared
  end

  defp conditions(character), do: Map.get(character.meta, :conditions) || %{}

  defp clear_conditions(character) do
    %{character | meta: Map.put(character.meta, :conditions, %{})}
  end

  defp start_busy(character, rounds) do
    combat = Combat.start_busy(character.meta.combat, rounds)
    %{character | meta: %{character.meta | combat: combat}}
  end

  defp deduct_neili(character, amount) do
    vitals = character.meta.vitals
    vitals = %{vitals | neili: max(vitals.neili - amount, 0)}
    %{character | meta: %{character.meta | vitals: vitals}}
  end

  defp force_name(character) do
    # LPC: force_name = to_chinese(me->query_skill_mapped("force"));
    to_chinese(Stats.mapped(character.meta.stats, "force"))
  end

  # LPC: to_chinese(name) —— 引擎未维护内功 id→中文名 表，保留 id 原样
  # （同 `sanku_shengong/dispel.ex` 的对齐副本约定）。
  defp to_chinese(name), do: name
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // dispel.c
  # 
  # #include <ansi.h>
  # 
  # int exert(object me, object target)
  # {
  #         int i;
  #         int still_ill;
  #         string force_name;
  #         string *cnds;
  #         mapping conditions;
  # 
  #         if (me->query("neili") < 300)
  #         {
  #                 write("你的内力不足，无法运满一个周天。\n");
  #                 return 1;
  #         }
  # 
  #         force_name = to_chinese(me->query_skill_mapped("force"));
  # 
  #         if (me == target)
  #         {
  #                 message_vision(HIW "$N" HIW "深吸一口气，又缓缓的吐了出来。\n" NOR, me);
  #                 tell_object(me, YEL "你默运" + force_name + YEL "，开始排除身"
  #                                 "体中的异常症状。\n" NOR);
  #                 me->add("neili", -100);
  #         } else
  #         {
  #             if (me->is_fighting(target))
  #             {
  #                 write("你们正打得热闹呢，还有心思干这个？\n");
  #                         return 1;
  #                 }
  # 
  #                 if (target->is_fighting())
  #                 {
  #                     write("对方正在打架，还是等他打完了再说吧。\n");
  #                         return 1;
  #                 }
  # 
  #                 if (target->is_busy())
  #                 {
  #                     write("对方现在正忙着呢，等他空了些再说吧。\n");
  #                         return 1;
  #                 }
  # 
  #                 message_vision(HIW "$N" HIW "深吸一口气，将手掌粘到$n"
  #                                HIW "的背后。\n" NOR, me, target);
  #                 tell_object(me, YEL "你默运" + force_name + YEL "，开"
  #                                 "始帮助" + target->name() + YEL "排除"
  #                                 "身体中的异常症状。\n" NOR);
  #                 tell_object(target, YEL + me->name() + YEL "正在运功帮"
  #                                     "助你排除身体中的异常症状。\n" NOR);
  #                 me->add("neili", -250);
  #         }
  # 
  #         still_ill = 0;
  #         conditions = target->query_condition();
  #         if (conditions)
  #         {
  #                 cnds = keys(conditions);
  #                 for (i = 0; i < sizeof(cnds); i++)
  #                 {
  #                         switch(target->dispel_condition(me, cnds[i]))
  #                         {
  #                         case 0:
  #                                 continue;
  #                         case -1:
  #                                 still_ill = 1;
  #                                 continue;
  #                         }
  # 
  #                         if (me == target)
  #                         {
  #                                 tell_object(me, WHT "你调息完毕，将内力收回丹"
  #                         "田。\n" NOR);
  #                                 me->start_busy(1 + random(2));
  #                         } else
  #                         {
  #                                 tell_object(me, WHT "你调息完毕，将内力收回"
  #                         "丹田。\n" NOR);
  #                                 tell_object(target, WHT "你觉得内息一畅，看来是" +
  #                                             me->name() + "收功了。\n");
  #                                 me->start_busy(2 + random(3));
  #                                 target->start_busy(1 + random(2));
  #                                 message_vision(WHT "$N" WHT "将手掌从$n" WHT "背后"
  #                                                "收了回来。\n" NOR, me, target);
  #                         }
  #                         return 1;
  #                 }
  #         }
  # 
  #         if (still_ill)
  #         {
  #                 if (me == target)
  #                 {
  #                         tell_object(me, MAG "你调息良久，没有一点效果。\n" NOR);
  #                         message_vision(HIG "$N" HIG "脸色变了变，有些不"
  #                        "太自然。\n" NOR, me);
  #                         me->start_busy(3 + random(3));
  #                 } else
  #                 {
  #                         tell_object(me, MAG "你运功良久，没能发挥半点作用。\n" NOR);
  #                         tell_object(target, MAG "你觉得内息一阵紊乱，说不出"
  #                             "的难受。\n看来" + me->name() +
  #                         "是不能给予你帮助了。\n" NOR);
  # 
  #                         message_vision(HIG "$N将手掌从$n背后收了回来，脸色"
  #                        "说不出的难看。\n" NOR, me, target);
  # 
  #                         me->start_busy(6 + random(6));
  #                         target->start_busy(4 + random(4));
  #                 }
  #         } else
  #         {
  #                 if (me == target)
  #                 {
  #                         tell_object(me, "结果你没发现自己有任何异常。\n");
  #                         message_vision(WHT "$N" WHT "眉角微微一动，随即恢"
  #                        "复正常。\n" NOR, me);
  #                         me->start_busy(1);
  #                 } else
  #                 {
  #                         tell_object(me, "结果你没发现" + target->name() +
  #                                    "有任何异常。\n");
  #                         tell_object(target, "你觉得内息一畅，看来是" +
  #                                     me->name() + "收功了，大概你本来没有什"
  #                     "么异常吧。\n");
  #                         message_vision(WHT "$N" WHT "将手掌从$n" WHT "背后收了"
  #                        "回来。\n" NOR, me, target);
  #                         me->start_busy(2);
  #                         target->start_busy(1);
  #                 }
  #         }
  # 
  #     return 1;
  # }
end
