defmodule Kantele.Combat.Skills.Performs.HuashanZhang.Piao do
  @moduledoc """
  perform「飞絮飘渺」（source huashan-zhang/piao.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 目标非忙 →
  华山掌法>=30 → 准备 strike 为华山掌法 → 真气>=60 → 目标存活。
  攻击方恒扣 30 真气；命中判定 `random(cuff)` vs 目标 `force/2`：
  命中则广播「无法施招」并令目标忙乱 `strike/25 + 2`；
  未命中则广播「看破虚实」并令攻击方忙乱 1。

  差异（TODO(migrate)）：
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - `target->is_busy()` 取引用快照 meta 的 `combat.busy`（缺 meta 时按非忙处理）；
  - 攻击方忙乱只在失手分支，经 `Performs.feedback/3` 由目标侧回传。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "huashan-zhang/piao"
  @move_name "「飞絮飘渺」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "huashan-zhang")
    cuff = Stats.skill(stats, "cuff")
    strike = Stats.skill(stats, "strike")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_target_busy(target),
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
          level: lvl,
          skill: lvl,
          cuff: cuff,
          strike: strike,
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

  # LPC: if (userp(me) && ! me->query("can_perform/huashan-zhang/piao"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (target->is_busy()) return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
  defp check_target_busy(target) do
    if target_busy?(target) do
      {:error, target.name <> "目前正自顾不暇，放胆攻击吧！\n"}
    else
      :ok
    end
  end

  defp target_busy?(target) do
    case get_in(target, [:meta, :combat, :busy]) do
      busy when is_integer(busy) -> busy > 0
      _ -> false
    end
  end

  # LPC: if ((int)me->query_skill("huashan-zhang", 1) < 30)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "huashan-zhang") < 30 do
      {:error, "你的华山掌法不够娴熟，不会使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "huashan-zhang")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "strike")

    if prepared == nil or prepared |> String.split("/") |> hd() != "huashan-zhang" do
      {:error, "你没有准备使用华山掌法，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili") < 60)
  defp check_resources(character) do
    if character.meta.vitals.neili < 60 do
      {:error, "你现在真气不够，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活，
  # 由目标侧 combat/perform-incoming 的死亡检查兜底。
  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIM "\n猛然间$N" HIM "双掌不断拍向$n" HIM "出，风声呼呼，攻到途中忽又左"
    #           "手虚出右手作势欲发，虚虚实实，飘渺不定，正是华山绝招「" HIG "飞絮飘渺" HIM
    #           "」。 顷刻剑$n" HIM "已被$N" HIM "掌风笼罩。\n" NOR;
    #      me->add("neili", -30);
    #      命中/失手与忙乱均在目标侧结算（dp 需目标 force）。
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 30}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn
    |> Broadcast.publish(
      "\n猛然间$N双掌不断拍向$n出，风声呼呼，攻到途中忽又左手虚出右手作势欲发，虚虚实实，飘渺不定，正是华山绝招#{@move_name}。 顷刻剑$n已被$N掌风笼罩。\n",
      n1: character.name,
      n2: target.name
    )
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    cuff = max(Map.get(data, :cuff, 0), 1)
    strike = Map.get(data, :strike, 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(me->query_skill("cuff")) > (int)target->query_skill("force") / 2)
    dp = div(Stats.skill(stats, "force"), 2)

    if Engine.rand(rng, cuff) > dp do
      # LPC: msg += HIR "结果$p" HIR "一时无法辨别其中虚实，竟无法施招。\n" NOR;
      #      target->start_busy((int)me->query_skill("strike") / 25 + 2);
      combat = Combat.start_busy(character.meta.combat, div(strike, 25) + 2)
      character = %{character | meta: %{character.meta | combat: combat}}

      conn
      |> Broadcast.publish(
        Messages.interpolate("结果$p一时无法辨别其中虚实，竟无法施招。\n", bindings)
      )
      |> put_character(character)
    else
      # LPC: msg += CYN "可是$n" CYN "看破其中虚实，更不理会。\n" NOR;
      #      me->start_busy(1);
      Performs.feedback(attacker, 0, 1)

      conn
      |> Broadcast.publish(
        Messages.interpolate("可是$n看破其中虚实，更不理会。\n", bindings)
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // MODIFY BY RCWIZ 2003
  # 
  # #include <ansi.h>
  # 
  # #define FEI "「" HIG "飞絮飘渺" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     // object weapon;
  #     string msg;
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/huashan-zhang/piao"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail(FEI "只能对战斗中的对手使用。\n");
  # 
  #     if (target->is_busy())
  #         return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
  # 
  #     if ((int)me->query_skill("huashan-zhang", 1) < 30)
  #         return notify_fail("你的华山掌法不够娴熟，不会使用" FEI  "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "huashan-zhang")
  #                 return notify_fail("你没有准备使用华山掌法，无法施展" FEI  "。\n");
  # 
  #         if (me->query("neili") < 60)
  #                 return notify_fail("你现在真气不够，无法施展" FEI  "。\n");
  # 
  #         if (! living(target))
  #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIM "\n猛然间$N" HIM "双掌不断拍向$n" HIM "出，风声呼呼，攻到途中忽又左"
  #               "手虚出右手作势欲发，虚虚实实，飘渺不定，正是华山绝招「" HIG  "飞絮飘渺" HIM
  #               "」。 顷刻剑$n" HIM "已被$N" HIM "掌风笼罩。\n" NOR;
  # 
  #         me->add("neili", -30);
  #     if (random(me->query_skill("cuff")) > (int)target->query_skill("force") / 2)
  #         {
  #         msg += HIR "结果$p" HIR "一时无法辨别其中虚实，竟无法施招。\n" NOR;
  #         target->start_busy((int)me->query_skill("strike") / 25 + 2);
  #     } else
  #         {
  #         msg += CYN "可是$n" CYN "看破其中虚实，更不理会。\n" NOR;
  #         me->start_busy(1);
  #     }
  #     message_sort(msg, me, target);
  # 
  #     return 1;
  # }
end
