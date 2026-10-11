defmodule Kantele.Combat.Skills.Performs.YiyangZhi.Dian do
  @moduledoc """
  perform「神指点穴」（source yiyang-zhi/dian.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "yiyang-zhi/dian"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "yiyang-zhi")
    ap = Stats.skill(stats, "finger")
    damage = (div(ap, 4) + Engine.rand(rng, div(ap, 2)))

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
      Stats.skill(stats, "force") < 160 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "jingluo-xue") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "yiyang-zhi") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "finger") != "yiyang-zhi" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 1800 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    vitals = %{vitals | neili: vitals.neili - 200}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1)
    combat = Combat.start_busy(combat, 2)
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
    Performs.feedback(attacker, 200, 2)
    result = Messages.interpolate("$N凝聚一阳指诀功力，陡然点出一指，变化多端，巧逼$n诸处大穴。
结果$p被$P逼得招架不迭，一时无法反击！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-200"}], "assign_refs": [{"ap", "finger"}, {"dp", "parry"}], "busy_lines": ["//if (target->is_busy())", "target->start_busy((int)me->query_skill("finger") / 20 + 2);", "me->start_busy(2);", "me->start_busy(1);"], "level_gates": [{"force", "160"}, {"jingluo-xue", "120"}, {"yiyang-zhi", "120"}], "map_gates": [{"finger", "yiyang-zhi"}], "prepared_gates": [{"finger", "yiyang-zhi"}], "remote_damage": true, "resource_gates": [{"max_neili", "1800"}, {"neili", "200"}], "temp_set": ["no_perform"]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define DIAN "「" HIR "神指点穴" NOR "」"
  # 
  # string final(object me, object target);
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     //object weapon;
  #     string msg;
  #         int ap, dp;
  #         int damage;
  #         if (userp(me) && ! me->query("can_perform/yiyang-zhi/dian"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(DIAN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(DIAN "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("yiyang-zhi", 1) < 120)
  #                 return notify_fail("你一阳指诀不够娴熟，难以施展" DIAN "。\n");
  # 
  #         if ((int)me->query_skill("jingluo-xue", 1) < 120)
  #                 return notify_fail("你对经络学了解不够，难以施展" DIAN "。\n");
  # 
  #         if (me->query_skill_mapped("finger") != "yiyang-zhi")
  #                 return notify_fail("你没有激发一阳指诀，难以施展" DIAN "。\n");
  # 
  #         if (me->query_skill_prepared("finger") != "yiyang-zhi")
  #                 return notify_fail("你没有准备一阳指诀，难以施展" DIAN "。\n");
  # 
  #         if ((int)me->query_skill("force") < 160)
  #                 return notify_fail("你的内功火候不够，难以施展" DIAN "。\n");
  # 
  #         if (me->query("max_neili") < 1800)
  #                 return notify_fail("你的内力修为不足，难以施展" DIAN "。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不够，难以施展" DIAN "。\n");
  # 
  #         //if (target->is_busy())
  #         //        return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  #         if (target->query_temp("no_perform"))
  #                 return notify_fail("对方现在已经无法控制真气，放胆攻击吧。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIR "$N" HIR "凝聚一阳指诀功力，陡然点出一指，变化多端，巧逼$n"
  #               HIR "诸处大穴。\n" NOR;
  # 
  #         ap = me->query_skill("finger");
  #         dp = target->query_skill("parry");
  # 
  #     if (ap / 2 + random(ap) > dp)
  #         {
  # /*        msg += HIR "结果$p" HIR "被$P" HIR "逼得招"
  #                        "架不迭，一时无法反击！\n" NOR;
  #         target->start_busy((int)me->query_skill("finger") / 20 + 2);
  # */
  #         damage = ap / 4 + random(ap / 2);
  #         msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 0, (: final, me, target, 0 :));
  #         me->start_busy(2);
  #         me->add("neili", -200);
  # 
  #     } else
  #         {
  #         msg += CYN "可是$p" CYN "看破了$P" CYN "的变化，"
  #                        "小心招架，挡住了$P" CYN "的进击。\n" NOR;
  #         me->start_busy(1);
  #         me->add("neili", -100);
  #     }
  # 
  #     message_combatd(msg, me, target);
  #     return 1;
  # }
  # 
  # string final(object me, object target)
  # {
  #         target->set_temp("no_perform", 1);
  #         call_out("dian_end", 1 + random(5), me, target);
  #         return HIR "$n" HIR "只觉眼前寒芒一闪而过，随即全身一阵"
  #                "刺痛，几股血柱自身上射出。\n$p陡然间一提真气，"
  #                "竟发现周身力道竟似涣散一般，全然无法控制。\n" NOR;
  # }
  # 
  # void dian_end(object me, object target)
  # {
  #         if (target && target->query_temp("no_perform"))
  #         {
  #                 if (living(target))
  #                 {
  #                         message_combatd(HIC "$N" HIC "深深吸入一口"
  #                                         "气，脸色由白转红，看起来好"
  #                                         "多了。\n" NOR, target);
  # 
  #                         tell_object(target, HIY "你感到被扰乱的真气"
  #                                             "慢慢平静了下来。\n" NOR);
  #                 }
  #                 target->delete_temp("no_perform");
  #     }
  #     return;
  # }
end
