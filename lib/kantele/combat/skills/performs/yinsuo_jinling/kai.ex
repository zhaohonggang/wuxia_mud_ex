defmodule Kantele.Combat.Skills.Performs.YinsuoJinling.Kai do
  @moduledoc """
  perform「开天辟地」（source yinsuo-jinling/kai.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "yinsuo-jinling/kai"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "yinsuo-jinling")
    ap = Stats.skill(stats, "whip")

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
      Stats.skill(stats, "force") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "yinsuo-jinling") < 140 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "whip") != "yinsuo-jinling" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
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
    vitals = %{vitals | neili: vitals.neili - 100}
    vitals = %{vitals | neili: vitals.neili - 220}
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
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 220, 4)
    result = Messages.interpolate("但见$N攻势如洪，气势磅礴，$n心中略微一惊，惨叫一声，顿时鲜血淋淋。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-220"}], "assign_refs": [{"ap", "whip"}, {"damage", "yinsuo-jinling"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(2 + random(2));", "me->start_busy(4);"], "level_gates": [{"force", "180"}, {"yinsuo-jinling", "140"}], "map_gates": [{"whip", "yinsuo-jinling"}], "remote_damage": true, "resource_gates": [{"neili", "300"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define KAI "「" HIY "开天辟地" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         int ap, dp;
  #         object weapon;
  # 
  #         if (userp(me) && ! me->query("can_perform/yinsuo-jinling/kai"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(KAI "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "whip")
  #                 return notify_fail("你所使用的武器不对，难以施展" KAI "。\n");
  # 
  #         if ((int)me->query_skill("yinsuo-jinling", 1) < 140)
  #                 return notify_fail("你银索金铃够娴熟，难以施展" KAI "。\n");
  # 
  #         if (me->query_skill_mapped("whip") != "yinsuo-jinling")
  #                 return notify_fail("你没有激发银索金铃，难以施展" KAI "。\n");
  # 
  #         if (me->query_skill("force") < 180)
  #                 return notify_fail("你的内功修为不够，难以施展" KAI "。\n");
  # 
  #         if ((int)me->query("neili") < 300)
  #                 return notify_fail("你现在的真气不够，难以施展" KAI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         ap = me->query_skill("whip");
  #         dp = target->query_skill("parry");
  # 
  #         msg = HIW "\n$N" HIW "长啸一声，疼空而起，施出绝招「" HIY "开天辟地" HIW
  #               "」，手中" +weapon->name() + HIW "犹如长龙般龙吟不定，临空而下，罩"
  #               "向$n。" NOR;
  # 
  #         message_sort(msg, me, target);
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = (int)me->query_skill("yinsuo-jinling", 1);
  #                 damage += random(damage / 2);
  # 
  #                 msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
  #                                            HIR "\n但见$N" HIR "攻势如洪，气势磅礴，"
  #                                            "$n" HIR "心中略微一惊，惨叫一声，顿"
  #                                            "时鲜血淋淋。\n" NOR);
  # 
  #                 me->start_busy(2 + random(2));
  #                 me->add("neili", -220);
  #         } else
  #         {
  #                 msg = CYN "\n$n" CYN "见$N" CYN "这招袭来，内力"
  #                       "充盈，只得向后一纵，才躲过这一鞭。\n" NOR;
  # 
  #                 me->start_busy(4);
  #                 me->add("neili", -100);
  #         }
  #         message_vision(msg, me, target);
  #         return 1;
  # }
end
