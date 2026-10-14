defmodule Kantele.Combat.Skills.Performs.PiaofengQuan.Juan do
  @moduledoc """
  perform「卷字决」（对照 `kungfu/skill/piaofeng-quan/juan.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 飘风拳法>=30 →
  准备 cuff 为飘风拳法 → 真气>=80 → 目标存活；**目标不忙乱**的门槛在目标侧
  结算（见下）。
  起手广播后由目标侧判定 `random(掌法) > 目标内功/2`：命中则目标忙乱
  `掌法/22`；未命中则攻击方忙乱 1。两种情况攻击方均扣 40 真气
  （`.c` 中该消耗位于目标忙乱门槛之后、命中分支之外）。

  差异（TODO(migrate)）：
  - **目标忙乱门槛**（`target->is_busy()`，文案 `target->name() + "目前正自顾不暇，
    放胆攻击吧！\\n"`）在攻击方不可得（`combat.enemies` 仅存
    `%{id,pid,name,room_id}` 快照），故移到目标侧 `resolve_incoming` 判定，
    文案以 `$n` 绑定目标名（同 `miaojia_jian/zhai.ex`）；`.c` 中该门槛先于攻击方
    熟练度门槛，此处次序相反；
  - `me->add("neili", -40)` 在 `.c` 里位于目标忙乱门槛之后，因门槛移到目标侧，
    该消耗一并随门槛在目标侧结算，经 `Performs.feedback/3` 回执
    （命中 `busy: 0` 不改攻击方忙乱，未命中 `busy: 1`）；
  - `.c` 的 `message_sort(msg, me, target)`（按感知排序）降级为房间广播；
  - 起手文案按 `.c` 原样保留 `笼罩， 正是` 中的空格；
  - `!living(target)` 门槛在攻击方恒判存活（无 meta 可查），其文案放在攻击方
    `check_target_alive/1`，由目标侧死亡检查兜底（`resolve_incoming` 的 dead 分支不重复文案）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs

  @perform_id "piaofeng-quan/juan"
  @move_name "「卷字决」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: random(me->query_skill("cuff")) —— 分支判定用掌法（cuff）等级。
    ap = Stats.skill(stats, "cuff")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_levels(character),
         :ok <- check_prepared(character),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          ap: ap,
          rng: rng
        }
      })

      apply_effect(conn, character, target)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/piaofeng-quan/juan"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_skill("piaofeng-quan", 1) < 30)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "piaofeng-quan") < 30 do
      {:error, "你的飘风拳法不够娴熟，不会使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("cuff") != "piaofeng-quan")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "cuff")

    if prepared != nil and hd(String.split(prepared, "/")) == "piaofeng-quan" do
      :ok
    else
      {:error, "你没有准备使用飘风拳法，无法施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query("neili") < 80)
  defp check_resources(character) do
    if character.meta.vitals.neili < 80 do
      {:error, "你现在真气不够，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活，
  # 由目标侧 combat/perform-incoming 的死亡检查兜底。
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIC "\n只见$N" HIC "右拳直出，中途猛地一转，突然发力，身法"
    #            "陡快，将$n" HIC "笼罩， 正是飘风拳法绝招「" HIW "卷字决" HIC "」。\n" NOR;
    #      message_sort(msg, me, target);
    #      me->add("neili", -40);   // 位于目标忙乱门槛之后，随门槛在目标侧结算
    Broadcast.publish(
      conn,
      "\n只见$N右拳直出，中途猛地一转，突然发力，身法陡快，将$n笼罩， 正是飘风拳法绝招「卷字决」。\n",
      n1: character.name,
      n2: target.name
    )
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  # LPC: if (target->is_busy()) return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
  # 目标忙乱状态只在目标侧可见，故死亡/忙乱门槛在 resolve_incoming 结算（同 miaojia_jian/zhai.ex）。
  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    cond do
      character.meta.combat.dead ->
        conn

      Combat.busy?(character.meta.combat) ->
        Broadcast.publish(conn, "$n目前正自顾不暇，放胆攻击吧！\n",
          n1: attacker.name,
          n2: character.name
        )

      true ->
        do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)

    # LPC: (int)target->query_skill("force") / 2
    force = Stats.skill(character.meta.stats, "force")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(me->query_skill("cuff")) > (int)target->query_skill("force") / 2)
    #      { msg += HIR "结果$p" HIR "运力招架，一时却觉得"
    #                     "内力不济，被$P" HIR "抢住手腕一拉，顿时立足"
    #                     "不稳，滴溜溜打了两个圈子。\n" NOR;
    #        target->start_busy((int)me->query_skill("cuff") / 22); }
    #      else
    #      { msg += CYN "可是$p" CYN "奋力一架，硬生生格开了$P"
    #                     CYN "这一拳。\n" NOR;
    #        me->start_busy(1); }
    if Engine.rand(rng, ap) > div(force, 2) do
      # LPC: me->add("neili", -40);（无条件，位于忙乱门槛之后）
      Performs.feedback(attacker, 40, 0)

      # LPC: target->start_busy((int)me->query_skill("cuff") / 22);
      combat = Combat.start_busy(character.meta.combat, div(ap, 22))

      conn =
        Broadcast.publish(
          conn,
          "结果$p运力招架，一时却觉得内力不济，被$P抢住手腕一拉，顿时立足不稳，滴溜溜打了两个圈子。\n",
          bindings
        )

      character = %{character | meta: %{character.meta | combat: combat}}

      conn
      |> put_character(character)
    else
      # LPC: me->add("neili", -40);  me->start_busy(1);
      Performs.feedback(attacker, 40, 1)

      Broadcast.publish(
        conn,
        "可是$p奋力一架，硬生生格开了$P这一拳。\n",
        bindings
      )
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # #define JUAN "「" HIW "卷字决" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  # //    object weapon;
  #     string msg;
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/piaofeng-quan/juan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail(JUAN "只能对战斗中的对手使用。\n");
  # 
  #     if (target->is_busy())
  #         return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
  # 
  #     if ((int)me->query_skill("piaofeng-quan", 1) < 30)
  #         return notify_fail("你的飘风拳法不够娴熟，不会使用" JUAN "。\n");
  # 
  #         if (me->query_skill_prepared("cuff") != "piaofeng-quan")
  #                 return notify_fail("你没有准备使用飘风拳法，无法施展" JUAN "。\n");
  # 
  #         if (me->query("neili") < 80)
  #                 return notify_fail("你现在真气不够，无法施展" JUAN "。\n");
  # 
  #         if (! living(target))
  #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIC "\n只见$N" HIC "右拳直出，中途猛地一转，突然发力，身法"
  #               "陡快，将$n" HIC "笼罩， 正是飘风拳法绝招「" HIW "卷字决" HIC "」。\n" NOR;
  # 
  #         me->add("neili", -40);
  #     if (random(me->query_skill("cuff")) > (int)target->query_skill("force") / 2)
  #         {
  #         msg += HIR "结果$p" HIR "运力招架，一时却觉得"
  #                        "内力不济，被$P" HIR "抢住手腕一拉，顿时立足"
  #                        "不稳，滴溜溜打了两个圈子。\n" NOR;
  #         target->start_busy((int)me->query_skill("cuff") / 22);
  #     } else
  #         {
  #         msg += CYN "可是$p" CYN "奋力一架，硬生生格开了$P"
  #                        CYN "这一拳。\n" NOR;
  #         me->start_busy(1);
  #     }
  #     message_sort(msg, me, target);
  # 
  #     return 1;
  # }
end
