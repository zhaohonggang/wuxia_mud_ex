defmodule Kantele.Combat.Skills.Performs.BaishengQuan.Kai do
  @moduledoc """
  perform「混沌初开」（source baisheng-quan/kai.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：未持兵器 → 百胜神拳>=100 → 内功>=140 →
  激发 cuff 为百胜神拳 → 准备 cuff 招式 → 真气>=200 → 目标存活。
  命中判定 `random(cuff) > dodge/2`；命中时伤害
  `cuff/2 + random(cuff*2/3)`；命中扣 100 真气并忙乱 2，失手扣 60 真气并忙乱 3。

  差异（TODO(migrate)）：
  - `do_damage` 的第 5 参 `percent` 为护甲穿透比例，Elixir 侧 Vitals 未建模
    护甲，按同级迁移惯例只做 `Vitals.damage(:qi, damage)`；
  - 前置广播在 .c 中被 `NOR + HIR "混沌初开" NOR + WHT` 拆为三段字面量
    （`+` 阻止 C 侧 join_adjacent 合并），此处按原样拆为三段，运行时再
    `Enum.join` 合一；
  - `living(target)` 门槛未实现，由目标侧 `combat/perform-incoming` 兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "baisheng-quan/kai"

  @move_name "「混沌初开」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "baisheng-quan")
    damage = Stats.skill(stats, "cuff")

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          damage: damage,
          rng: rng
        }
      })

      apply_effect(conn, character)
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

  defp check_gates(character) do
    with :ok <- check_weapon(character),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "baisheng-quan") < 100 ->
        {:error, "你的百胜神拳不够娴熟，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "force") < 140 ->
        {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}

      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "cuff") != "baisheng-quan" ->
        {:error, "你没有激发百胜神拳，难以施展#{@move_name}。\n"}

      Stats.prepared_perform(stats, "cuff") == nil or String.split(Stats.prepared_perform(stats, "cuff"), "/") |> hd() != "baisheng-quan" ->
        {:error, "你没有准备百胜神拳，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 200 -> {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp check_weapon(character) do
    combat = character.meta.combat

    cond do
      Combat.weapon(combat) != nil -> {:error, "只有空手才能施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # 无条件攻击方效果：仅前置广播。
    # C 的 -100/busy 2（命中）与 -60/busy 3（失手）均为条件消耗，
    # 由 do_resolve_incoming 通过 Performs.feedback 作用于攻击方。
    # 前缀广播在 .c 中被颜色宏拆为三段字面量，此处按原样拆分、运行时再合一。
    msg =
      [
        "$N身子蓦的横移，两臂向后反钩，呼的一声朝$n攻去，正是「",
        "混沌初开",
        "」绝技。\n"
      ]
      |> Enum.join("")

    conn = Broadcast.publish(conn, msg, n1: character.name)

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「混沌初开」只能对战斗中的对手使用。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？", n1: attacker.name, n2: character.name)
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    skill = max(Map.get(data, :damage, 0), 1)
    stats = character.meta.stats
    dp = div(Stats.skill(stats, "dodge"), 2)
    # LPC: if (random(me->query_skill("cuff")) > target->query_skill("dodge") / 2)
    hit = Engine.rand(rng, skill) > dp

    vitals =
      if hit do
        # C: damage = damage / 2 + random(damage * 2 / 3)
        dmg = div(skill, 2) + Engine.rand(rng, div(skill * 2, 3))
        Vitals.damage(character.meta.vitals, :qi, dmg)
      else
        character.meta.vitals
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # 命中：add("neili", -100) + start_busy(2)；失手：add("neili", -60) + start_busy(3)
    {neili_cost, busy} = if hit, do: {100, 2}, else: {60, 3}

    Performs.feedback(attacker, neili_cost, busy)

    msg =
      if hit,
        do: "结果$n闪避不及，$N双拳正中$p头部两侧，顿时口喷鲜血，几欲昏厥。\n",
        else: "可是$p识破了$P这一招，斜斜一跃避开。\n"

    result = Messages.interpolate(msg, n1: attacker.name, n2: character.name)

    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-60"}], "assign_refs": [{"damage", "cuff"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "level_gates": [{"baisheng-quan", "100"}, {"force", "140"}], "map_gates": [{"cuff", "baisheng-quan"}], "prepared_gates": [{"cuff", "baisheng-quan"}], "remote_damage": true, "resource_gates": [{"neili", "200"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define KAI "「" WHT "混沌初开" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         int damage;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/baisheng-quan/kai"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(KAI "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(weapon = me->query_temp("weapon")))
  #                 return notify_fail("只有空手才能施展" KAI "。\n");
  # 
  #         if ((int)me->query_skill("baisheng-quan", 1) < 100)
  #                 return notify_fail("你的百胜神拳不够娴熟，难以施展" KAI "。\n");
  # 
  #         if ((int)me->query_skill("force") < 140)
  #                 return notify_fail("你的内功修为不够，难以施展" KAI "。\n");
  # 
  #         if (me->query_skill_mapped("cuff") != "baisheng-quan") 
  #                 return notify_fail("你没有激发百胜神拳，难以施展" KAI "。\n");
  # 
  #         if (me->query_skill_prepared("cuff") != "baisheng-quan")
  #                 return notify_fail("你没有准备百胜神拳，难以施展" KAI "。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不足，难以施展" KAI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = WHT "$N" WHT "身子蓦的横移，两臂向后反钩，呼的一声朝$n"
  #               WHT "攻去，正是「" NOR + HIR "混沌初开" NOR + WHT "」绝"
  #               "技。\n" NOR;
  # 
  #         if (random(me->query_skill("cuff")) > target->query_skill("dodge") / 2)
  #         {
  #                 me->start_busy(2);
  #                 damage = me->query_skill("cuff");
  #                 damage = damage / 2 + random(damage * 2 / 3);
  #                 me->add("neili", -100);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 50,
  #                                            HIR "结果$n" HIR "闪避不及，$N" HIR "双"
  #                                            "拳正中$p" HIR "头部两侧，顿时口喷鲜血"
  #                                            "，几欲昏厥。\n" NOR);
  #         } else
  #         {
  #                 me->start_busy(3);
  #                 me->add("neili", -60);
  #                 msg += CYN "可是$p" CYN "识破了$P"
  #                        CYN "这一招，斜斜一跃避开。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
