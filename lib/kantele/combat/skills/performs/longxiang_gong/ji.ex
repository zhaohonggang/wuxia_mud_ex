defmodule Kantele.Combat.Skills.Performs.LongxiangGong.Ji do
  @moduledoc """
  perform「般若极」（source longxiang-gong/ji.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "longxiang-gong/ji"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "longxiang-gong")
    layer = 13

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
      Stats.skill(stats, "longxiang-gong") < 300 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "force") != "longxiang-gong" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "unarmed") != "longxiang-gong" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 5000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 800 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 400}
    vitals = %{vitals | neili: vitals.neili - 600}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
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
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 600, 4)
    result = Messages.interpolate("$N运转龙象般若功第层功力，双拳携着『十龙十象』之力朝$n崩击
而出，拳锋过处，竟卷起万里尘埃，正是密宗绝学「般若极」。
$n不及闪避，顿被$N双拳击个正中，般若罡劲破体而入，尽伤三焦六脉。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-400"}, {"neili", "-600"}], "apply_adds": ["armor"], "assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}, {"layer", "longxiang-gong"}], "busy_lines": ["me->start_busy(4);", "me->start_busy(4);"], "level_gates": [{"longxiang-gong", "300"}], "map_gates": [{"force", "longxiang-gong"}, {"unarmed", "longxiang-gong"}], "prepared_gates": [{"unarmed", "longxiang-gong"}], "remote_damage": true, "resource_gates": [{"max_neili", "5000"}, {"neili", "800"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define JI "「" HIY "般若极" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  # //      object weapon;
  #         int ap, dp, shd, jia, layer, damage;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/longxiang-gong/ji"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(JI "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(JI "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("longxiang-gong", 1) < 300)
  #                 return notify_fail("你的龙象般若功修为不够，难以施展" JI "。\n");
  # 
  #         if (me->query("max_neili") < 5000)
  #                 return notify_fail("你的内力修为不足，难以施展" JI "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "longxiang-gong")
  #                 return notify_fail("你没有激发龙象般若功为拳脚，难以施展" JI "。\n");
  # 
  #         if (me->query_skill_mapped("force") != "longxiang-gong")
  #                 return notify_fail("你没有激发龙象般若功为内功，难以施展" JI "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "longxiang-gong")
  #                 return notify_fail("你没有准备使用龙象般若功，难以施展" JI "。\n");
  # 
  #         if (me->query("neili") < 800)
  #                 return notify_fail("你现在的真气不足，难以施展" JI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         layer = me->query_skill("longxiang-gong", 1) / 30;
  # 
  #         if (layer > 13) layer = 13;
  # 
  #         msg = HIY "$N" HIY "运转龙象般若功第" + chinese_number(layer) + "层"
  #               "功力，双拳携着『" HIR "十龙十象" HIY "』之力朝$n" HIY "崩击"
  #               "\n而出，拳锋过处，竟卷起万里尘埃，正是密宗绝学「" HIW "般若"
  #               "极" HIY "」。\n" NOR;
  # 
  #         ap = me->query_skill("unarmed") +
  #              me->query_skill("force");
  # 
  #         dp = target->query_skill("parry") +
  #              target->query_skill("force");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 if (target->query_temp("shield"))
  #         {
  #                     shd = target->query_temp("apply/armor");
  # 
  #                     target->add_temp("apply/armor", -shd);
  #                     target->delete_temp("shield");
  # 
  #                     msg += HIW "$N" HIW "罡气涌至，竟然激起层层气浪，顿时将$n"
  #                                HIW "的护体真气摧毁得荡然无存！\n" NOR;
  #         }
  #                 jia = me->query("jiali");
  #                 damage = ap / 2 + random(jia * 5);
  # 
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80,
  #                                                HIR "$n" HIR "不及闪避，顿被$N" HIR
  #                                                "双拳击个正中，般若罡劲破体而入，尽"
  #                                                "伤三焦六脉。\n" NOR);
  # 
  #                 me->start_busy(4);
  #                 me->add("neili", -600);
  #         } else
  #         {
  #                 me->start_busy(4);
  #                 me->add("neili", -400);
  #                 msg += CYN "可是$p" CYN "识破了$P"
  #                        CYN "这一招，斜斜一跃避开。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
