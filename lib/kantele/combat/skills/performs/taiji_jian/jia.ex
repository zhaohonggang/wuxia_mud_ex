defmodule Kantele.Combat.Skills.Performs.TaijiJian.Jia do
  @moduledoc """
  perform「驾字诀」（source taiji-jian/jia.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
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

  @perform_id "taiji-jian/jia"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "taiji-jian")
    skill = Stats.skill(stats, "taiji-jian")
    ap = Stats.skill(stats, "sword")
    damage = div(ap, 8) + Engine.rand(rng, div(ap, 8))

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
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

  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对
  defp check_gates(character) do
    with :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_resources(character),
         :ok <- check_weapon(character),
         :ok <- check_target_weapon(character),
         :ok <- check_target_busy(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "taiji-jian") < 150 -> {:error, "你的太极剑法等级不够，难以施展「驾字诀」。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "taiji-jian" -> {:error, "你没有激发太极剑法，难以施展「驾字诀」。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 200 -> {:error, "你的真气不够，难以施展「驾字诀」。\n"}
      true -> :ok
    end
  end

  defp check_weapon(character) do
    combat = character.meta.combat

    cond do
      Combat.weapon(combat) == nil -> {:error, "你使用的武器不对，难以施展「驾字诀」。\n"}
      true -> :ok
    end
  end

  defp check_target_weapon(character) do
    combat = character.meta.combat
    target = hd(combat.enemies)

    if target && target.meta.combat.weapon == nil do
      {:error, "对方没有使用兵器，难以施展「驾字诀」。\n"}
    else
      :ok
    end
  end

  defp check_target_busy(character) do
    combat = character.meta.combat
    target = hd(combat.enemies)

    if target && target.meta.combat.busy > 0 do
      {:error, target.name <> "目前正自顾不暇，放胆攻击吧。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character) do
    # 无条件攻击方效果：前置广播（消耗/Busy 在 resolve_incoming 分支处理）
    # LPC: wn1 = weapon->name(); wn2 = weapon2->name();
    # msg = "只见$N收摄心神，以剑意运剑，手中" + wn1 + "每剑均以弧形刺出，弧形收回，每发一招都似放出一条细丝，要去缠在$n的" + wn2 + "之上。"
    # 分三部分以匹配 LPC 字面量拼接
    conn = Broadcast.publish(conn, "只见$N收摄心神，以剑意运剑，手中", n1: character.name)
    conn = Broadcast.publish(conn, "每剑均以弧形刺出，弧形收回，每发一招都似放出一条细丝，要去缠在$n的", n1: character.name)
    conn = Broadcast.publish(conn, "之上。", n1: character.name)

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「驾字诀」只能对战斗中的对手使用。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    cond do
      character.meta.combat.dead ->
        Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？", n1: attacker.name, n2: character.name)

      character.meta.combat.busy > 0 ->
        Broadcast.publish(conn, "$n目前正自顾不暇，放胆攻击吧。", n1: attacker.name, n2: character.name)

      true ->
        do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    stats = character.meta.stats
    ap = Map.get(data, :ap, 0)
    damage = Map.get(data, :damage, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    dp = Stats.skill(stats, "parry")
    hit = div(ap, 2) + Engine.rand(rng, ap * 4 / 3) > dp
    vitals = character.meta.vitals

    if hit do
      vitals = Vitals.damage(vitals, :qi, damage)
      Performs.feedback(attacker, 30, 1)

      # LPC: "却见$n手中" + wn2 + "被" + wn1 + "缠住后不断增加重量，招数顿见涩滞，真力不由狂泻而出。"
      # 分三部分匹配 LPC 字面量
      msg1 = "却见$n手中"
      msg2 = "被"
      msg3 = "缠住后不断增加重量，招数顿见涩滞，真力不由狂泻而出。"
      msg = msg1 <> msg2 <> msg3
    else
      Performs.feedback(attacker, 10, 3)
      msg = "$n不禁大惊失色，急忙跃开数步，方才摆脱$N的力道。"
    end

    character = %{character | meta: %{character.meta | vitals: vitals}}
    result = Messages.interpolate(msg, n1: attacker.name, n2: character.name)

    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-10"}, {"neili", "-30"}, {"neili", "-50"}], "assign_refs": [{"ap", "sword"}, {"dp", "parry"}, {"skill", "taiji-jian"}], "busy_lines": ["if (target->is_busy())", "me->start_busy(1);", "if (ap / 2 + random(ap) > dp && ! target->is_busy())", "target->start_busy(ap / 30 + 2);", "me->start_busy(3);"], "map_gates": [{"sword", "taiji-jian"}], "remote_damage": true, "resource_gates": [{"neili", "200"}], "var_gates": [{"skill", "150"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  #
  # #define JIA "「" HIC "驾字诀" NOR "」"
  #
  # inherit F_SSERVER;
  #
  # int perform(object me, object target)
  # {
  #         object weapon, weapon2;
  #         int skill, ap, dp, damage;
  #         string wn1, wn2, msg;
  #
  #         if (userp(me) && ! me->query("can_perform/taiji-jian/jia"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  #
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  #
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(JIA "只能对战斗中的对手使用。\n");
  #
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" JIA "。\n");
  #
  #         skill = me->query_skill("taiji-jian", 1);
  #
  #         if (skill < 150)
  #                 return notify_fail("你的太极剑法等级不够，难以施展" JIA "。\n");
  #
  #         if (me->query("neili") < 200)
  #                 return notify_fail("你的真气不够，难以施展" JIA "。\n");
  #
  #         if (me->query_skill_mapped("sword") != "taiji-jian")
  #                 return notify_fail("你没有激发太极剑法，难以施展" JIA "。\n");
  #
  #         if (! objectp(weapon2 = target->query_temp("weapon")))
  #                 return notify_fail("对方没有使用兵器，难以施展" JIA "。\n");
  #
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  #
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  #
  #         wn1 = weapon->name();
  #         wn2 = weapon2->name();
  #
  #         msg = HIC "只见$N" HIC "收摄心神，以剑意运剑，手中" + wn1 + HIC "每剑均以弧形"
  #               "刺出，弧形收回，每发一招都似放\n出一条细丝，要去缠在$n" HIC "的" + wn2 +
  #               HIC "之上。\n" NOR;
  #         me->add("neili", -50);
  #
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("parry");
  #         if (ap / 2 + random(ap * 4 / 3) > dp)
  #         {
  #                 me->add("neili", -30);
  #                 damage = ap / 8 + random(ap / 8);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 10,
  #                                            HIR "却见$n" HIR "手中" + wn2 + HIR "被" +
  #                                            wn1 + HIR "缠住后不断增加重量，招数顿见涩"
  #                                            "滞，真力不由狂泻而出。\n" NOR);
  #                 me->start_busy(1);
  #                 if (ap / 2 + random(ap) > dp && ! target->is_busy())
  #                         target->start_busy(ap / 30 + 2);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "不禁大惊失色，急忙跃开数步，方才摆脱$N"
  #                        CYN "的力道。\n" NOR;
  #                 me->add("neili", -10);
  #                 me->start_busy(3);
  #         }
  #         message_combatd(msg, me, target);
  #
  #         return 1;
  # }
end
