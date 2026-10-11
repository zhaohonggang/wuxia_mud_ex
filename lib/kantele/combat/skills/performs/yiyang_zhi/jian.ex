defmodule Kantele.Combat.Skills.Performs.YiyangZhi.Jian do
  @moduledoc """
  perform「先天功」（source yiyang-zhi/jian.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "yiyang-zhi/jian"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "yiyang-zhi")
    i = 0

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
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
      Stats.skill(stats, "xiantian-gong") < 280 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "yiyang-zhi") < 280 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "finger") != "yiyang-zhi" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "force") != "xiantian-gong" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "unarmed") != "xiantian-gong" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 5000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 1000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 600}
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
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 600, 1)
    result = Messages.interpolate("霎时只见$N逆运先天真气，化为纯阳内劲聚于指尖，以一阳指诀手法疾点$n全身诸多要穴。
$n只觉全身一热，$P「先天功乾阳剑气」顿时破体而入，便似身置洪炉，喷出一口鲜血。
紧接着$N十指纷飞，接连弹出数道无形剑气，$n四面八方皆被剑气所笼罩。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-600"}], "apply_adds": ["attack"], "assign_refs": [{"ap", "force"}, {"dp", "force"}], "busy_lines": ["if (random(3) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(3 + random(3));"], "level_gates": [{"jingluo-xue", "200"}, {"xiantian-gong", "280"}, {"yiyang-zhi", "280"}], "map_gates": [{"finger", "yiyang-zhi"}, {"force", "xiantian-gong"}, {"unarmed", "xiantian-gong"}], "prepared_gates": [{"finger", "yiyang-zhi"}, {"unarmed", "xiantian-gong"}], "remote_damage": true, "resource_gates": [{"max_neili", "5000"}, {"neili", "1000"}], "var_gates": [{"i", "5"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define JIAN "「" HIW "先天功" HIR "乾阳" HIY "剑气" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int ap, dp, i, damage;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/xiantian-gong/jian"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(JIAN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(JIAN "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("xiantian-gong", 1) < 280)
  #                 return notify_fail("你的先天功修为不够，难以施展" JIAN "。\n");
  # 
  #         if ((int)me->query_skill("yiyang-zhi", 1) < 280)
  #                 return notify_fail("你一阳指诀不够娴熟，难以施展" JIAN "。\n");
  # 
  #         if ((int)me->query_skill("jingluo-xue", 1) < 200)
  #                 return notify_fail("你对经络学了解不够，难以施展" JIAN "。\n");
  # 
  #         if (me->query("max_neili") < 5000)
  #                 return notify_fail("你的内力修为不足，难以施展" JIAN "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "xiantian-gong")
  #                 return notify_fail("你没有激发先天功为拳脚，难以施展" JIAN "。\n");
  # 
  #         if (me->query_skill_mapped("force") != "xiantian-gong")
  #                 return notify_fail("你没有激发先天功为内功，难以施展" JIAN "。\n");
  # 
  #         if (me->query_skill_mapped("finger") != "yiyang-zhi")
  #                 return notify_fail("你没有激发一阳指为指法，难以施展" JIAN "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "xiantian-gong"
  #            && me->query_skill_prepared("finger") != "yiyang-zhi")
  #                 return notify_fail("你没有准备先天功或一阳指，难以施展" JIAN "。\n");
  # 
  #         if (me->query("neili") < 1000)
  #                 return notify_fail("你现在的真气不足，难以施展" JIAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "霎时只见$N" HIY "逆运" HIW "先天真气" HIY "，化为" HIR
  #               "纯阳内劲" HIY "聚于指尖，以一阳指诀手法疾点$n" HIY "全身诸"
  #               "多要穴。\n" NOR;  
  # 
  #         ap = me->query_skill("force") +
  #            me->query_skill("finger") +
  #            me->query_skill("unarmed");
  # 
  #         dp = target->query_skill("force") +
  #            target->query_skill("parry") +
  #            target->query_skill("dodge");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         { 
  #                 damage = ap + random(ap / 2);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 100,
  #                                            HIR "$n" HIR "只觉全身一热，$P" HIR "「"
  #                                            HIW "先天功" HIR "乾阳" HIY "剑气" HIR
  #                                            "」顿时破体而入，便似身置洪炉，喷出一口"
  #                                            "鲜血。\n" NOR);
  #                 message_combatd(msg, me, target);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "见$N" CYN "这指来势汹涌，不敢"
  #                        "轻易招架，当即飞身纵跃闪开。\n" NOR;
  #                 message_combatd(msg, me, target);
  #         }
  # 
  #         msg = HIR "紧接着$N" HIR "十指纷飞，接连弹出数道无形剑气，$n"
  #               HIR "四面八方皆被剑气所笼罩。\n"NOR;
  #         message_combatd(msg, me, target);
  # 
  #         me->add_temp("apply/attack", 100);
  # 
  #         for (i = 0; i < 5; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  # 
  #                 if (random(3) == 1 && ! target->is_busy())
  #                         target->start_busy(1);
  # 
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  # 
  #         me->add_temp("apply/attack", -100);
  #         me->add("neili", -600);
  #         me->start_busy(3 + random(3));
  #         return 1;
  # }
end
