defmodule Kantele.Combat.Skills.Performs.GuzhuoZhang.Zhuo do
  @moduledoc """
  perform「大巧若拙」（source guzhuo-zhang/zhuo.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "guzhuo-zhang/zhuo"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "guzhuo-zhang")
    ap = Stats.skill(stats, "strike")

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
      Stats.skill(stats, "force") < 220 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "guzhuo-zhang") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "guzhuo-zhang" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 1800 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 300 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 150}
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
    Performs.feedback(attacker, 150, 2)
    result = Messages.interpolate("$n见$N掌风凌厉，慌忙招架，顿时便失了先机。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-150"}], "assign_refs": [{"ap", "strike"}, {"dp", "parry"}], "busy_lines": ["if (target->is_busy())", "target->start_busy((int)me->query_skill("guzhuo-zhang", 1) / 22 + 2);", "me->start_busy(1);", "me->start_busy(2);"], "level_gates": [{"force", "220"}, {"guzhuo-zhang", "150"}], "map_gates": [{"strike", "guzhuo-zhang"}], "prepared_gates": [{"strike", "guzhuo-zhang"}], "remote_damage": false, "resource_gates": [{"max_neili", "1800"}, {"neili", "300"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHUO "「" WHT "大巧若拙" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/guzhuo-zhang/zhuo"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHUO "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(ZHUO "只能空手使用。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #         if ((int)me->query_skill("force") < 220)
  #                 return notify_fail("你内功修为不够，难以施展" ZHUO "。\n");
  # 
  #         if ((int)me->query("max_neili") < 1800)
  #                 return notify_fail("你内力修为不够，难以施展" ZHUO "。\n");
  # 
  #         if ((int)me->query_skill("guzhuo-zhang", 1) < 150)
  #                 return notify_fail("你古拙掌法火候不够，难以施展" ZHUO "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "guzhuo-zhang")
  #                 return notify_fail("你没有激发古拙掌法，难以施展" ZHUO "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "guzhuo-zhang")
  #                 return notify_fail("你没有准备古拙掌法，难以施展" ZHUO "。\n");
  # 
  #         if ((int)me->query("neili") < 300)
  #                 return notify_fail("你现在真气不够，难以施展" ZHUO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = WHT "$N" WHT "手腕一探，平平推出一掌，顿时掌风激进，尘沙四起，直"
  #               "刮得$n" WHT "面庞隐隐生疼。\n" NOR;
  #         me->add("neili", -150);
  # 
  #         ap = me->query_skill("strike");
  #         dp = target->query_skill("parry");
  # 
  #         if (ap / 2 + random(ap) > dp)
  # 
  #         {
  #                 msg += HIR "$n" HIR "见$N" HIR "掌风凌厉，慌"
  #                        "忙招架，顿时便失了先机。\n" NOR;
  #                 target->start_busy((int)me->query_skill("guzhuo-zhang", 1) / 22 + 2);
  #                 me->start_busy(1);
  #         } else
  #         {
  #                 msg += CYN "可是$n" CYN "不慌不忙，看破了$N"
  #                        CYN "此招虚实，并没有受到半点影响。\n" NOR;
  #                 me->start_busy(2);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
