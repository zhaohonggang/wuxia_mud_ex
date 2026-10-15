defmodule Kantele.Combat.Skills.Performs.SuxinJian.Lian do
  @moduledoc """
  连环剑术「lian」（对照 `kungfu/skill/suxin-jian/lian.c`）

  玉女素心剑连击绝技：需持剑、玉女素心剑>=120、轻功>=100、激发 sword 为
  玉女素心剑、真气>=200、目标存活。命中判定
  `ap/2 + random(ap*2) > 目标dodge`（ap = sword）：命中则连击
  `4 + random(ap/40)` 次（上限 8），未命中固定 4 次；每段伤害按引擎默认
  攻击折算（同 `biyan_dao/luo.ex` 的 do_attack 折叠先例：每次
  `level/2 + random(level) > dodge` 命中则累计 `level + random(level)`）。
  真气消耗 `attack_time * 20`，忙乱 `1 + random(attack_time)`。

  差异（TODO(migrate)）：
  - `.c` 的 `me->add_temp("apply/attack", count * 2)`（命中后临时加成）本引擎
    无对应注入点，已略去（moduledoc 记录）；
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底，
    连击中的 `! me->is_fighting(target)` 打断同样无法表达，按满段结算；
  - 引子走 `message_sort`，本引擎统一 `Broadcast.publish`；分支文案在目标侧结算。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "suxin-jian/lian"
  @move_name "「连环剑术」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_level(stats),
         :ok <- check_dodge(stats),
         :ok <- check_mapped(stats),
         :ok <- check_neili(character) do
      apply_perform(conn, character, target, weapon, stats)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/suxin-jian/lian"))
  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon"))
  #        || (string)weapon->query("skill_type") != "sword")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      {:ok, weapon}
    else
      {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("suxin-jian", 1) < 120)
  defp check_level(stats) do
    if Stats.skill(stats, "suxin-jian") < 120 do
      {:error, "你玉女素心剑不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("dodge", 1) < 100)
  defp check_dodge(stats) do
    if Stats.skill(stats, "dodge") < 100 do
      {:error, "你的轻功修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "suxin-jian")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "suxin-jian" do
      :ok
    else
      {:error, "你没有激发玉女素心剑，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query("neili") < 200)
  defp check_neili(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, weapon, stats) do
    # LPC: msg = HIM "\n$N" HIM "身子轻轻一转，霎时向$n" HIM "劈出了数剑！剑招看"
    #           "似简单，但却迅猛非常，令人匪夷所思！" NOR;
    #      message_sort(msg, me, target);
    #      ap = me->query_skill("sword"); dp = target->query_skill("dodge");
    #      attack_time = 4;
    weapon_name = Map.get(weapon, :name, "")

    conn =
      Broadcast.publish(
        conn,
        "\n$N身子轻轻一转，霎时向$n劈出了数剑！剑招看似简单，但却迅猛非常，令人匪夷所思！",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: Stats.skill(stats, "sword"),
        weapon_name: weapon_name,
        rng: &:rand.uniform/1
      }
    })

    conn
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？\n",
        n1: attacker.name,
        n2: character.name
      )
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: ap = me->query_skill("sword"); dp = target->query_skill("dodge");
    #      attack_time = 4;
    ap = max(Map.get(data, :ap, 0), 1)
    dp = Stats.skill(stats, "dodge")
    base_time = 4

    {conn, attack_time} =
      if div(ap, 2) + Engine.rand(rng, ap * 2) > dp do
        # LPC: msg = HIR "结果$n" HIR "被$N" HIR "攻了个措手不及，$n"
        #           HIR "慌忙招架，心中叫苦。\n" NOR;
        #      count = ap / 8; attack_time += random(ap / 40);
        #      me->add_temp("apply/attack", count * 2);  // 本引擎无对应注入点
        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate(
              "结果$n被$N攻了个措手不及，$n慌忙招架，心中叫苦。\n",
              bindings
            )
          )

        {conn, base_time + Engine.rand(rng, max(div(ap, 40), 1))}
      else
        # LPC: msg = HIC "$n" HIC "见$N" HIC "这几剑招式凌厉，凶猛异"
        #           "常，只得苦苦招架。\n" NOR;
        #      count = 0;
        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate(
              "$n见$N这几剑招式凌厉，凶猛异常，只得苦苦招架。\n",
              bindings
            )
          )

        {conn, base_time}
      end

    # LPC: if (attack_time > 8) attack_time = 8;
    finish(conn, character, attacker, rng, ap, min(attack_time, 8))
  end

  defp finish(conn, character, attacker, rng, ap, attack_time) do
    stats = character.meta.stats
    dodge = Stats.skill(stats, "dodge")

    # LPC: for (i = 0; i < attack_time; i++) COMBAT_D->do_attack(me, target, weapon, 20, 20);
    #      折叠为每段 `ap/2 + random(ap) > dodge` 命中累计 `ap + random(ap)`（luo.ex 先例）。
    damage =
      Enum.reduce(1..max(attack_time, 1), 0, fn _, acc ->
        if div(ap, 2) + Engine.rand(rng, ap) > dodge do
          acc + ap + Engine.rand(rng, ap)
        else
          acc
        end
      end)

    vitals = character.meta.vitals

    vitals =
      if damage > 0 do
        vitals |> Vitals.damage(:qi, damage) |> Vitals.wound(:qi, div(damage, 3))
      else
        vitals
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: me->add("neili", -attack_time * 20); me->start_busy(1 + random(attack_time));
    Performs.feedback(attacker, attack_time * 20, 1 + Engine.rand(rng, max(attack_time, 1)))

    conn
    |> put_character(character)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "suxin-jian/lian",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define LIAN "「" HIW "连环剑术" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #         string msg;
  #     int ap, dp;
  #         int count;
  #     int i, attack_time;
  # 
  #         if (userp(me) && ! me->query("can_perform/suxin-jian/lian"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #                 return notify_fail(LIAN "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你所使用的武器不对，难以施展" LIAN "。\n");
  # 
  #     if ((int)me->query_skill("suxin-jian", 1) < 120)
  #         return notify_fail("你玉女素心剑不够娴熟，难以施展" LIAN "。\n");
  # 
  #     if ((int)me->query_skill("dodge", 1) < 100)
  #         return notify_fail("你的轻功修为不够，难以施展" LIAN "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "suxin-jian")
  #                 return notify_fail("你没有激发玉女素心剑，难以施展" LIAN "。\n");
  # 
  #     if (me->query("neili") < 200)
  #         return notify_fail("你现在的真气不够，难以施展" LIAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIM "\n$N" HIM "身子轻轻一转，霎时向$n" HIM "劈出了数剑！剑招看"
  #              "似简单，但却迅猛非常，令人匪夷所思！" NOR;
  # 
  #     message_sort(msg, me, target);
  # 
  #     ap = me->query_skill("sword");
  #     dp = target->query_skill("dodge");
  # 
  #         attack_time = 4;
  # 
  #     if (ap / 2 + random(ap * 2) > dp)
  #     {
  #         msg = HIR "结果$n" HIR "被$N" HIR "攻了个措手不及，$n"
  #                       HIR "慌忙招架，心中叫苦。\n" NOR;
  #                 count = ap / 8;
  #                 attack_time += random(ap / 40);
  #                 me->add_temp("apply/attack", count * 2);
  #         } else
  #         {
  #                 msg = HIC "$n" HIC "见$N" HIC "这几剑招式凌厉，凶猛异"
  #                       "常，只得苦苦招架。\n" NOR;
  #                 count = 0;
  #         }
  #     message_combatd(msg, me, target);
  # 
  #         if (attack_time > 8)
  #                 attack_time = 8;
  # 
  #     me->add("neili", -attack_time * 20);
  # 
  #     for (i = 0; i < attack_time; i++)
  #     {
  #         if (! me->is_fighting(target))
  #             break;
  # 
  #             COMBAT_D->do_attack(me, target, weapon, 20, 20);
  #     }
  #         me->add_temp("apply/attack", -count * 2);
  #     me->start_busy(1 + random(attack_time));
  # 
  #     return 1;
  # }
end
