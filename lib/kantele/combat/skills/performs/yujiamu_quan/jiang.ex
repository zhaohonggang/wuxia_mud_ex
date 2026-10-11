defmodule Kantele.Combat.Skills.Performs.YujiamuQuan.Jiang do
  @moduledoc """
  perform「修罗降世」（source yujiamu-quan/jiang.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "yujiamu-quan/jiang"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "yujiamu-quan")
    skill = Stats.skill(stats, "yujiamu-quan")
    ap = (div(Stats.skill(stats, "cuff"), 2) + skill)
    dp = 1
    damage = ((10 + div(skill, 3)) + Engine.rand(rng, div(skill, 2)))

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
    with :ok <- check_mapped(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "cuff") != "yujiamu-quan" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 180 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    vitals = %{vitals | neili: vitals.neili - 40}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1)
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
    Performs.feedback(attacker, 40, 3)
    result = Messages.interpolate("$N目睚俱裂，一声爆喝，全身骨骼劈啪作响，拳头如闪电般击向$n的要害！
$N大喝一声，面色赤红，全身骨骼劈啪作响，拳头如闪电般击向$n的要害！
结果$p无法抵挡$P这雷霆一击，登时被打退数步，摇晃不定。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-40"}], "assign_refs": [{"ap", "cuff"}, {"dp", "dodge"}, {"skill", "yujiamu-quan"}], "busy_lines": ["me->start_busy(1);", "me->start_busy(3);"], "map_gates": [{"cuff", "yujiamu-quan"}], "prepared_gates": [{"cuff", "yujiamu-quan"}], "remote_damage": true, "resource_gates": [{"neili", "180"}], "var_gates": [{"dp", "1"}, {"skill", "100"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define JIANG "「" HIR "修罗降世" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int angry;
  #         string msg;
  #         int skill, ap, dp, damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/yujiamu-quan/jiang"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! me->is_fighting(target))
  #                 return notify_fail(JIANG "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(JIANG "只能空手施展。\n");
  # 
  #         skill = me->query_skill("yujiamu-quan", 1);
  # 
  #         if (skill < 100)
  #                 return notify_fail("你金刚瑜迦母拳修为不够，难以施展" JIANG "。\n");
  # 
  #         if (me->query_skill_mapped("cuff") != "yujiamu-quan")
  #                 return notify_fail("你没有激发金刚瑜迦母拳，难以施展" JIANG "。\n");
  # 
  #         if (me->query_skill_prepared("cuff") != "yujiamu-quan")
  #                 return notify_fail("你没有准备金刚瑜迦母拳，难以施展" JIANG "。\n");
  # 
  #         if (me->query("neili") < 180)
  #                 return notify_fail("你目前的真气不足，难以施展" JIANG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         if (angry = me->query("qi") < me->query("max_qi") / 2)
  #                 msg = HIR "$N" HIR "目睚俱裂，一声爆喝，全身骨骼劈啪作响，拳"
  #                       "头如闪电般击向$n" HIR "的要害！\n" NOR;
  #         else
  #                 msg = HIR "$N" HIR "大喝一声，面色赤红，全身骨骼劈啪作响，拳"
  #                       "头如闪电般击向$n" HIR "的要害！\n" NOR;
  # 
  #         ap = me->query_skill("cuff", 1) / 2 + skill;
  #         dp = target->query_skill("dodge");
  #         if (dp < 1) dp = 1;
  #         if (ap / 2 + random(ap * 4 / 5) > dp)
  #         {
  #                 me->add("neili", -100);
  #                 me->start_busy(1);
  #                 damage = 10 + skill / 3 + random(skill / 2);
  #                 if (angry) damage += random(damage / 2);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 35,
  #                                            HIR "结果$p" HIR "无法抵挡$P" HIR "这雷"
  #                                            "霆一击，登时被打退数步，摇晃不定。\n" NOR);
  #         } else
  #         {
  #                 me->add("neili",-40);
  #                 msg += CYN "可是$p" CYN "并未被这气势所慑，轻移"
  #                        "脚步，躲开了$P" CYN "的攻击。\n" NOR;
  #                 me->start_busy(3);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
