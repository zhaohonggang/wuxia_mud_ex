defmodule Kantele.Combat.Skills.Performs.KuihuaMogong.Qiong do
  @moduledoc """
  perform「无穷无尽」（source kuihua-mogong/qiong.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "kuihua-mogong/qiong"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "kuihua-mogong")
    ap = Stats.skill(stats, "kuihua-mogong")
    ap1 = (Stats.skill(stats, "kuihua-mogong") + Stats.skill(stats, "dodge"))
    damage = (div(ap, 2) + Engine.rand(rng, ap))

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
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
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "kuihua-mogong") < 250 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "kuihua-mogong" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 3800 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 120}
    vitals = %{vitals | neili: vitals.neili - 60}
    vitals = %{vitals | neili: vitals.neili - 80}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "这里没有可供攻击的对手。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    _stats = character.meta.stats
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 80, 1)
    result = Messages.interpolate("$N尖啸一声，猛然进步欺前，一招竟直袭$n要害，速度之快，令人见所未见，闻所未闻。
这一招速度之快完全超出了$n的想象，$n慌忙回缩招架，但是此招之快，已无从躲闪，$n尖叫一声，已然中招。
这一招速度之快完全超出了$n的想象，被$N这一招正好击中了丹田要害，浑身真气登时涣散！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-120"}, {"neili", "-60"}, {"neili", "-80"}], "assign_refs": [{"ap", "kuihua-mogong"}, {"ap1", "kuihua-mogong"}, {"dp1", "dodge"}], "busy_lines": ["me->start_busy(1 + random(2));"], "level_gates": [{"kuihua-mogong", "250"}], "map_gates": [{"sword", "kuihua-mogong"}], "prepared_gates": [{"unarmed", "kuihua-mogong"}], "remote_damage": true, "resource_gates": [{"max_neili", "3800"}, {"neili", "200"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // qiong 无穷无尽
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define QIONG "「" HIR "无穷无尽" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #     string msg;
  #         int ap, dp, ap1, dp1, damage;
  #         object weapon;
  # 
  #         if (userp(me) && ! me->query("can_perform/kuihua-mogong/qiong"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #             return notify_fail(QIONG "只能在战斗中对对手使用。\n");
  # 
  #     if (me->query_skill("kuihua-mogong", 1) < 250)
  #         return notify_fail("你的葵花魔功还不够娴熟，不能使用" QIONG "！\n");
  # 
  #         if ((int)me->query("max_neili") < 3800)
  #                 return notify_fail("你的内力修为不足，难以施展" QIONG "。\n");
  # 
  #     if (me->query("neili") < 200)
  #         return notify_fail("你的真气不够，无法施展" QIONG "\n");
  # 
  #         if (weapon = me->query_temp("weapon"))
  #         {
  #                 if (weapon->query("skill_type") != "sword" &&
  #                     weapon->query("skill_type") != "pin")
  #                         return notify_fail("你手里拿的不是剑，怎么施"
  #                                            "展" QIONG "？\n");
  #         } else
  #         {
  #                 if (me->query_skill_prepared("unarmed") != "kuihua-mogong")
  #                         return notify_fail("你并没有准备使用葵"
  #                                            "花魔功，如何施展" QIONG "？\n");
  #         }
  #         if (weapon && me->query_skill_mapped("sword") != "kuihua-mogong")
  #                 return notify_fail("你没有准备使用葵花魔功，难以施展" QIONG "。\n");
  # 
  #         if (! weapon && me->query_skill_prepared("unarmed") != "kuihua-mogong")
  #                 return notify_fail("你没有准备使用葵花魔功，难以施展" QIONG "。\n");
  # 
  #         if (! living(target))
  #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "\n$N" HIR "尖啸一声，猛然进步欺前，一招竟直袭$n" HIR "要害，速度之快，令"
  #               "人见所未见，闻所未闻。\n" NOR;
  # 
  #     me->want_kill(target);
  #         ap = me->query_skill("kuihua-mogong", 1);
  #         dp = target->query("combat_exp") / 10000;
  #     me->add("neili", -60);
  #     me->start_busy(1 + random(2));
  # 
  #         if (dp >= 100) // 对百万经验以上无效，但是仍然受到伤害
  #         {
  #                 ap1 = me->query_skill("kuihua-mogong", 1) + me->query_skill("dodge", 1);
  #                 dp1 = target->query_skill("dodge", 1) + target->query_skill("martial-cognize", 1);
  #                 if (ap1 * 2 / 3 + random(ap1) > dp1)
  #                 {
  #                      damage = ap / 2 + random(ap);
  #                      msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 95 + random(5),
  #                                                 HIR "这一招速度之快完全超出了$n" HIR "的想象，$n" HIR
  #                                                 "慌忙回缩招架，但是此招之快，已无从躲闪，$n" HIR "尖叫"
  #                                                 "一声，已然中招。\n" NOR);
  #                      me->add("neili", -80);
  #                 }
  #                 else
  #                 {
  #                      msg += HIC "$n" HIC "知道来招不善，急忙闪避，没出一点差错。\n" NOR;
  #                 }
  #                 message_sort(msg, me, target);
  #                 return 1;
  #         } else
  #         if (random(ap) > dp)
  #         {
  #                 msg += HIR "这一招速度之快完全超出了$n" HIR "的想象，被$N"
  #                        HIR "这一招正好击中了丹田要害，浑身真气登时涣散！\n" NOR;
  #                 message_combatd(msg, me, target);
  #                 me->add("neili", -120);
  #                 target->die(me);
  #                 return 1;
  #         } else
  #         {
  #                 msg += HIM "$n" HIM "大吃一惊，连忙退后，居然"
  #                       "侥幸躲开着这一招！\n" NOR;
  #         }
  # 
  #         message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
