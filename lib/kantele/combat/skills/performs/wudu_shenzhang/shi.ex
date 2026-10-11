defmodule Kantele.Combat.Skills.Performs.WuduShenzhang.Shi do
  @moduledoc """
  perform「万毒噬体」（source wudu-shenzhang/shi.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "wudu-shenzhang/shi"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "wudu-shenzhang")
    ap = Stats.skill(stats, "strike")
    count = 0
    damage = (ap + Engine.rand(rng, ap))

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
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "wudu-shenzhang") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 120 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    combat = character.meta.combat
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
    stats = character.meta.stats
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "parry")
    hit = div(ap, 2) + Engine.rand(rng, ap) > dp
    vitals = character.meta.vitals
    if hit do
          vitals = Vitals.wound(vitals, :jing, (8 + Engine.rand(rng, 4)))
    end

    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 0, 2)
    result = if hit, do: Messages.interpolate("", n1: attacker.name, n2: character.name), else: Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"affect_by": ["wudu_shenzhang"], "assign_refs": [{"ap", "strike"}, {"dp", "force"}], "busy_lines": ["me->start_busy(1 + random(3));", "me->start_busy(2);", "target->start_busy(1);"], "level_gates": [{"force", "200"}, {"wudu-shenzhang", "150"}], "prepared_gates": [{"strike", "wudu-shenzhang"}], "remote_damage": true, "resource_gates": [{"neili", "120"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define SHI "「" HIR "万毒噬体" NOR "」"
  # 
  # string final(object me, object target, int damage);
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int damage, count;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/wudu-shenzhang/shi"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(SHI "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_skill("force") < 200)
  #                 return notify_fail("你的内功不够火候，难以施展" SHI "。\n");
  # 
  #         if ((int)me->query_skill("wudu-shenzhang", 1) < 150)
  #                 return notify_fail("你的五毒神掌不够娴熟，难以施展" SHI "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "wudu-shenzhang")
  #                 return notify_fail("你现在没有准备五毒神掌，难以施展" SHI "。\n");
  # 
  #         if (me->query("neili") < 120)
  #                 return notify_fail("你的真气不够，难以施展" SHI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "将体内真气运于双掌之间，只见双掌微微泛出紫光，猛"
  #               "地拍向$n。\n" NOR;
  # 
  #         ap = me->query_skill("strike");
  #         dp = target->query_skill("force");
  #         count = 0;
  # 
  #         if (target->query("shen") > 0)
  #         {
  #             count += 20;
  #             ap += ap * 10 / 100;
  #         }
  # 
  #         if (target->query("gender") != "女性")
  #         {
  #             count += 30;
  #             ap += ap * 15 / 100;
  #         }
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  # 
  #                 damage = ap + random(ap);
  #                 damage += damage * count / 100;
  #                 msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 70 + count,
  #                                           (: final, me, target, damage :));
  #                 me->add("neili", -count);
  #                 me->start_busy(1 + random(3));
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "眼明手快，侧身一跳$P"
  #                        CYN "已躲过$N这招。\n" NOR;
  #                 me->start_busy(2);
  #                 target->start_busy(1);
  #         }
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
  # 
  # string final(object me, object target, int damage)
  # {
  #         int ap;
  #         int count = 0;
  #         ap = me->query_skill("strike");
  # 
  #         if (target->query("shen") > 0)
  #         {
  #             count += 20;
  #             ap += ap * 10 / 100;
  #         }
  # 
  #         if (target->query("gender") != "女性")
  #         {
  #             count += 30;
  #             ap += ap * 15 / 100;
  #         }
  # 
  #         target->affect_by("wudu_shenzhang",
  #                 ([ "level" : me->query("jiali") + random(me->query("jiali")) + count,
  #                    "id"    : me->query("id"),
  #                    "duration" : ap / 70 + random(ap / 30) ]));
  # 
  #         target->receive_wound("jing", 8 + random(4), me);
  # 
  #         return  HIR "只见$n" HIR "被$N" HIR "一掌拍中"
  #                 "，倒退几步，却见脸色已微微泛黑。\n" NOR;
  # 
  # }
end
