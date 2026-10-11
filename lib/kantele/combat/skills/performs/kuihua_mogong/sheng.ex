defmodule Kantele.Combat.Skills.Performs.KuihuaMogong.Sheng do
  @moduledoc """
  perform「无声无息」（source kuihua-mogong/sheng.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "kuihua-mogong/sheng"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "kuihua-mogong")

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
      Stats.skill(stats, "kuihua-mogong") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "dodge") != "kuihua-mogong" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 3000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 120}
    vitals = %{vitals | neili: vitals.neili - 80}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1)
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
    Performs.feedback(attacker, 80, 1)
    result = Messages.interpolate("$N身子忽进忽退，身形诡秘异常，在$n身边飘忽不定。
结果$p只能紧守门户，不敢妄自出击！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-120"}, {"neili", "-80"}], "assign_refs": [{"ap", "kuihua-mogong"}, {"dp", "dodge"}], "busy_lines": ["if (target->is_busy())", "target->start_busy(ap / 30 + 2);", "me->start_busy(1);", "me->start_busy(1 + random(2));"], "level_gates": [{"kuihua-mogong", "200"}], "map_gates": [{"dodge", "kuihua-mogong"}], "remote_damage": false, "resource_gates": [{"max_neili", "3000"}, {"neili", "200"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // sheng.c 无声无息
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define XI "「" HIW "无声无息" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #     string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/kuihua-mogong/sheng"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail(XI "只能对战斗中的对手使用。\n");
  # 
  #     if (target->is_busy())
  #         return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
  # 
  #     if ((int)me->query_skill("kuihua-mogong", 1) < 200)
  #         return notify_fail("你的葵花魔功不够深厚，不会使用" XI "。\n");
  # 
  #         if ((int)me->query("max_neili") < 3000)
  #                 return notify_fail("你的内力修为不足，难以施展" XI "。\n");
  # 
  #     if (me->query("neili") < 200)
  #         return notify_fail("你的真气不够，无法施展" XI "！\n");
  # 
  #         if (me->query_skill_mapped("dodge") != "kuihua-mogong")
  #                 return notify_fail("你还没有激发葵花魔功为轻功，无法施展" XI "。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIR "$N" HIR "身子忽进忽退，身形诡秘异常，在$n"
  #               HIR "身边飘忽不定。\n" NOR;
  # 
  #         ap = me->query_skill("kuihua-mogong", 1) * 3 / 2 +
  #              me->query_skill("martial-cognize", 1);
  #         dp = target->query_skill("dodge") +
  #              target->query_skill("martial-cognize", 1);
  # 
  #     if (ap * 3 / 5 + random(ap) > dp)
  #         {
  #         msg += HIR "结果$p" HIR "只能紧守门户，不敢妄自出击！\n" NOR;
  #         target->start_busy(ap / 30 + 2);
  #                 me->add("neili", -120);
  #                 me->start_busy(1);
  #     } else
  #         {
  #         msg += CYN "可是$p" CYN "看破了$P" CYN "的身法，并没"
  #                        "有受到任何影响。\n" NOR;
  #         me->start_busy(1 + random(2));
  #                 me->add("neili", -80);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
