defmodule Kantele.Combat.Skills.Performs.DabeiZhang.Bei do
  @moduledoc """
  perform「万里鲸涛大悲神诀」（source dabei-zhang/bei.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "dabei-zhang/bei"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "dabei-zhang")
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
      Stats.skill(stats, "dabei-zhang") < 220 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "force") < 300 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "dabei-zhang" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 3500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 300}
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
    Performs.feedback(attacker, 300, 1)
    result = Messages.interpolate("$n勘破不透掌中虚实，$N双掌正中$p前胸，“喀嚓喀嚓”接连断了数根肋骨。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-300"}], "assign_refs": [{"ap", "strike"}, {"dp", "force"}], "busy_lines": ["if (random(3) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(4 + random(3));"], "level_gates": [{"dabei-zhang", "220"}, {"force", "300"}], "map_gates": [{"strike", "dabei-zhang"}], "prepared_gates": [{"strike", "dabei-zhang"}], "remote_damage": true, "resource_gates": [{"max_neili", "3500"}, {"neili", "500"}], "var_gates": [{"i", "4"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define BEI "「" HIW "万里鲸涛大悲神诀" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         int i, ap, dp;
  #         // object weapon;
  # 
  #         if (userp(me) && ! me->query("can_perform/dabei-zhang/bei"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(BEI "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(BEI "只能空手使用。\n");
  # 
  #         if ((int)me->query_skill("force") < 300)
  #                 return notify_fail("你内功修为不够，难以施展" BEI "。\n");
  # 
  #         if ((int)me->query("max_neili") < 3500)
  #                 return notify_fail("你内力修为不够，难以施展" BEI "。\n");
  # 
  #         if ((int)me->query_skill("dabei-zhang", 1) < 220)
  #                 return notify_fail("你大悲神掌火候不够，难以施展" BEI "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "dabei-zhang")
  #                 return notify_fail("你没有激发大悲神掌，难以施展" BEI "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "dabei-zhang")
  #                 return notify_fail("你没有准备大悲神掌，难以施展" BEI "。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你现在真气不够，难以施展" BEI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "凄然一声长啸，施出「" HIG "万里鲸涛大悲神诀"
  #               HIW "」，双掌翻滚出漫天掌影，尽数拍向$n" HIW "。\n" NOR;
  # 
  #         ap = me->query_skill("strike") + me->query("int") * 10;
  #         dp = target->query_skill("force") + target->query("int") * 10;
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 2);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 200,
  #                                            HIR "$n" HIR "勘破不透掌中虚实，$N" HIR
  #                                            "双掌正中$p" HIR "前胸，“喀嚓喀嚓”接"
  #                                            "连断了数根肋骨。\n" NOR);
  #             message_combatd(msg, me, target);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "见$N" CYN "这掌来势非凡，不敢"
  #                        "轻易招架，当即飞身纵跃闪开。\n" NOR;
  #             message_combatd(msg, me, target);
  #         }
  # 
  #         for (i = 0; i < 4; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (random(3) == 1 && ! target->is_busy())
  #                         target->start_busy(1);
  #             COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  #         me->add("neili", -300);
  #         me->start_busy(4 + random(3));
  #         return 1;
  # }
end
