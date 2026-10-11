defmodule Kantele.Combat.Skills.Performs.JieshouJiushi.Jie do
  @moduledoc """
  perform「截筋断脉」（source jieshou-jiushi/jie.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "jieshou-jiushi/jie"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jieshou-jiushi")
    skill = Stats.skill(stats, "jieshou-jiushi")
    damage = (div(skill, 2) + Engine.rand(rng, div(skill, 3)))
    ap = Stats.skill(stats, "hand")

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
      Stats.mapped(stats, "hand") != "jieshou-jiushi" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 800 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
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
          vitals = Vitals.damage(vitals, :jing, damage)
          vitals = Vitals.wound(vitals, :jing, damage)
          vitals = Vitals.damage(vitals, :qi, div((damage * 3), 2))
          vitals = Vitals.wound(vitals, :qi, div((damage * 3), 2))
    end

    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 200, 4)
    result = if hit, do: Messages.interpolate("$N身形一展，陡然跃至$n跟前，十指箕张，直锁$n要穴，正是截手九式绝技「截筋断脉」。
$n奋力格挡，可还是被$N截住腕部要穴，只觉眼前一黑，几欲晕倒。", n1: attacker.name, n2: character.name), else: Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-200"}], "assign_refs": [{"ap", "hand"}, {"dp", "parry"}, {"skill", "jieshou-jiushi"}], "busy_lines": ["me->start_busy(3);", "target->start_busy(1);", "me->start_busy(4);"], "map_gates": [{"hand", "jieshou-jiushi"}], "prepared_gates": [{"hand", "jieshou-jiushi"}], "remote_damage": true, "resource_gates": [{"max_neili", "800"}, {"neili", "200"}], "var_gates": [{"skill", "100"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define JIE "「" HIR "截筋断脉" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me)
  # {
  #         string msg;
  #         object target;
  #         int skill, ap, dp, damage;
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (userp(me) && ! me->query("can_perform/jieshou-jiushi/jie"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         skill = me->query_skill("jieshou-jiushi", 1);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(JIE "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(JIE "只能空手施展。\n");
  # 
  #         if (skill < 100)
  #                 return notify_fail("你的截手九式等级不够，难以施展" JIE "。\n");
  # 
  #         if (me->query("max_neili") < 800 )
  #                 return notify_fail("你的内力修为不足，难以施展" JIE "。\n");
  # 
  #         if (me->query("neili") < 200 )
  #                 return notify_fail("你的内力不够，难以施展" JIE "。\n");
  # 
  #         if (me->query_skill_mapped("hand") != "jieshou-jiushi")
  #                 return notify_fail("你没有激发截手九式，难以施展" JIE "。\n");
  # 
  #         if (me->query_skill_prepared("hand") != "jieshou-jiushi")
  #                 return notify_fail("你现在没有准备使用截手九式，难以施展" JIE "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "$N" HIR "身形一展，陡然跃至$n" HIR "跟前，十指箕张，直锁$n"
  #               HIR "要穴，正是截手九式绝技「截筋断脉」。\n" NOR;
  # 
  #         damage = skill / 2 + random(skill / 3);
  # 
  #         ap = me->query_skill("hand");
  #         dp = target->query_skill("parry");
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 me->add("neili", -200);
  #                 me->start_busy(3);
  # 
  #                 target->receive_damage("jing", damage);
  #                 target->receive_wound("jing", damage);
  #                 target->receive_damage("qi", damage * 3 / 2);
  #                 target->receive_wound("qi", damage * 3 / 2);
  #                 target->start_busy(1);
  # 
  #                 msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK,
  #                        damage, 10, HIR "$n" HIR "奋力格挡，可还是被$N"
  #                                    HIR "截住腕部要穴，只觉眼前一黑，"
  #                                    "几欲晕倒。\n" NOR);
  #         }
  #         else
  #         {
  #                 me->add("neili", -100);
  #                 msg += CYN "$n" CYN "见状大吃一惊，急忙向后猛退数步，"
  #                        "终于避开了$N" CYN "这一击。\n" NOR;
  #                 me->start_busy(4);
  #         }
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
