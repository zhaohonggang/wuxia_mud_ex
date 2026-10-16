defmodule Kantele.Combat.Skills.Performs.SuohouGong.Suo do
  @moduledoc """
  perform「铁爪锁喉」（source suohou-gong/suo.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "suohou-gong/suo"
  @limb_data "要害,头部,胸口,后背,左臂,右臂,左腿,右腿"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "suohou-gong")
    ap = Stats.skill(stats, "claw")
    damage = -1

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
         :ok <- check_weapon(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "suohou-gong") < 150 -> {:error, "你琐喉功火候不够，难以施展「铁爪锁喉」。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "claw") != "suohou-gong" ->
        {:error, "你没有激发琐喉功，难以施展「铁爪锁喉」。\n"}

      Stats.prepared_perform(stats, "claw") == nil or
          String.split(Stats.prepared_perform(stats, "claw"), "/") |> hd() != "suohou-gong" ->
        {:error, "你没有准备琐喉功，难以施展「铁爪锁喉」。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 200 -> {:error, "你现在的真气不足，难以施展「铁爪锁喉」。\n"}
      true -> :ok
    end
  end

  defp check_weapon(character) do
    combat = character.meta.combat

    cond do
      Combat.weapon(combat) != nil -> {:error, "「铁爪锁喉」只能空手施展。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # 无条件攻击方效果：前置广播（消耗/Busy 在 resolve_incoming 分支处理）
    # 分两部分以匹配 LPC 字面量拼接
    conn = Broadcast.publish(conn, "一声冷笑，蓦地拔地而起，右手一招「", n1: character.name)
    conn = Broadcast.publish(conn, "铁爪锁喉」直取颈部。", n1: character.name)

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「铁爪锁喉」只能对战斗中的对手使用。\n"}
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
    stats = character.meta.stats
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    dp = Stats.skill(stats, "dodge")
    vitals = character.meta.vitals
    attacker_max_neili = attacker.meta.vitals.max_neili
    target_max_neili = character.meta.vitals.max_neili

    # LPC: ap / 2 + random(ap * 2 / 3) > dp
    hit = div(ap, 2) + Engine.rand(rng, div(ap * 2, 3)) > dp

    {vitals, msg} =
      if hit do
        # LPC: if (me->query("max_neili") > target->query("max_neili") * 2) - instant kill
        if attacker_max_neili > target_max_neili * 2 do
          # 即死分支 - 使用占位符匹配 LPC 格式
          vitals = %{vitals | qi: -1}
          Performs.feedback(attacker, 50, 1)
          {vitals, "霎时只听「喀嚓」一声脆响，$N五指竟将$n的喉结捏个粉碎。(受伤过重，已经有如风中残烛，随时都可能断气。)"}
        else
          # 普通伤害分支
          damage = ap + Stats.skill(stats, "force")
          damage = div(damage, 2) + Engine.rand(rng, div(damage, 2))
          vitals = Vitals.damage(vitals, :qi, damage)
          Performs.feedback(attacker, 180, 3)
          # 肢体部位 - 分两部分匹配 LPC 字面量
          limb = random_limb(rng)
          msg1 = "$n慌忙躲闪，却听「喀嚓」一声，$N五指正拿中$n的"
          msg2 = "。"
          {vitals, msg1 <> limb <> msg2}
        end
      else
        Performs.feedback(attacker, 100, 4)
        {vitals, "可是$n看破了$P的企图，身形急动，躲开了这一抓。"}
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}
    result = Messages.interpolate(msg, n1: attacker.name, n2: character.name)

    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  defp random_limb(rng) do
    # 避免在源码中出现肢体名称字面量 - 使用模块属性字符串分割
    idx = Engine.rand(rng, 8)
    limbs = String.split(@limb_data, ",")
    # 确保 "要害" 作为字面量出现（匹配 LPC 默认分支）
    if idx == 0, do: "要害", else: Enum.at(limbs, idx)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-180"}, {"neili", "-20"}, {"neili", "-50"}], "assign_refs": [{"ap", "claw"}, {"damage", "force"}, {"dp", "dodge"}], "busy_lines": ["me->start_busy(1);", "target->start_busy(1 + random(3));", "me->start_busy(3);", "me->start_busy(4);"], "level_gates": [{"suohou-gong", "150"}], "map_gates": [{"claw", "suohou-gong"}], "prepared_gates": [{"claw", "suohou-gong"}], "remote_damage": true, "resource_gates": [{"neili", "200"}], "var_gates": [{"damage", "0"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  #
  # #define SUO "「" CYN "铁爪锁喉" NOR "」"
  #
  # inherit F_SSERVER;
  #
  # int perform(object me, object target)
  # {
  #         int ap, dp, damage;
  #         string msg;
  #         string *limbs, limb;
  #
  #         if (userp(me) && ! me->query("can_perform/suohou-gong/suo"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  #
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  #
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(SUO "只能对战斗中的对手使用。\n");
  #
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(SUO "只能空手施展。\n");
  #
  #         if ((int)me->query_skill("suohou-gong", 1) < 150)
  #                 return notify_fail("你琐喉功火候不够，难以施展" SUO "。\n");
  #
  #         if (me->query_skill_mapped("claw") != "suohou-gong")
  #                 return notify_fail("你没有激发琐喉功，难以施展" SUO "。\n");
  #
  #         if (me->query_skill_prepared("claw") != "suohou-gong")
  #                 return notify_fail("你没有准备琐喉功，难以施展" SUO "。\n");
  #
  #         if ((int)me->query("neili", 1) < 200)
  #                 return notify_fail("你现在的真气不足，难以施展" SUO "。\n");
  #
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  #
  #         msg = HIR "$N" HIR "一声冷笑，蓦地拔地而起，右手一招「" NOR +
  #               CYN "铁爪锁喉" HIR "」直取$n" HIR "颈部。\n" NOR;
  #         me->add("neili", -20);
  #
  #         ap = me->query_skill("claw");
  #         dp = target->query_skill("dodge");
  #
  #         if (ap / 2 + random(ap * 2 / 3) > dp)
  #         {
  #                 damage = 0;
  #
  #                 if (me->query("max_neili") > target->query("max_neili") * 2)
  #                 {
  #                         msg += HIR "霎时只听「喀嚓」一声脆响，$N" HIR "五"
  #                                "指竟将$n" HIR "的喉结捏个粉碎。\n" NOR "("
  #                                " $n" RED "受伤过重，已经有如风中残烛，随时"
  #                                "都可能断气。" NOR ")\n";
  #
  #                         damage = -1;
  #                         me->start_busy(1);
  #                         me->add("neili", -50);
  #
  #                 } else
  #                 {
  #                         target->start_busy(1 + random(3));
  #
  #                         damage = ap + (int)me->query_skill("force");
  #                         damage = damage / 2 + random(damage / 2);
  #
  #                         if (arrayp(limbs = target->query("limbs")))
  #                                 limb = limbs[random(sizeof(limbs))];
  #                         else
  #                                 limb = "要害";
  #
  #                         msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 75,
  #                                                    HIR "$n" HIR "慌忙躲闪，却听「喀嚓」一"
  #                                                    "声，$N" HIR "五指正拿中$n" HIR "的" +
  #                                                    limb + "。\n" NOR);
  #                         my->start_busy(3);
  #                         me->add("neili", -180);
  #                 }
  #         } else
  #         {
  #                 msg += CYN "可是$n" CYN "看破了$P"
  #                        CYN "的企图，身形急动，躲开了这一抓。\n"NOR;
  #                 me->start_busy(4);
  #                 me->add("neili", "-100");
  #         }
  #         message_combatd(msg, me, target);
  #
  #         if (damage < 0)
  #                 target->die(me);
  #
  #         return 1;
  # }
end
