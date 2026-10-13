defmodule Kantele.Combat.Skills.Performs.LanhuaShou.Fu do
  @moduledoc """
  perform「兰花拂穴」（source lanhua-shou/fu.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 未持兵器 → 对方未忙乱 →
  兰花拂穴手>=120 → 经络学>=120 → 激发 hand 为兰花拂穴手 → 准备兰花拂穴手 →
  真气>=100 → 目标存活。
  命中判定 `hand/2 + random(hand)` > 目标 `parry/2`；命中则点穴令目标忙乱
  `hand/30+2`，攻击方扣 100 真气并忙乱 1；未命中攻击方忙乱 2。无伤害。

  差异（TODO(migrate)）：
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧 perform-incoming 的
    死亡检查兜底；`target->is_busy()` 门槛读敌人引用快照。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs

  @perform_id "lanhua-shou/fu"
  @move_name "「兰花拂穴」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(character),
         :ok <- check_target_busy(target),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_prepared(character),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: Stats.skill(stats, "lanhua-shou"),
          skill: Stats.skill(stats, "lanhua-shou"),
          # LPC: ap = me->query_skill("hand")
          ap: Stats.skill(stats, "hand"),
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

  # LPC: if (objectp(me->query_temp("weapon")))
  defp check_weapon(character) do
    if Combat.weapon(character.meta.combat) != nil do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: if (target->is_busy())
  #         return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  defp check_target_busy(target) do
    if busy?(target) do
      {:error, "#{target.name}目前正自顾不暇，放胆攻击吧。\n"}
    else
      :ok
    end
  end

  defp busy?(%{meta: %{combat: %{busy: busy}}}) when is_number(busy), do: busy > 0
  defp busy?(_), do: false

  # LPC: if ((int)me->query_skill("lanhua-shou", 1) < 120)
  #         if ((int)me->query_skill("jingluo-xue", 1) < 120)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "lanhua-shou") < 120 ->
        {:error, "你兰花拂穴手不够娴熟，难以施展#{@move_name}。\n"}
      Stats.skill(stats, "jingluo-xue") < 120 ->
        {:error, "你对经络学的了解不够，难以施展#{@move_name}。\n"}
      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_mapped("hand") != "lanhua-shou")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "hand") == "lanhua-shou" do
      :ok
    else
      {:error, "你没有激发兰花拂穴手，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill_prepared("hand") != "lanhua-shou")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "hand")

    if prepared == nil or hd(String.split(prepared, "/")) != "lanhua-shou" do
      {:error, "你没有准备兰花拂穴手，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 100)
  defp check_resources(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你现在真气不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target))
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
    # LPC: msg = HIC "$N" HIC "反手轻轻伸出三指，…轻点$n" HIC "胁下要穴。\n";
    #      message_combatd(msg, me, target);
    # 内力消耗在命中分支（me->add("neili", -100)），由目标侧 feedback 回执。
    conn
    |> Broadcast.publish(
      "$N反手轻轻伸出三指，婉转如一朵盛开的兰花，轻点$n胁下要穴。\n",
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
    ap = max(Map.get(data, :ap, 0), 1)
    # LPC: dp = target->query_skill("parry") / 2;
    dp = div(Stats.skill(character.meta.stats, "parry"), 2)

    # LPC: if (ap / 2 + random(ap) > dp) 命中：点穴
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # target->start_busy(ap / 30 + 2); me->add("neili", -100); me->start_busy(1);
      combat = Combat.start_busy(character.meta.combat, div(ap, 30) + 2)
      character = %{character | meta: %{character.meta | combat: combat}}

      Performs.feedback(attacker, 100, 1)

      conn
      |> Broadcast.publish(
        "$p只觉胁下一麻，已被$P点个正着，顿时全身酸软，呆立当场。\n",
        n1: attacker.name,
        n2: character.name
      )
      |> put_character(character)
    else
      # me->start_busy(2);
      Performs.feedback(attacker, 0, 2)

      conn
      |> Broadcast.publish(
        "可是$p看破了$P的企图，轻轻一跃，跳了开去。\n",
        n1: attacker.name,
        n2: character.name
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define FU "「" HIC "兰花拂穴" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/lanhua-shou/fu"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(FU "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(me->query_temp("weapon")))
  #                 return notify_fail(FU "只能空手施展。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #         if ((int)me->query_skill("lanhua-shou", 1) < 120)
  #                 return notify_fail("你兰花拂穴手不够娴熟，难以施展" FU "。\n");
  # 
  #         if ((int)me->query_skill("jingluo-xue", 1) < 120)
  #                 return notify_fail("你对经络学的了解不够，难以施展" FU "。\n");
  # 
  #         if (me->query_skill_mapped("hand") != "lanhua-shou")
  #                 return notify_fail("你没有激发兰花拂穴手，难以施展" FU "。\n");
  # 
  #         if (me->query_skill_prepared("hand") != "lanhua-shou")
  #                 return notify_fail("你没有准备兰花拂穴手，难以施展" FU "。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你现在真气不足，难以施展" FU "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIC "$N" HIC "反手轻轻伸出三指，婉转如一朵盛开的兰花，轻点$n"
  #               HIC "胁下要穴。\n";
  # 
  #         ap = me->query_skill("hand");
  #         dp = target->query_skill("parry") / 2;
  #     if (ap / 2 + random(ap) > dp)
  #     {
  #         msg +=  HIR "$p" HIR "只觉胁下一麻，已被$P"
  #                         HIR "点个正着，顿时全身酸软，呆立当场。\n" NOR;
  #         target->start_busy(ap / 30 + 2);
  #         me->add("neili", -100);
  #                 me->start_busy(1);
  #     } else
  #     {
  #         msg += CYN "可是$p" CYN "看破了$P" CYN
  #                "的企图，轻轻一跃，跳了开去。\n" NOR;
  #         me->start_busy(2);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
