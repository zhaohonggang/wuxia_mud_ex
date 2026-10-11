defmodule Kantele.Combat.Skills.Performs.YuezhaoGong.Shi do
  @moduledoc """
  perform「弑元诀」（source yuezhao-gong/shi.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "yuezhao-gong/shi"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "yuezhao-gong")
    ap = Stats.skill(stats, "claw")
    damage = Stats.skill(stats, "yuezhao-gong")

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
         :ok <- check_mapped(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "yuezhao-gong") < 130 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "claw") != "yuezhao-gong" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
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
    vitals = %{vitals | neili: vitals.neili - 50}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
    combat = Combat.start_busy(combat, 3)
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
    Performs.feedback(attacker, 50, 3)
    result = Messages.interpolate("$N施出越爪功「弑元诀」绝技，右手一横，直直抓向$n破绽所在。
只听$n一声惨嚎，竟被$N的五指抓破气门，鲜血登时四处飞溅！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-50"}], "assign_refs": [{"ap", "claw"}, {"damage", "yuezhao-gong"}, {"dp", "dodge"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "level_gates": [{"force", "200"}, {"yuezhao-gong", "130"}], "map_gates": [{"claw", "yuezhao-gong"}], "prepared_gates": [{"claw", "yuezhao-gong"}], "remote_damage": true, "resource_gates": [{"neili", "300"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define SHI "「" HIR "弑元诀" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     int damage;
  #     string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/yuezhao-gong/shi"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(SHI "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(weapon = me->query_temp("weapon")))
  #                 return notify_fail(SHI "只能空手施展。\n");
  # 
  #         if (me->query_skill("force") < 200)
  #                 return notify_fail("你的内功火候不够，难以施展" SHI "。\n");
  # 
  #         if ((int)me->query_skill("yuezhao-gong", 1) < 130)
  #                 return notify_fail("你越爪功等级不够，难以施展" SHI "。\n");
  # 
  #         if (me->query_skill_mapped("claw") != "yuezhao-gong")
  #                 return notify_fail("你没有激发越爪功，难以施展" SHI "。\n");
  # 
  #         if (me->query_skill_prepared("claw") != "yuezhao-gong")
  #                 return notify_fail("你没有准备越爪功，难以施展" SHI "。\n");
  # 
  #         if (me->query("neili") < 300)
  #                 return notify_fail("你现在的真气不足，难以施展" SHI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = WHT "$N" WHT "施出越爪功「" HIR "弑元诀" NOR + WHT "」绝技，右"
  #               "手一横，直直抓向$n" WHT "破绽所在。\n" NOR;
  # 
  #     me->add("neili", -100);
  #         ap = me->query_skill("claw");
  #         dp = target->query_skill("dodge");
  #         if (ap / 2 + random(ap) > dp)
  #     {
  #         damage = me->query_skill("yuezhao-gong", 1);
  #                 damage += random(damage);
  #         me->add("neili", -50);
  # 
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 55,
  #                                    HIR "只听$n" HIR "一声惨嚎，竟被$N" HIR
  #                                            "的五指抓破气门，鲜血登时四处飞溅！\n" NOR);
  #         me->start_busy(2);
  #     } else
  #     {
  #         msg += HIC "可是$p" HIC "身手敏捷，身形急转，巧妙的躲过了$P"
  #                        HIC "的攻击。\n"NOR;
  #         me->start_busy(3);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
