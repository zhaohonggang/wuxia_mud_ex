defmodule Kantele.Combat.Skills.Performs.HujiaDaofa.Cang do
  @moduledoc """
  perform「八方藏刀势」（source hujia-daofa/cang.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 兵器为刀 →
  基本内功>=250 → 胡家刀法>=180 → 激发 blade 为胡家刀法 → 真气>=200 →
  目标存活。起手广播后判定 `random(blade) > 目标 parry/2`：
  命中则广播「心生惧意…出了破绽」并令 `count = 胡家刀法/4`（否则 `count = 0`）；
  攻击方扣 220 真气、`apply/attack += count`（结算后还原）、忙乱 `1+random(8)`，
  连出 8 击（`COMBAT_D->do_attack`），每击前 `random(3)==1` 且目标非忙时
  令目标忙乱 1。

  差异（TODO(migrate)）：
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - `add_temp("apply/attack", count)` 折算为命中判定 `ap = 基本刀法 + count`
    （`count` 在目标侧按自身 `parry` 判定后算出）；
  - LPC 的 8 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线）折算为
    每击 `ap/2 + random(ap)` vs 目标 `dodge`（与 `biyan_dao/luo.ex` 同构）；
  - `weapon->query("skill_type") != "blade"` 的兵器检查未持刀/非刀合并为同一文案。
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
  alias Kantele.Combat.Messages

  @perform_id "hujia-daofa/cang"
  @move_name "「八方藏刀势」"

  # LPC: for (i = 0; i < 8; i++) { ... COMBAT_D->do_attack(me, target, weapon, 0); }
  @strikes 8

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "hujia-daofa")
    blade = Stats.skill(stats, "blade")
    weapon_name = weapon_name(combat)

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
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
          blade: blade,
          strikes: @strikes,
          rng: rng
        }
      })

      apply_effect(conn, character, target, weapon_name, rng)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/hujia-daofa/cang"))
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

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #         (string)weapon->query("skill_type") != "blade")
  defp check_weapon(combat) do
    if weapon_name(combat) == nil do
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (query_skill("force") < 250) / if (query_skill("hujia-daofa", 1) < 180)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 250 ->
        {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "hujia-daofa") < 180 ->
        {:error, "你的胡家刀法还不到家，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_mapped("blade") != "hujia-daofa")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "blade") == "hujia-daofa" do
      :ok
    else
      {:error, "你没有激发胡家刀法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query("neili") < 200)
  defp check_resources(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你的真气不够，难以施展#{@move_name}。\n"}
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

  defp apply_effect(conn, character, target, weapon_name, rng) do
    # LPC: msg = HIW "$N" HIW "轻舒猿臂，施出「战八方藏刀式」，手中的" + weapon->name() +
    #           HIW "吞吞吐吐，变化莫测，笼罩了$n" HIW "周身要害！\n" NOR;
    #      me->add("neili", -220); me->add_temp("apply/attack", count);
    #      … me->add_temp("apply/attack", -count); me->start_busy(1 + random(8));
    # .c 里 weapon->name() 两侧各为一个独立字面量，故 Elixir 侧保持
    #      "A" <> weapon_name <> "B" 的插入形式（不合并）。
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 220}
    combat = Combat.start_busy(character.meta.combat, 1 + Engine.rand(rng, 8))
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    conn
    |> Broadcast.publish(
      "$N轻舒猿臂，施出「战八方藏刀式」，手中的" <>
        weapon_name <> "吞吞吐吐，变化莫测，笼罩了$n周身要害！\n",
      n1: character.name,
      n2: target.name
    )
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp weapon_name(combat) do
    case Combat.weapon(combat) do
      nil -> nil
      weapon -> Map.get(weapon, :name)
    end
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
    level = Map.get(data, :level, 0)
    blade = max(Map.get(data, :blade, 0), 1)
    strikes = Map.get(data, :strikes, @strikes)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(me->query_skill("blade")) > target->query_skill("parry") / 2)
    #        { … count = me->query_skill("hujia-daofa", 1) / 4; } else { … count = 0; }
    parry = Stats.skill(stats, "parry")

    {conn, count} =
      if Engine.rand(rng, blade) > div(parry, 2) do
        {Broadcast.publish(
           conn,
           Messages.interpolate(
             "$n见来招实在是变幻莫测，不由得心生惧意，招式登时出了破绽！\n",
             bindings
           )
         ), div(level, 4)}
      else
        {Broadcast.publish(
           conn,
           Messages.interpolate("$n心底微微一惊，打起精神小心接招。\n", bindings)
         ), 0}
      end

    # LPC: me->add_temp("apply/attack", count) —— 折算为命中判定的 ap 加成。
    ap = blade + count
    dodge = Stats.skill(stats, "dodge")

    # LPC 连击 8 次：每次 `random(3)==1 && ! target->is_busy()` 令目标忙乱 1，
    # 然后 `COMBAT_D->do_attack(me, target, weapon, 0)`。
    {combat, damage} =
      Enum.reduce(1..strikes, {character.meta.combat, 0}, fn _, {combat_acc, damage_acc} ->
        combat_acc =
          if Engine.rand(rng, 3) == 1 and not Combat.busy?(combat_acc) do
            Combat.start_busy(combat_acc, 1)
          else
            combat_acc
          end

        if div(ap, 2) + Engine.rand(rng, ap) > dodge do
          {combat_acc, damage_acc + ap + Engine.rand(rng, ap)}
        else
          {combat_acc, damage_acc}
        end
      end)

    vitals =
      if damage > 0 do
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage, 3))
      else
        character.meta.vitals
      end

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    conn
    |> put_character(character)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # #define CANG "「" HIW "八方藏刀势" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #         string msg;
  #         int count;
  #         int i;
  # 
  #         if (userp(me) && ! me->query("can_perform/hujia-daofa/cang"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail(CANG "只能对战斗中的对手使用。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon")) ||
  #         (string)weapon->query("skill_type") != "blade")
  #                 return notify_fail("你使用的武器不对，难以施展" CANG "。\n");
  # 
  #     if ((int)me->query_skill("force") < 250)
  #         return notify_fail("你的内功火候不够，难以施展" CANG "。\n");
  # 
  #     if ((int)me->query_skill("hujia-daofa", 1) < 180)
  #         return notify_fail("你的胡家刀法还不到家，难以施展" CANG "。\n");
  # 
  #         if (me->query_skill_mapped("blade") != "hujia-daofa")
  #                 return notify_fail("你没有激发胡家刀法，难以施展" CANG "。\n");
  # 
  #     if ((int)me->query("neili") < 200)
  #         return notify_fail("你的真气不够，难以施展" CANG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIW "$N" HIW "轻舒猿臂，施出「战八方藏刀式」，手中的" + weapon->name() +
  #               HIW "吞吞吐吐，变化莫测，笼罩了$n" HIW "周身要害！\n" NOR;
  # 
  #         if (random(me->query_skill("blade")) > target->query_skill("parry") / 2)
  #         {
  #                 msg += HIY "$n" HIY "见来招实在是变幻莫测，不由得心"
  #                        "生惧意，招式登时出了破绽！\n" NOR;
  #                 count = me->query_skill("hujia-daofa", 1) / 4;
  #         } else
  #         {
  #                 msg += HIC "$n" HIC "心底微微一惊，打起精神小心接招。\n" NOR;
  #                 count = 0;
  #         }
  # 
  #     message_combatd(msg, me, target);
  #     me->add("neili", -220);
  #         me->add_temp("apply/attack", count);
  # 
  #         for (i = 0; i < 8; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (random(3) == 1 && ! target->is_busy())
  #                         target->start_busy(1);
  #             COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  # 
  #         me->add_temp("apply/attack", -count);
  #     me->start_busy(1 + random(8));
  #     return 1;
  # }
end
