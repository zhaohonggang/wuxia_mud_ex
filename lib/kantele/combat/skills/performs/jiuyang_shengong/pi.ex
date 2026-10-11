defmodule Kantele.Combat.Skills.Performs.JiuyangShengong.Pi do
  @moduledoc """
  perform「骄阳劈天」（source jiuyang-shengong/pi.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "jiuyang-shengong/pi"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jiuyang-shengong")
    ap = (Stats.skill(stats, "blade") + Stats.skill(stats, "force"))
    damage = (ap + Engine.rand(rng, div(ap, 3)))

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
      Stats.skill(stats, "blade") < 240 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "force") < 240 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "jiuyang-shengong") < 220 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "blade") != "jiuyang-shengong" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 5500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 400 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 150}
    vitals = %{vitals | neili: vitals.neili - 200}
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
    Performs.feedback(attacker, 200, 1)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-150"}, {"neili", "-200"}], "assign_refs": [{"ap", "blade"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(2 + random(2));"], "level_gates": [{"blade", "240"}, {"force", "240"}, {"jiuyang-shengong", "220"}], "map_gates": [{"blade", "jiuyang-shengong"}], "remote_damage": true, "resource_gates": [{"max_neili", "5500"}, {"neili", "400"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define PO "「" HIW "骄阳劈天" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # string final(object me, object target, int damage);
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/jiuyang-shengong/pi"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (userp(me) && ! me->query("can_learn/jiuyang-shengong/enable_weapon"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");    
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(PO "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "blade")
  #                 return notify_fail("你使用的武器不对，难以施展" PO "。\n");
  # 
  #         if ((int)me->query_skill("jiuyang-shengong", 1) < 220)
  #                 return notify_fail("你的九阳神功不够娴熟，难以施展" PO "。\n");
  # 
  #         if ((int)me->query_skill("force", 1) < 240)
  #                 return notify_fail("你的内功根基不够，难以施展" PO "。\n");
  # 
  #         if ((int)me->query_skill("blade", 1) < 240)
  #                 return notify_fail("你的基本刀法火候不够，难以施展" PO "。\n");
  # 
  #         if ((int)me->query("max_neili") < 5500)
  #                 return notify_fail("你的内力修为不足，难以施展" PO "。\n");
  # 
  #         if (me->query("neili") < 400)
  #                 return notify_fail("你现在真气不够，难以施展" PO "。\n");
  # 
  #         if (me->query_skill_mapped("blade") != "jiuyang-shengong") 
  #                 return notify_fail("你没有激发九阳神功为刀法，难以施展" PO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "\n$N" HIW "猛然间飞身而起，半空中一声长啸，内力源源不绝地涌"
  #               "入" + weapon->name() + HIW "，刹那间刀芒夺目，自天而下，劈向$n" HIW "！\n" NOR;
  # 
  #         me->add("neili", -150);
  #         ap = me->query_skill("blade") + me->query_skill("force", 1);
  #         dp = target->query_skill("parry") + target->query_skill("force", 1);
  # 
  #         me->start_busy(2 + random(2));
  #         if (ap * 11 / 20 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 3);
  #                 me->add("neili", -200);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 85 + random(5),
  #                                            (: final, me, target, damage :));
  #         } else
  #         {
  #                 msg += HIC "可是$n" HIC "看透$P" HIC "此招之中的破绽，镇"
  #                        "定逾恒，全神应对自如。\n" NOR;
  #         }
  #         message_sort(msg, me, target);
  # 
  #         return 1;
  # }
  # 
  # string final(object me, object target, int damage)
  # {
  #         target->add("neili", -(damage / 4));
  #         target->add("neili", -(damage / 8));
  #         return  HIR "$n" HIR "只觉刀芒夺目，正犹豫间到刀芒已穿透$n" HIR "身体，顿时"
  #                 "鲜血狂涌，内息散乱。\n" NOR;
  # }
end
