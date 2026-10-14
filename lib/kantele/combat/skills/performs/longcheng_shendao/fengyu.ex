defmodule Kantele.Combat.Skills.Performs.LongchengShendao.Fengyu do
  @moduledoc """
  perform「风雨交加」（source longcheng-shendao/fengyu.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 持刀 → 真气>=270 →
  内功>=150 → 龙城神刀>=120 → 目标存活。
  起手广播（含手中兵器名）后，按 `lvl/2 + random(lvl) > 目标招架*2/3` 追加文案：
  命中则给自身 `apply/attack` 临时加成 `lvl/5`，否则无加成；随后无条件扣
  真气 120，连击 5 次 `do_attack`，收招后忙乱 `1 + random(5)`。

  差异（TODO(migrate)）：
  - 起手文案与命中分支依赖目标招架，故整体在目标侧 `resolve_incoming/4` 完成；
    攻击方无条件的内力消耗与忙乱在 `run` 侧直接结算；
  - `.c` 的 `COMBAT_D->do_attack(me, target, weapon, 0)` 连击（完整 AP/DP/招架/
    伤害管线）折算为每击 `lvl/15 + count` 基础伤害 + 命中判定
    `lvl/2 + random(lvl)` vs 目标 dodge；`apply/attack` 的 `count` 加成（先加后减、
    净零）折入每击伤害；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧死亡检查兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine

  @perform_id "longcheng-shendao/fengyu"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "longcheng-shendao")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         {:ok, weapon} <- check_weapon(character),
         :ok <- check_neili(character),
         :ok <- check_force(stats),
         :ok <- check_level(stats),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          weapon_name: Map.get(weapon, :name),
          rng: rng
        }
      })

      apply_effect(conn, character, rng)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/longcheng-shendao/fengyu"))
  #         return notify_fail("你不会使用「风雨交加」。\n");
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你不会使用「风雨交加」。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「风雨交加」只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (!objectp(weapon = me->query_temp("weapon")) ||
  #          (string)weapon->query("skill_type") != "blade")
  #         return notify_fail("施展「风雨交加」手中必须拿着一把刀！\n");
  defp check_weapon(character) do
    case Combat.weapon(character.meta.combat) do
      %{skill_type: "blade"} = weapon -> {:ok, weapon}
      _ -> {:error, "施展「风雨交加」手中必须拿着一把刀！\n"}
    end
  end

  # LPC: if ((int)me->query("neili") < 270)
  #         return notify_fail("你的真气不够，无法施展「风雨交加」！\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 270 do
      {:error, "你的真气不够，无法施展「风雨交加」！\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("force") < 150)
  #         return notify_fail("你的内功火候不够，无法施展「风雨交加」！\n");
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 150 do
      {:error, "你的内功火候不够，无法施展「风雨交加」！\n"}
    else
      :ok
    end
  end

  # LPC: if ((lvl = (int)me->query_skill("longcheng-shendao", 1)) < 120)
  #         return notify_fail("你的龙城神刀还不到家，无法使用绝技「风雨交加」！\n");
  defp check_level(stats) do
    if Stats.skill(stats, "longcheng-shendao") < 120 do
      {:error, "你的龙城神刀还不到家，无法使用绝技「风雨交加」！\n"}
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

  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活。
  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  # LPC: me->add("neili", -120); me->start_busy(1 + random(5));
  defp apply_effect(conn, character, rng) do
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 120}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    combat = Combat.start_busy(character.meta.combat, 1 + Engine.rand(rng, 5))
    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> put_character(character)
    |> assign(:prompt, false)
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
    lvl = max(Map.get(data, :level, 0), 1)
    weapon_name = Map.get(data, :weapon_name, "")
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: msg = HIC "$N" HIC "大喝一声，手中的" + weapon->name() + HIC
    #            "如雨点一般向$n" HIC "打去，$n" HIC "如同小舟一般在刀雨中漂泊不定。\n" NOR;
    opening =
      "$N大喝一声，手中的" <> weapon_name <>
        "如雨点一般向$n打去，$n如同小舟一般在刀雨中漂泊不定。\n"

    # LPC: if (lvl / 2 + random(lvl) > target->query_skill("parry") * 2 / 3)
    #         { msg += HIY "这阵刀势变化莫测，$n" HIY "顿时觉得眼花缭乱，无法抵挡。\n" NOR;
    #           count = lvl / 5; me->add_temp("apply/attack", count); }
    #      else { msg += HIC "$n" HIC "不禁心中凛然，不敢有半点小觑，使出浑身解数抵挡。\n" NOR;
    #             count = 0; }
    {conn, count} =
      if div(lvl, 2) + Engine.rand(rng, lvl) > div(Stats.skill(stats, "parry") * 2, 3) do
        {Broadcast.publish(
           conn,
           opening <> "这阵刀势变化莫测，$n顿时觉得眼花缭乱，无法抵挡。\n",
           bindings
         ), div(lvl, 5)}
      else
        {Broadcast.publish(
           conn,
           opening <> "$n不禁心中凛然，不敢有半点小觑，使出浑身解数抵挡。\n",
           bindings
         ), 0}
      end

    # LPC: for (i = 0; i < 5; i++) { if (! me->is_fighting(target)) break;
    #          COMBAT_D->do_attack(me, target, weapon, 0); }
    # 连击折算：每击 `lvl/15 + count` 基础伤害 + 命中判定（lvl/2 + random(lvl) vs 目标 dodge）。
    dodge = Stats.skill(stats, "dodge")
    per_hit = max(div(lvl, 15), 1) + count

    {damage, hits} =
      Enum.reduce(1..5, {0, 0}, fn _, {damage_acc, hit_acc} ->
        if not Combat.fighting?(character.meta.combat) do
          {damage_acc, hit_acc}
        else
          if div(lvl, 2) + Engine.rand(rng, lvl) > dodge do
            {damage_acc + per_hit + Engine.rand(rng, per_hit), hit_acc + 1}
          else
            {damage_acc, hit_acc}
          end
        end
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn =
      if hits > 0 do
        Broadcast.publish(conn, "$n被$N击中！\n", bindings)
      else
        conn
      end

    put_character(conn, character)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // fengyu.c 风雨交加
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #         string msg;
  #         int count;
  #         int lvl;
  #         int i;
  # 
  #         if (userp(me) && ! me->query("can_perform/longcheng-shendao/fengyu"))
  #                 return notify_fail("你不会使用「风雨交加」。\n");
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail("「风雨交加」只能对战斗中的对手使用。\n");
  # 
  #     if (!objectp(weapon = me->query_temp("weapon")) ||
  #         (string)weapon->query("skill_type") != "blade")
  #         return notify_fail("施展「风雨交加」手中必须拿着一把刀！\n");
  # 
  #     if ((int)me->query("neili") < 270)
  #         return notify_fail("你的真气不够，无法施展「风雨交加」！\n");
  # 
  #     if ((int)me->query_skill("force") < 150)
  #         return notify_fail("你的内功火候不够，无法施展「风雨交加」！\n");
  # 
  #     if ((lvl = (int)me->query_skill("longcheng-shendao", 1)) < 120)
  #         return notify_fail("你的龙城神刀还不到家，无法使用绝技「风雨交加」！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIC "$N" HIC "大喝一声，手中的" + weapon->name() + HIC
  #               "如雨点一般向$n" HIC "打去，$n" HIC "如同小舟一般在刀雨中漂泊不定。\n" NOR;
  # 
  #         if (lvl / 2 + random(lvl) > target->query_skill("parry") * 2 / 3)
  #         {
  #                 msg += HIY "这阵刀势变化莫测，$n" HIY "顿时觉得眼花缭乱，无法抵挡。\n" NOR;
  #                 count = lvl / 5;
  #                 me->add_temp("apply/attack", count);
  #         } else
  #         {
  #                 msg += HIC "$n" HIC "不禁心中凛然，不敢有半点小觑，使出浑身解数抵挡。\n" NOR;
  #                 count = 0;
  #         }
  # 
  #     message_combatd(msg, me, target);
  #     me->add("neili", -120);
  # 
  #         for (i = 0; i < 5; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #             COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  # 
  #     me->start_busy(1 + random(5));
  #         me->add_temp("apply/attack", -count);
  # 
  #     return 1;
  # }
end
