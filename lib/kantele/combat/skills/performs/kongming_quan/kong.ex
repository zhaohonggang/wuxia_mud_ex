defmodule Kantele.Combat.Skills.Performs.KongmingQuan.Kong do
  @moduledoc """
  perform「空空如也」（source kongming-quan/kong.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "kongming-quan/kong"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "kongming-quan")
    ap = Stats.skill(stats, "unarmed")

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
      Stats.skill(stats, "kongming-quan") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "unarmed") != "kongming-quan" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 150 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 80}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
    combat = Combat.start_busy(combat, 3)
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
    rng = Map.get(data, :rng, &:rand.uniform/1)
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 80, 3)
    result = Messages.interpolate("$n无法窥测$N拳中奥秘，被这一拳击中要害，登时呕出一大口鲜血！
:内伤@?", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-80"}], "assign_refs": [{"ap", "unarmed"}, {"damage", "force"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(3);", "me->start_busy(2);"], "level_gates": [{"kongming-quan", "150"}], "map_gates": [{"unarmed", "kongming-quan"}], "prepared_gates": [{"unarmed", "kongming-quan"}], "remote_damage": true, "resource_gates": [{"neili", "150"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define KONG "「" HIG "空空如也" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     int damage;
  #     string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/kongming-quan/kong"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #                 return notify_fail(KONG "只能对战斗中的对手使用。\n");
  # 
  #     if (objectp(me->query_temp("weapon")))
  #                 return notify_fail(KONG "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("kongming-quan", 1) < 150)
  #         return notify_fail("你的空明拳不够娴熟，难以施展" KONG "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "kongming-quan")
  #                 return notify_fail("你没有激发空明拳，难以施展" KONG "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "kongming-quan")
  #                 return notify_fail("你没有准备空明拳，难以施展" KONG "。\n");
  # 
  #         if ((int)me->query("neili", 1) < 150)
  #         return notify_fail("你现在的真气太弱，难以施展" KONG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = WHT "$N" WHT "使出空明拳「" HIG "空空如也" NOR + WHT "」，拳劲"
  #               "虚虚实实，变化莫测，让$n" WHT "一时难以捕捉。\n" NOR;
  #     me->add("neili", -80);
  # 
  #         ap = me->query_skill("unarmed");
  #         dp = target->query_skill("parry");
  #     if (ap / 2 + random(ap) > dp)
  #     {
  #         me->start_busy(3);
  # 
  #         damage = (int)me->query_skill("force", 1);
  #                 damage = damage + random(damage / 2);
  # 
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80,
  #                        HIR "$n" HIR "无法窥测$N" HIR "拳中奥"
  #                                            "秘，被这一拳击中要害，登时呕出一大口"
  #                                            "鲜血！\n:内伤@?");
  #     } else
  #     {
  #         me->start_busy(2);
  #         msg += CYN "可是$p" CYN "识破了$P"
  #                        CYN "的拳招中的变化，精心应对，并没有吃亏。\n" NOR;
  #     }
  #     message_combatd(msg, me, target);
  #     return 1;
  # }
end
