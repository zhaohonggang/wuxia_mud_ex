defmodule Kantele.Combat.Skills.Performs.LingxiaoQuan.Jue do
  @moduledoc """
  perform「凌宵总诀」（source lingxiao-quan/jue.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 空手 → 凌霄拳法>=60 →
  内功>=100 → 真气>=100 → 激发 cuff 为凌霄拳法 → 准备凌霄拳法 → 目标存活。
  前置广播后命中判定 `random(cuff)` > 目标 `dodge/2`，命中扣 50 真气、
  攻击方忙乱 2、伤害 `cuff/2 + random(cuff/2)`（20% 外伤比例）；
  未命中扣 30 真气、攻击方忙乱 3。

  差异（TODO(migrate)）：
  - `COMBAT_D->do_damage(UNARMED_ATTACK, damage, 20, msg)` 折算为
    `Vitals.damage(:qi, damage) |> Vitals.wound(:qi, div(damage, 5))`；
  - JUE 宏（`"「" HIW "凌宵总诀" NOR "」"`）在 C 侧展开+去色后合并为单段
    `「凌宵总诀」`，E 侧用 @move_name 属性插值复现（注意起手式里是
    「凌霄总**决**」，门槛文案是「凌**宵**总诀」，两处字不同，照抄）。
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

  @perform_id "lingxiao-quan/jue"
  @move_name "「凌宵总诀」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "lingxiao-quan")
    ap = Stats.skill(stats, "cuff")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_mapped(character),
         :ok <- check_prepared(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
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

  # LPC: if (userp(me) && ! me->query("can_perform/lingxiao-quan/jue"))
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

  # LPC: if (objectp(weapon = me->query_temp("weapon")))
  defp check_weapon(combat) do
    if Combat.weapon(combat) == nil do
      :ok
    else
      {:error, "只有空手才能施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("lingxiao-quan", 1) < 60)
  #         if ((int)me->query_skill("force") < 100)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "lingxiao-quan") < 60 ->
        {:error, "你的凌霄拳法不够娴熟，难以施展#{@move_name}。\n"}

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

  # LPC: if (me->query_skill_mapped("cuff") != "lingxiao-quan")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "cuff") == "lingxiao-quan" do
      :ok
    else
      {:error, "你没有激发凌霄拳法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill_prepared("cuff") != "lingxiao-quan")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "cuff")

    if prepared == nil or hd(String.split(prepared, "/")) != "lingxiao-quan" do
      {:error, "你现在没有准备使用凌霄拳法，难以施展#{@move_name}。\n"}
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
    # LPC: msg = HIW "只听$N" HIW "一声断喝，双拳聚力齐发，一式「凌霄总决」携"
    #               "着风雷之势轰向$n" HIW "！\n" NOR;
    # 相邻字面量合并为单段。
    # me->start_busy(2) / me->start_busy(3) 与分支 neili 由目标侧 feedback 回执。
    conn =
      Broadcast.publish(
        conn,
        "只听$N一声断喝，双拳聚力齐发，一式「凌霄总决」携着风雷之势轰向$n！\n",
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
    ap = max(Map.get(data, :ap, 0), 1)
    stats = character.meta.stats
    dp = div(Stats.skill(stats, "dodge"), 2)

    # LPC: if (random(me->query_skill("cuff")) > target->query_skill("dodge") / 2)
    hit? = Engine.rand(rng, ap) > dp

    # LPC: me->start_busy(2);
    #      damage = me->query_skill("cuff");
    #      damage = damage / 2 + random(damage / 2);
    #      me->add("neili", -50);
    #      COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 20, msg);
    # else: me->start_busy(3); me->add("neili", -30);
    {vitals, msg, neili_cost, attacker_busy} =
      if hit? do
        damage = div(ap, 2) + Engine.rand(rng, div(ap, 2))

        v =
          character.meta.vitals
          |> Vitals.damage(:qi, damage)
          |> Vitals.wound(:qi, div(damage, 5))

        {v, hit_message(), 50, 2}
      else
        {character.meta.vitals, miss_message(), 30, 3}
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}

    Performs.feedback(attacker, neili_cost, attacker_busy)

    conn
    |> Broadcast.publish(msg, n1: attacker.name, n2: character.name)
    |> put_character(character)
  end

  # LPC: HIR "结果$p" HIR "闪避不及，被$P" HIR "一拳正中面门，顿时口喷鲜血，几乎昏厥！\n" NOR
  # （相邻字面量合并为单段）
  defp hit_message do
    "结果$p闪避不及，被$P一拳正中面门，顿时口喷鲜血，几乎昏厥！\n"
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
  # #define JUE "「" HIW "凌宵总诀" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         int damage;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/lingxiao-quan/jue"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(JUE "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(weapon = me->query_temp("weapon")))
  #                 return notify_fail("只有空手才能施展" JUE "。\n");
  # 
  #         if ((int)me->query_skill("lingxiao-quan", 1) < 60)
  #                 return notify_fail("你的凌霄拳法不够娴熟，难以施展" JUE "。\n");
  # 
  #         if ((int)me->query_skill("force") < 100)
  #                 return notify_fail("你的内功修为不够，难以施展" JUE "。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你现在真气不够，难以施展" JUE "。\n");
  # 
  #         if (me->query_skill_mapped("cuff") != "lingxiao-quan") 
  #                 return notify_fail("你没有激发凌霄拳法，难以施展" JUE "。\n");
  # 
  #         if (me->query_skill_prepared("cuff") != "lingxiao-quan")
  #                 return notify_fail("你现在没有准备使用凌霄拳法，难以施展" JUE "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "只听$N" HIW "一声断喝，双拳聚力齐发，一式「凌霄总决」携"
  #               "着风雷之势轰向$n" HIW "！\n" NOR;
  # 
  #         if (random(me->query_skill("cuff")) > target->query_skill("dodge") / 2)
  #         {
  #                 me->start_busy(2);
  #                 damage = me->query_skill("cuff");
  #                 damage = damage / 2 + random(damage / 2);
  #                 me->add("neili", -50);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 20,
  #                                            HIR "结果$p" HIR "闪避不及，被$P" HIR
  #                                            "一拳正中面门，顿时口喷鲜血，几乎昏厥"
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
