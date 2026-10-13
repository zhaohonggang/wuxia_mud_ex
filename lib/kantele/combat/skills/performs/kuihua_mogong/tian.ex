defmodule Kantele.Combat.Skills.Performs.KuihuaMogong.Tian do
  @moduledoc """
  perform「无法无天」（source kuihua-mogong/tian.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 内力>=340 →
  葵花魔功>=220 → 激发 force 为葵花魔功 → 内力上限>=3400 →
  武器须为剑/针（空手则须准备 unarmed 为葵花魔功）→ 有武器则须激发 sword、
  空手则须准备 unarmed 为葵花魔功 → 目标存活。
  连击数 i = 6 + random(5)（固定 6~10 连），攻击方扣 i*30 内力。
  命中判定：lvl*11/20 + random(lvl) > 目标 dodge（决定分支文案）。

  差异（TODO(migrate)）：
  - LPC 的 i 次 `COMBAT_D->do_attack(me, target, weapon, 0)`（完整 AP/DP/招架/
    伤害管线）折算为每击 `lvl/15` 基础伤害 + 命中判定 `lvl/2 + random(lvl)` vs
    目标 dodge（同 chongyang-shenzhang/lian、duanjia-sword/jue）；
  - LPC 命中时 `add_temp("apply/attack|damage|unarmed_damage", lvl/4)` 只在连击
    期间生效、连击后即移除；本版连击在目标侧折算，加成值 `count` 随事件数据
    传给目标侧直接折入每击伤害，不落在攻击方临时属性上；
  - `living(target)` 门槛在攻击方无 meta 可查时恒判存活，由目标侧
    `combat/perform-incoming` 的死亡检查兜底。
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
  alias Kantele.Character.Vitals

  @perform_id "kuihua-mogong/tian"
  @move_name "「无法无天」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "kuihua-mogong")
    hits = 6 + Engine.rand(rng, 5)

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_neili(character),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_max_neili(character),
         :ok <- check_weapon_type(combat, character),
         :ok <- check_weapon_mapped(combat, character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          # LPC: count = kuihua / 4（命中时 apply/* 临时加成，折入每击伤害）
          count: div(lvl, 4),
          hits: hits,
          rng: rng
        }
      })

      apply_effect(conn, character, target, hits)
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

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query("neili") < 340)
  defp check_neili(character) do
    if character.meta.vitals.neili < 340 do
      {:error, "你的真气不够，无法施展#{@move_name}！\n"}
    else
      :ok
    end
  end

  # LPC: if ((lvl = me->query_skill("kuihua-mogong", 1)) < 220)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "kuihua-mogong") < 220 do
      {:error, "你的葵花魔功火候不够，无法施展#{@move_name}！\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("force") != "kuihua-mogong")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "force") != "kuihua-mogong" do
      {:error, "你还没有激发葵花魔功为内功，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("max_neili") < 3400)
  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 3400 do
      {:error, "你的内力修为不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (weapon = me->query_temp("weapon"))
  #          { 若武器非剑/针则「你手里拿的不是剑，怎么施展…？」 }
  #          else { 若未准备 unarmed 为葵花魔功则「你并没有准备使用葵花魔功，如何施展…？」 }
  defp check_weapon_type(combat, character) do
    case Combat.weapon(combat) do
      nil ->
        prepared = Stats.prepared_perform(character.meta.stats, "unarmed")

        if prepared == nil or hd(String.split(prepared, "/")) != "kuihua-mogong" do
          {:error, "你并没有准备使用葵花魔功，如何施展#{@move_name}？\n"}
        else
          :ok
        end

      %{skill_type: st} when st == "sword" or st == "pin" ->
        :ok

      _ ->
        {:error, "你手里拿的不是剑，怎么施展#{@move_name}？\n"}
    end
  end

  # LPC: if (weapon && me->query_skill_mapped("sword") != "kuihua-mogong")
  #          return notify_fail("你没有准备使用葵花魔功，难以施展…。\n");
  #     if (! weapon && me->query_skill_prepared("unarmed") != "kuihua-mogong")
  #          return notify_fail("你没有准备使用葵花魔功，难以施展…。\n");
  defp check_weapon_mapped(combat, character) do
    case Combat.weapon(combat) do
      nil ->
        prepared = Stats.prepared_perform(character.meta.stats, "unarmed")

        if prepared == nil or hd(String.split(prepared, "/")) != "kuihua-mogong" do
          {:error, "你没有准备使用葵花魔功，难以施展#{@move_name}。\n"}
        else
          :ok
        end

      _ ->
        if Stats.mapped(character.meta.stats, "sword") != "kuihua-mogong" do
          {:error, "你没有准备使用葵花魔功，难以施展#{@move_name}。\n"}
        else
          :ok
        end
    end
  end

  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  # LPC: msg = HIR "$N" HIR "默运葵花魔功，身形变得奇快无比，接连从不同的方位向$n"
  #               HIR "攻出数招！\n" NOR;
  #      message_combatd(msg, me, target);  me->add("neili", -i * 30);
  # （C 侧各段字面量仅由颜色宏/空白分隔，合并为同一条文案）
  # 连击伤害/busy 在目标侧结算。
  defp apply_effect(conn, character, target, hits) do
    vitals = %{character.meta.vitals | neili: max(character.meta.vitals.neili - hits * 30, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn
    |> Broadcast.publish(
      Messages.interpolate(
        "$N默运葵花魔功，身形变得奇快无比，接连从不同的方位向$n攻出数招！\n",
        [n1: character.name, n2: target.name]
      )
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
    level = max(Map.get(data, :level, 0), 1)
    count = Map.get(data, :count, 0)
    hits = Map.get(data, :hits, 6)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (lvl * 11 / 20 + random(lvl) > (int)target->query_skill("dodge", 1))
    dodge = Stats.skill(stats, "dodge")

    conn =
      if div(level * 11, 20) + Engine.rand(rng, level) > dodge do
        # LPC: count = kuihua / 4 的 apply/* 加成只在命中分支生效，折入每击伤害
        conn
        |> Broadcast.publish(
          Messages.interpolate(
            "$n只觉得眼前一花，发现四周都是$N的身影，不由暗生惧意，接连后退。\n",
            bindings
          )
        )
      else
        conn
        |> Broadcast.publish(
          Messages.interpolate(
            "$n见$N身法好快，哪里敢怠慢，连忙打起精神小心应对。\n",
            bindings
          )
        )
      end

    # LPC: while (i--) { if (! me->is_fighting(target)) break;
    #         if (random(2) && ! target->is_busy()) target->start_busy(1);
    #         COMBAT_D->do_attack(me, target, weapon, 0); }
    per_hit = max(div(level, 15), 1) + count

    {damage, busy_roll?} =
      Enum.reduce(1..hits, {0, false}, fn _, {damage_acc, busy_acc} ->
        hit? = div(level, 2) + Engine.rand(rng, level) > dodge
        busy_acc = busy_acc or Engine.rand(rng, 2) == 1

        damage_acc =
          if hit? do
            damage_acc + per_hit + Engine.rand(rng, per_hit)
          else
            damage_acc
          end

        {damage_acc, busy_acc}
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    combat = character.meta.combat

    combat =
      if busy_roll? and not Combat.busy?(combat) do
        Combat.start_busy(combat, 1)
      else
        combat
      end

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    # LPC: me->start_busy(1 + random(4))（收招后，位于连击之后）
    Performs.feedback(attacker, 0, 1 + Engine.rand(rng, 4))

    conn
    |> put_character(character)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // wu.c 无法无天
  # // 武器或者空手，手里拿剑或者针都可以
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define WU "「" HIC "无法无天" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int count;
  #         int lvl;
  #         int i;
  # 
  #         if (userp(me) && ! me->query("can_perform/kuihua-mogong/tian"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail(WU "只能对战斗中的对手使用。\n");
  # 
  #     if (me->query("neili") < 340)
  #         return notify_fail("你的真气不够，无法施展" WU "！\n");
  # 
  #     if ((lvl = me->query_skill("kuihua-mogong", 1)) < 220)
  #         return notify_fail("你的葵花魔功火候不够，无法施展" WU "！\n");
  # 
  #         if (me->query_skill_mapped("force") != "kuihua-mogong")
  #                 return notify_fail("你还没有激发葵花魔功为内功，无法施展" WU "。\n");
  # 
  #         if ((int)me->query("max_neili") < 3400)
  #                 return notify_fail("你的内力修为不足，难以施展" WU "。\n");
  # 
  #         if (weapon = me->query_temp("weapon"))
  #         {
  #                 if (weapon->query("skill_type") != "sword" &&
  #                     weapon->query("skill_type") != "pin")
  #                         return notify_fail("你手里拿的不是剑，怎么施"
  #                                            "展" WU "？\n");
  #         } else
  #         {
  #                 if (me->query_skill_prepared("unarmed") != "kuihua-mogong")
  #                         return notify_fail("你并没有准备使用葵"
  #                                            "花魔功，如何施展" WU "？\n");
  #         }
  # 
  #         if (weapon && me->query_skill_mapped("sword") != "kuihua-mogong")
  #                 return notify_fail("你没有准备使用葵花魔功，难以施展" WU "。\n");
  # 
  #         if (! weapon && me->query_skill_prepared("unarmed") != "kuihua-mogong")
  #                 return notify_fail("你没有准备使用葵花魔功，难以施展" WU "。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIR "$N" HIR "默运葵花魔功，身形变得奇快无比，接连从不同的方位向$n"
  #               HIR "攻出数招！\n" NOR;
  #         i = 6  + random(5);    // 取消连招数判定条件，固定连击6~10次 BY MK
  #         if (lvl * 11 / 20 + random(lvl) > (int)target->query_skill("dodge", 1))
  #         {
  #                 msg += HIR "$n" HIR "只觉得眼前一花，发现四周都是$N"
  #                        HIR "的身影，不由暗生惧意，接连后退。\n" NOR;
  #                 count = me->query_skill("kuihua-mogong", 1) / 4;
  #                 me->add_temp("apply/attack", count);
  #                 //增强伤害
  #                 me->add_temp("apply/damage", count);
  #                 me->add_temp("apply/unarmed_damage", count);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "见$N" CYN "身法好快，哪里"
  #                        "敢怠慢，连忙打起精神小心应对。\n" NOR;
  #                 count = 0;
  #         }
  # 
  #     message_combatd(msg, me, target);
  #     me->add("neili", -i * 30);
  # 
  #         while (i--)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (random(2) && ! target->is_busy())
  #                         target->start_busy(1);
  #             COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  # 
  #         me->add_temp("apply/attack", -count);
  #         me->add_temp("apply/damage", -count);
  #         me->add_temp("apply/unarmed_damage", -count);
  #     me->start_busy(1 + random(4));
  #     return 1;
  # }
end
