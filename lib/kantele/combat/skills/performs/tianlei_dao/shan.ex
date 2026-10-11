defmodule Kantele.Combat.Skills.Performs.TianleiDao.Shan do
  @moduledoc """
  perform「五雷连闪」（source tianlei-dao/shan.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "tianlei-dao/shan"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "tianlei-dao")
    attack_time = 5
    ap = Stats.skill(stats, "blade")
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
      Stats.skill(stats, "dodge") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "tianlei-dao") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "blade") != "tianlei-dao" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 300 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 180}
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
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 180, 1)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-180"}], "assign_refs": [{"ap", "blade"}, {"dp", "dodge"}], "busy_lines": ["if (target->is_busy())", "me->start_busy(1 + random(attack_time));"], "level_gates": [{"dodge", "180"}, {"tianlei-dao", "150"}], "map_gates": [{"blade", "tianlei-dao"}], "remote_damage": false, "resource_gates": [{"neili", "300"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define SHAN "「" HIW "五雷连闪" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg, wn;
  #     int ap, dp;
  #         int i, attack_time;
  # 
  #         if (userp(me) && ! me->query("can_perform/tianlei-dao/shan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(SHAN "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "blade")
  #         return notify_fail("你使用的武器不对，难以施展" SHAN "。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #         if ((int)me->query_skill("tianlei-dao", 1) < 150)
  #                 return notify_fail("你天雷绝刀不够娴熟，难以施展" SHAN "。\n");
  # 
  #         if (me->query_skill_mapped("blade") != "tianlei-dao")
  #                 return notify_fail("你没有激发天雷绝刀，难以施展" SHAN "。\n");
  # 
  #         if (me->query_skill("dodge") < 180)
  #                 return notify_fail("你的轻功修为不够，难以施展" SHAN "。\n");
  # 
  #         if ((int)me->query("neili") < 300)
  #                 return notify_fail("你现在的真气不够，难以施展" SHAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  # 
  #         wn = weapon->name();
  # 
  #     msg = HIY "\n$N" HIY "将手中" + wn + HIY "立于胸前，施出绝招「" HIW "五"
  #               "雷连闪" HIY "」，$N身法陡然加快，手中" + wn + HIY "连续砍出五刀，"
  #               "刀法之精妙，令人匪夷所思。\n" NOR;
  # 
  #         message_sort(msg, me, target);
  # 
  #         attack_time = 5;
  # 
  #     ap = me->query_skill("blade");
  #     dp = target->query_skill("dodge");
  # 
  #     me->add("neili", -180);
  # 
  #     if (ap / 2 + random(ap) > dp)
  #     {
  #         msg = HIG "$n" HIG "见$P" HIG "这招来势汹涌，势不可"
  #                      "挡，被$N" HIG "攻得连连后退。\n" NOR;
  #         } else
  #         {
  #                 msg = HIC "$n" HIC "见$N" HIC "这几刀来势迅猛无比，毫"
  #                       "无破绽，只得小心应付。\n" NOR;
  #         }
  # 
  #         message_combatd(msg, me, target);
  # 
  #         for (i = 0; i < attack_time; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  # 
  #                 COMBAT_D->do_attack(me, target, weapon, 15);
  #         }
  # 
  #     me->start_busy(1 + random(attack_time));
  # 
  #         return 1;
  # }
end
