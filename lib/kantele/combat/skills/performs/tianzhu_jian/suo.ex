defmodule Kantele.Combat.Skills.Performs.TianzhuJian.Suo do
  @moduledoc """
  perform「烟云锁身」（source tianzhu-jian/suo.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "tianzhu-jian/suo"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "tianzhu-jian")
    ap = Stats.skill(stats, "tianzhu-jian")

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
      Stats.skill(stats, "dodge") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "tianzhu-jian") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "tianzhu-jian" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
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
    result = Messages.interpolate("$n只见眼前白芒暴涨，登时右手一轻，竟脱手飞出。

$n惊慌不定，顿时乱了阵脚，竟被困于$N的剑光当中。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-200"}], "assign_refs": [{"ap", "tianzhu-jian"}, {"dp", "parry"}], "busy_lines": ["if (target->is_busy())", "me->start_busy(2);", "target->start_busy(3);", "me->start_busy(1);", "target->start_busy(ap / 25 + 1);"], "level_gates": [{"dodge", "150"}, {"tianzhu-jian", "120"}], "map_gates": [{"sword", "tianzhu-jian"}], "remote_damage": false, "resource_gates": [{"neili", "200"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define SUO "「" HIW "烟云锁身" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg, wp, wp2;
  #         object weapon, weapon2;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/tianzhu-jian/suo"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(SUO "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #         return notify_fail("你使用的武器不对，难以施展" SUO "。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #         if ((int)me->query_skill("tianzhu-jian", 1) < 120)
  #                 return notify_fail("你天柱剑法不够娴熟，难以施展" SUO "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "tianzhu-jian")
  #                 return notify_fail("你没有激发天柱剑法，难以施展" SUO "。\n");
  # 
  #         if (me->query_skill("dodge") < 150)
  #                 return notify_fail("你的轻功修为不够，难以施展" SUO "。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不够，难以施展" SUO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         wp = weapon->name();
  #         ap = me->query_skill("tianzhu-jian", 1);
  #         dp = target->query_skill("parry", 1);
  # 
  #         if (me->query("max_neili") > target->query("max_neili") * 3 / 2
  #            && objectp(weapon2 = target->query_temp("weapon")))
  #         {
  #                 wp2 = weapon2->name();
  # 
  #         msg = HIW "\n$N" HIW "剑法陡然变快，施展出「烟云锁身剑」，手中" +
  #                       wp + HIW "幻作一道白芒，撩向$n" HIW "所持的" + wp2 + HIW
  #                       "。" NOR;
  # 
  #                 message_sort(msg, me, target);
  # 
  #                me->start_busy(2);
  #                me->add("neili", -200);
  # 
  #             if (random(ap) > dp / 2)
  #             {
  #                     msg = HIR "$n" HIR "只见眼前白芒暴涨，登时右手一轻，"
  #                               + wp2 + HIR "竟脱手飞出。\n" NOR;
  # 
  #                     target->start_busy(3);
  #                         weapon2->move(environment(target));
  #             } else
  #         {
  #                 msg += CYN "可是$n" CYN "看破$N" CYN "剑法中的虚招，镇"
  #                                "定自如，从容应对。\n" NOR;
  #             }
  #     } else
  #     {
  #         msg = HIC "\n$N" HIC "剑法陡然变快，施展出「" HIW "烟云锁身剑"
  #                       HIC "」，手中" + wp + HIC "剑光夺目，欲将$n" HIC "笼罩在"
  #                       "剑光之中。" NOR;
  # 
  #                me->start_busy(1);
  #             me->add("neili", -100);
  # 
  #             if (random(ap) > dp / 2)
  #             {
  #                     msg += HIR "\n$n" HIR "惊慌不定，顿时乱了阵脚，竟被困于$N"
  #                                HIR "的剑光当中。" NOR;
  # 
  #                         target->start_busy(ap / 25 + 1);
  #             } else
  #         {
  #                 msg += CYN "\n可是$n" CYN "看破$N" CYN "剑法中的虚招，镇"
  #                                "定自如，从容应对。" NOR;
  #             }
  #     }
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
