defmodule Kantele.Combat.Skills.Performs.SanwuShou.Zhi do
  @moduledoc """
  perform「无所不至」（source sanwu-shou/zhi.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "sanwu-shou/zhi"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "sanwu-shou")
    ap = Stats.skill(stats, "whip")
    attack_time = 7
    count = div(ap, 15)
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
      Stats.skill(stats, "sanwu-shou") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "whip") != "sanwu-shou" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 140 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
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
    result = Messages.interpolate("结果$n被$N攻了个措手不及，$n慌忙招架，心中叫苦。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"apply_adds": ["attack"], "assign_refs": [{"ap", "whip"}, {"dp", "dodge"}], "busy_lines": ["me->start_busy(1 + random(attack_time));"], "level_gates": [{"sanwu-shou", "100"}], "map_gates": [{"whip", "sanwu-shou"}], "remote_damage": false, "resource_gates": [{"neili", "140"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHI "「" HIW "无所不至" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg;
  #     int ap, dp;
  #     int count;
  #     int i, attack_time;
  # 
  #     if (userp(me) && ! me->query("can_perform/sanwu-shou/zhi"))
  #             return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #             return notify_fail(ZHI "只能对战斗中的对手使用。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon"))
  #             || (string)weapon->query("skill_type") != "whip")
  #             return notify_fail("你所使用的武器不对，难以施展" ZHI "。\n");
  # 
  #     if ((int)me->query_skill("sanwu-shou", 1) < 100)
  #             return notify_fail("你三无三不手不够娴熟，难以施展" ZHI "。\n");
  # 
  #     if (me->query_skill_mapped("whip") != "sanwu-shou")
  #             return notify_fail("你没有激发三无三不手，难以施展" ZHI "。\n");
  # 
  #     if (me->query("neili") < 140)
  #             return notify_fail("你现在的真气不够，难以施展" ZHI "。\n");
  # 
  #     if (! living(target))
  #             return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIM "\n$N" HIM "长啸一声，腾空而起，施出绝招 「" HIW "无"
  #               "所不至" HIM "」手中" + weapon->name() + HIM "化出无数"
  #               "光点，犹如满天花雨般洒向$n全身各处" HIM "。" NOR;
  # 
  #     message_sort(msg, me, target);
  # 
  #     ap = me->query_skill("whip");
  #     dp = target->query_skill("dodge");
  #     attack_time = 4;
  # 
  #     if (target->query("shen") > 0)
  #         ap += ap * 10 / 100;
  # 
  #     if (target->query("gender") != "女性")
  #     {
  #         attack_time += 1;
  #         ap += ap * 15 / 100;
  #     }
  # 
  #     if (ap / 2 + random(ap * 2) > dp)
  #     {
  #                 msg = HIR "结果$n" HIR "被$N" HIR "攻了个措手不及，$n"
  #                       HIR "慌忙招架，心中叫苦。\n" NOR;
  #                 count = ap / 8;
  #                 attack_time += random(ap / 45);
  #     } else
  #     {
  #                 msg= HIC "$n" HIC "见$N" HIC "这几鞭招式凌厉，凶猛异"
  #                      "常，只得苦苦招架。\n" NOR;
  #                 count = ap / 15;
  #     }
  #     me->add_temp("apply/attack", count);
  #     message_combatd(msg, me, target);
  # 
  #     if (attack_time > 7)
  #             attack_time = 7;
  # 
  #     me->add("neili", -attack_time * 20);
  # 
  #     for (i = 0; i < attack_time; i++)
  #     {
  #         if (! me->is_fighting(target))
  #             break;
  # 
  #         COMBAT_D->do_attack(me, target, weapon, 0);
  #     }
  #     me->add_temp("apply/attack", -count);
  #     me->start_busy(1 + random(attack_time));
  # 
  #     return 1;
  # }
end
