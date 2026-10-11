defmodule Kantele.Combat.Skills.Performs.TanzhiShentong.Xiao do
  @moduledoc """
  perform「啸沧海」（source tanzhi-shentong/xiao.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "tanzhi-shentong/xiao"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "tanzhi-shentong")
    ap = Stats.skill(stats, "finger")
    damage = ap

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
      Stats.skill(stats, "jingluo-xue") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "tanzhi-shentong") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "finger") != "tanzhi-shentong" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 3000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 0 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 800 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: 0}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 3)
    combat = Combat.start_busy(combat, 4)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

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
    damage = Map.get(data, :damage, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "parry")
    hit = div(ap, 2) + Engine.rand(rng, ap) > dp
    vitals = character.meta.vitals
    if hit do
          vitals = Vitals.damage(vitals, :jing, div((damage * 4), 3))
          vitals = Vitals.wound(vitals, :jing, div(damage, 3))
    end

    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 0, 4)
    result = if hit, do: Messages.interpolate("$n只觉$N指风袭体，随即上体一阵冰凉，顿感真气涣散几欲晕厥。", n1: attacker.name, n2: character.name), else: Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"assign_refs": [{"ap", "finger"}, {"dp", "force"}], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);"], "level_gates": [{"jingluo-xue", "200"}, {"tanzhi-shentong", "200"}], "map_gates": [{"finger", "tanzhi-shentong"}], "prepared_gates": [{"finger", "tanzhi-shentong"}], "remote_damage": false, "resource_gates": [{"max_neili", "3000"}, {"neili", "0"}, {"neili", "800"}], "set_flags": [{"neili", "0"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define XIAO "「" HIG "啸沧海" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  # //      object weapon;
  #         int ap, dp, damage;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/tanzhi-shentong/xiao"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(XIAO "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(XIAO "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("tanzhi-shentong", 1) < 200)
  #                 return notify_fail("你的弹指神通不够娴熟，难以施展" XIAO "。\n");
  # 
  #         if ((int)me->query_skill("jingluo-xue", 1) < 200)
  #                 return notify_fail("你对经络学的了解不够，难以施展" XIAO "。\n");
  # 
  #         if (me->query_skill_mapped("finger") != "tanzhi-shentong")
  #                 return notify_fail("你没有激发弹指神通，难以施展" XIAO "。\n");
  # 
  #         if (me->query_skill_prepared("finger") != "tanzhi-shentong")
  #                 return notify_fail("你没有准备弹指神通，难以施展" XIAO "。\n");
  # 
  #         if (me->query("max_neili") < 3000)
  #                 return notify_fail("你的内力修为不足，难以施展" XIAO "。\n");
  # 
  #         if (me->query("neili") < 800)
  #                 return notify_fail("你现在的真气不够，难以施展" XIAO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIG "突然间$N" HIG "指锋一转，力聚指尖“嗤”的弹出一道紫芒，直袭$n"
  #               HIG "气海大穴。\n" NOR;
  # 
  #         ap = me->query_skill("finger");
  #         dp = target->query_skill("force");
  # 
  #         damage = ap;
  #         damage += random(damage);
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 target->receive_damage("jing", damage * 4 / 3, me);
  #                 target->receive_wound("jing", damage / 3, me);
  #         target->add("neili", -damage * 3);
  # 
  #             if (target->query("neili") < 0)
  #                         target->set("neili", 0);
  # 
  #                 msg += HIR "$n" HIR "只觉$N" HIR "指风袭体，随即上体一"
  #                        "阵冰凉，顿感真气涣散几欲晕厥。\n" NOR;
  #                 me->start_busy(3);
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "防守严密，紧守门户，顿时令$P"
  #                        CYN "的攻势化为乌有。\n" NOR;
  #                 me->start_busy(4);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
