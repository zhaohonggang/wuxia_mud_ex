defmodule Kantele.Combat.Skills.Performs.YingzhuaGong.Chumo do
  @moduledoc """
  perform「chumo」（source yingzhua-gong/chumo.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "yingzhua-gong/chumo"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "yingzhua-gong")
    skill = Stats.skill(stats, "yingzhua-gong")
    ap = (Stats.skill(stats, "force") + Stats.skill(stats, "claw"))
    damage = (div(ap, 2) + Engine.rand(rng, div(ap, 4)))

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
    with :ok <- check_mapped(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "claw") != "yingzhua-gong" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 250 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 200}
    vitals = %{vitals | neili: vitals.neili - 40}
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
    Performs.feedback(attacker, 40, 3)
    result = Messages.interpolate("不知怎么的，$p却偏偏躲不开$P这一抓，结果被抓了个正中，不由得闷哼一声，退了几步。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}, {"neili", "-40"}], "assign_refs": [{"ap", "force"}, {"dp", "parry"}, {"skill", "yingzhua-gong"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "map_gates": [{"claw", "yingzhua-gong"}], "remote_damage": true, "resource_gates": [{"neili", "250"}], "var_gates": [{"skill", "135"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // chumo.c 荡妖除魔
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me)
  # {
  #     string msg;
  #     object target;
  #     int skill, ap, dp, damage;
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail("「荡妖除魔」只能在战斗中对对手使用。\n");
  # 
  #     skill = me->query_skill("yingzhua-gong", 1);
  # 
  #     if (skill < 135)
  #         return notify_fail("你的鹰爪功等级不够，不会使用「荡妖除魔」！\n");
  # 
  #     if (me->query("neili") < 250)
  #         return notify_fail("你的真气不够，无法运用「荡妖除魔」！\n");
  # 
  #     if (me->query_skill_mapped("claw") != "yingzhua-gong")
  #         return notify_fail("你没有激发鹰爪功，无法使用「荡妖除魔」！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIY "$N" HIY "微微一笑，双掌缓缓的向$n" HIY "抓出，此招"
  #           "看上去也平平无奇，并无多少精妙变化！\n" NOR;
  # 
  #     ap = me->query_skill("force") + me->query_skill("claw");
  #     dp = target->query_skill("parry") + target->query_skill("dodge");
  #     if (ap / 2 + random(ap) > dp)
  #     {
  #         me->add("neili", -200);
  #         damage = ap / 2 + random(ap / 4);
  #         msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 45,
  #                                            HIR "不知怎么的，$p" HIR "却偏偏躲不开$P"
  #                                            HIR "这一抓，结果被抓了个正中，不由得闷"
  #                                            "哼一声，退了几步。\n" NOR);
  #         me->start_busy(2);
  #     } else
  #     {
  #         msg += CYN "可是$p" CYN "没有轻视$P" CYN
  #                        "这一抓，连忙招架，顺势跃开，没有被$P"
  #                        CYN "得手。\n" NOR;
  #         me->add("neili",-40);
  #         me->start_busy(3);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
