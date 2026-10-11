defmodule Kantele.Combat.Skills.Performs.XianglongZhang.Zhen do
  @moduledoc """
  perform「震惊百里」（source xianglong-zhang/zhen.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "xianglong-zhang/zhen"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "xianglong-zhang")

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
      Stats.skill(stats, "force") < 300 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "xianglong-zhang") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "xianglong-zhang" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 3000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 200}
    vitals = %{vitals | neili: vitals.neili - 400}
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
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 400, 4)
    result = Messages.interpolate("$n只觉一股罡风涌至，根本不及躲避，$N双掌正中前胸，鲜血如箭般喷出。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}, {"neili", "-400"}], "assign_refs": [{"ap", "strike"}, {"dp", "dodge"}], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);"], "level_gates": [{"force", "300"}, {"xianglong-zhang", "150"}], "map_gates": [{"strike", "xianglong-zhang"}], "prepared_gates": [{"strike", "xianglong-zhang"}], "remote_damage": true, "resource_gates": [{"max_neili", "3000"}, {"neili", "500"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHEN "「" HIW "震惊百里" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/xianglong-zhang/zhen"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHEN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(ZHEN "只能空手使用。\n");
  # 
  #         if ((int)me->query_skill("xianglong-zhang", 1) < 150)
  #                 return notify_fail("你降龙十八掌火候不够，难以施展" ZHEN "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "xianglong-zhang")
  #                 return notify_fail("你没有激发降龙十八掌，难以施展" ZHEN "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "xianglong-zhang")
  #                 return notify_fail("你没有准备降龙十八掌，难以施展" ZHEN "。\n");
  # 
  #         if ((int)me->query_skill("force") < 300)
  #                 return notify_fail("你的内功修为不够，难以施展" ZHEN "。\n");
  # 
  #         if ((int)me->query("max_neili") < 3000)
  #                 return notify_fail("你的内力修为不够，难以施展" ZHEN "。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你现在的真气不足，难以施展" ZHEN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = WHT "$N" WHT "施出降龙十八掌之「" HIW "震惊百里" NOR +
  #               WHT "」，全身真气鼓动，双掌如排山倒海般压向$n" WHT "。\n"NOR;  
  # 
  #         ap = me->query_skill("strike") + me->query("str") * 10;
  #         dp = target->query_skill("dodge") + target->query("dex") * 10;
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         { 
  #                 damage = ap + random(ap / 2);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80,
  #                                            HIR "$n" HIR "只觉一股罡风涌至，根本不"
  #                                            "及躲避，$N" HIR "双掌正中前胸，鲜血如"
  #                                            "箭般喷出。\n" NOR);
  #                 me->add("neili", -400);
  #                 me->start_busy(3);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "眼见$N" CYN "来势汹涌，丝毫不"
  #                        "敢小觑，急忙闪在了一旁。\n" NOR;
  #                 me->add("neili", -200);
  #                 me->start_busy(4);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
