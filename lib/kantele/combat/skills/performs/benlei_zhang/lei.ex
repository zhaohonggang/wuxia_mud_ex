defmodule Kantele.Combat.Skills.Performs.BenleiZhang.Lei do
  @moduledoc """
  perform「雷霆万钧」（source benlei-zhang/lei.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：未持兵器 → 霹雳奔雷掌>=120 → 激发 strike 为霹雳奔雷掌 →
  准备 strike 招式 → 真气>=400 → 目标存活。
  命中判定 `random(strike) > parry/2`；命中时伤害
  `benlei_zhang*3 + random(benlei_zhang*5)`；
  命中扣 300 真气并忙乱 3，失手扣 200 真气并忙乱 2。

  差异（TODO(migrate)）：
  - `do_damage` 的第 5 参 `percent` 为护甲穿透比例，Elixir 侧 Vitals 未建模
    护甲，按同级迁移惯例只做 `Vitals.damage(:qi, damage)`；
  - `living(target)` 门槛未实现，由目标侧 `combat/perform-incoming` 兜底；
  - `me->query_temp("secondary_weapon")` 副兵器检查未实现。
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

  @perform_id "benlei-zhang/lei"

  @move_name "「雷霆万钧」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "benlei-zhang")
    # 命中判定基数 strike（.c: random(me->query_skill("strike"))）
    skill = Stats.skill(stats, "strike")
    # 伤害基数 benlei-zhang（.c: me->query_skill("benlei-zhang", 1)）
    damage = Stats.skill(stats, "benlei-zhang")

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: skill,
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
      Stats.skill(stats, "benlei-zhang") < 120 ->
        {:error, "你的霹雳奔雷掌还不够娴熟，难以施展#{@move_name}。\n"}

      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "benlei-zhang" ->
        {:error, "你没有激发霹雳奔雷掌，难以施展#{@move_name}。\n"}

      Stats.prepared_perform(stats, "strike") == nil or String.split(Stats.prepared_perform(stats, "strike"), "/") |> hd() != "benlei-zhang" ->
        {:error, "你没有准备霹雳奔雷掌，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 400 -> {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp check_weapon(character) do
    combat = character.meta.combat

    cond do
      Combat.weapon(combat) != nil -> {:error, "#{@move_name}只能空手施展。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # 无条件攻击方效果：仅前置广播。
    # C 的 -300/busy 3（命中）与 -200/busy 2（失手）均为条件消耗，
    # 由 do_resolve_incoming 通过 Performs.feedback 作用于攻击方。
    conn =
      Broadcast.publish(
        conn,
        "只见$N聚力于掌，平平推出，顿时掌风澎湃，掌力携着雷霆万钧之势猛贯向$n而去！\n",
        n1: character.name
      )

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「雷霆万钧」只能对战斗中的对手使用。\n"}
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
    # LPC: 命中判定用 random(me->query_skill("strike"))，伤害基数用
    #      me->query_skill("benlei-zhang", 1)
    skill = max(Map.get(data, :skill, 0), 1)
    base = max(Map.get(data, :damage, 0), 1)
    stats = character.meta.stats
    dp = div(Stats.skill(stats, "parry"), 2)
    hit = Engine.rand(rng, skill) > dp

    vitals =
      if hit do
        # C: damage = damage * 3 + random(damage * 5)
        dmg = base * 3 + Engine.rand(rng, base * 5)
        Vitals.damage(character.meta.vitals, :qi, dmg)
      else
        character.meta.vitals
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # 命中：add("neili", -300) + start_busy(3)；失手：add("neili", -200) + start_busy(2)
    {neili_cost, busy} = if hit, do: {300, 3}, else: {200, 2}

    Performs.feedback(attacker, neili_cost, busy)

    msg =
      if hit,
        do: "结果只听$n一声闷哼，$N掌劲穿胸而过，“哇”的喷出一大口鲜血。\n",
        else: "可是$p看破了$N的企图，躲开了这招杀着。\n"

    result = Messages.interpolate(msg, n1: attacker.name, n2: character.name)

    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}, {"neili", "-300"}], "assign_refs": [{"damage", "benlei-zhang"}], "busy_lines": ["me->start_busy(3);", "me->start_busy(2);"], "level_gates": [{"benlei-zhang", "120"}], "map_gates": [{"strike", "benlei-zhang"}], "prepared_gates": [{"strike", "benlei-zhang"}], "remote_damage": true, "resource_gates": [{"neili", "400"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define LEI "「" HIY "雷霆万钧" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/benlei-zhang/lei"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(LEI "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(LEI "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("benlei-zhang", 1) < 120)
  #                 return notify_fail("你的霹雳奔雷掌还不够娴熟，难以施展" LEI "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "benlei-zhang")
  #                 return notify_fail("你没有激发霹雳奔雷掌，难以施展" LEI "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "benlei-zhang")
  #                 return notify_fail("你没有准备霹雳奔雷掌，难以施展" LEI "。\n");
  # 
  #         if (me->query("neili") < 400)
  #                 return notify_fail("你现在真气不够，难以施展" LEI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "只见$N" HIY "聚力于掌，平平推出，顿时掌风澎湃，掌力"
  #               "携着雷霆万钧之势猛贯向$n" HIY "而去！\n" NOR;
  # 
  #         if (random(me->query_skill("strike")) > target->query_skill("parry") / 2)
  #         {
  #                 me->start_busy(3);
  # 
  #                 damage = me->query_skill("benlei-zhang", 1);
  #                 damage = damage * 3 + random(damage * 5);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 25,
  #                                            HIR "结果只听$n" HIR "一声闷哼，$N"
  #                                            HIR "掌劲穿胸而过，“哇”的喷出一大"
  #                                            "口鲜血。\n" NOR);
  #                 me->add("neili", -300);
  #         } else
  #         {
  #                 me->start_busy(2);
  #                 me->add("neili", -200);
  #                 msg += CYN "可是$p" CYN "看破了$N" CYN
  #                        "的企图，躲开了这招杀着。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
