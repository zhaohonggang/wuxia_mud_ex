defmodule Kantele.Combat.Skills.Performs.LiuheZhang.Tan do
  @moduledoc """
  perform「乌龙探海」（source liuhe-zhang/tan.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 空手 → 六合掌法>=60 →
  内功>=100 → 真气>=100 → 激发 strike 为六合掌法 → 准备六合掌法 → 目标存活。
  起手广播为单段合并文案；命中判定 `random(strike) > dodge/2`，命中伤害
  `strike/2 + random(strike/3)`（20% 外伤比例）、扣 50 真气、忙乱 2；
  未命中扣 30 真气、忙乱 3。

  差异（TODO(migrate)）：
  - `COMBAT_D->do_damage(UNARMED_ATTACK, damage, 20, msg)` 折算为
    `Vitals.damage(:qi, damage)` + `Vitals.wound(:qi, div(damage*20, 100))`；
  - 分支 neili/busy 由目标侧 `combat/perform-feedback` 回执；
  - TAN 宏展开+去色后合并为单段「乌龙探海」，E 侧用 @move_name 属性插值复现；
  - secondary_weapon 槽位未建模，空手门槛只查主武器槽；
  - `living(target)` 门槛由目标侧 combat/perform-incoming 的死亡检查兜底。
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
  alias Kantele.Combat.Performs

  @perform_id "liuhe-zhang/tan"
  @move_name "「乌龙探海」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "liuhe-zhang")
    strike = Stats.skill(stats, "strike")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_mapped(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
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

  # LPC: if (userp(me) && ! me->query("can_perform/liuhe-zhang/tan"))
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

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #      （secondary_weapon 槽位未建模，只查主武器槽）
  defp check_weapon(combat) do
    if Combat.weapon(combat) != nil do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: liuhe-zhang < 60 / force < 100
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "liuhe-zhang") < 60 ->
        {:error, "你的六合掌法不够娴熟，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 100)
  defp check_resources(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: query_skill_mapped("strike") != "liuhe-zhang"
  #      / query_skill_prepared("strike") != "liuhe-zhang"
  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "liuhe-zhang" ->
        {:error, "你没有激发六合掌法，难以施展#{@move_name}。\n"}

      Stats.prepared_perform(stats, "strike") == nil or
          hd(String.split(Stats.prepared_perform(stats, "strike"), "/")) != "liuhe-zhang" ->
        {:error, "你没有准备六合掌法，难以施展#{@move_name}。\n"}

      true ->
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
    # LPC: msg = HIC "$N" HIC "履步沉身，双肩蓄力，陡然间单掌飕的探出，一招「乌龙"
    #               "探海势」向$n" HIC "胸前拍落！\n" NOR;
    # （相邻字面量在 C 侧合并为单段）
    # 分支 neili/busy 由目标侧 feedback 回执。
    conn =
      Broadcast.publish(
        conn,
        "$N履步沉身，双肩蓄力，陡然间单掌飕的探出，一招「乌龙探海势」向$n胸前拍落！\n",
        n1: character.name,
        n2: target.name
      )

    conn
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
    strike = max(Map.get(data, :strike, 0), 1)
    dp = Stats.skill(character.meta.stats, "dodge")

    # LPC: if (random(me->query_skill("strike")) > target->query_skill("dodge") / 2)
    hit? = Engine.rand(rng, strike) > div(dp, 2)

    {vitals, neili_cost, attacker_busy} =
      if hit? do
        # LPC: damage = strike; damage = damage / 2 + random(damage / 3);
        #      do_damage(UNARMED_ATTACK, damage, 20, msg); neili -50; busy 2;
        damage = div(strike, 2) + Engine.rand(rng, div(strike, 3))

        v =
          character.meta.vitals
          |> Vitals.damage(:qi, damage)
          |> Vitals.wound(:qi, div(damage * 20, 100))

        {v, 50, 2}
      else
        # LPC: neili -30; busy 3;
        {character.meta.vitals, 30, 3}
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}

    Performs.feedback(attacker, neili_cost, attacker_busy)

    msg = if hit?, do: hit_message(), else: miss_message()

    conn
    |> Broadcast.publish(msg, n1: attacker.name, n2: character.name)
    |> put_character(character)
  end

  # LPC: HIR "结果$p" HIR "闪避不及，被$P" HIR "一掌拍在胸口，顿时口喷鲜血，几乎昏厥" "！\n"
  # （相邻字面量合并为单段）
  defp hit_message do
    "结果$p闪避不及，被$P一掌拍在胸口，顿时口喷鲜血，几乎昏厥！\n"
  end

  # LPC: CYN "可是$p" CYN "识破了$P" CYN "这一招，斜斜一跃避开。\n" NOR
  # （相邻字面量合并为单段）
  defp miss_message do
    "可是$p识破了$P这一招，斜斜一跃避开。\n"
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define TAN "「" HIC "乌龙探海" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  # //      object weapon;
  #         int damage;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/liuhe-zhang/tan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(TAN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(TAN "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("liuhe-zhang", 1) < 60)
  #                 return notify_fail("你的六合掌法不够娴熟，难以施展" TAN "。\n");
  # 
  #         if ((int)me->query_skill("force") < 100)
  #                 return notify_fail("你的内功修为不够，难以施展" TAN "。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你现在真气不够，难以施展" TAN "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "liuhe-zhang") 
  #                 return notify_fail("你没有激发六合掌法，难以施展" TAN "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "liuhe-zhang")
  #                 return notify_fail("你没有准备六合掌法，难以施展" TAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIC "$N" HIC "履步沉身，双肩蓄力，陡然间单掌飕的探出，一招「乌龙"
  #               "探海势」向$n" HIC "胸前拍落！\n" NOR;
  # 
  #         if (random(me->query_skill("strike")) > target->query_skill("dodge") / 2)
  #         {
  #                 me->start_busy(2);
  #                 damage = me->query_skill("strike");
  #                 damage = damage / 2 + random(damage / 3);
  #                 me->add("neili", -50);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 20,
  #                                            HIR "结果$p" HIR "闪避不及，被$P" HIR
  #                                            "一掌拍在胸口，顿时口喷鲜血，几乎昏厥"
  #                                            "！\n" NOR);
  #         } else
  #         {
  #                 me->start_busy(3);
  #                 me->add("neili", -30);
  #                 msg += CYN "可是$p" CYN "识破了$P"
  #                        CYN "这一招，斜斜一跃避开。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
