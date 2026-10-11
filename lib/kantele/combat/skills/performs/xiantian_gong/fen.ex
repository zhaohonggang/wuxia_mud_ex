defmodule Kantele.Combat.Skills.Performs.XiantianGong.Fen do
  @moduledoc """
  perform「五阴焚灭」（source xiantian-gong/fen.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "xiantian-gong/fen"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "xiantian-gong")
    damage = (-1)

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
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
      Stats.skill(stats, "xiantian-gong") < 240 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "force") != "xiantian-gong" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "unarmed") != "xiantian-gong" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 4000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 600 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 120}
    vitals = %{vitals | neili: vitals.neili - 500}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
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
    Performs.feedback(attacker, 500, 4)
    result = Messages.interpolate("$n正直诧异间，$N一掌已正中$p脑门，先天真气登时贯脑而入。
( $n受伤过重，已经有如风中残烛，随时都可能断气。)
结果$N这掌正中$n胸口，先天真气登时透体而入，接连喷出数口鲜血。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-120"}, {"neili", "-500"}], "assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);", "me->start_busy(4);"], "level_gates": [{"xiantian-gong", "240"}], "map_gates": [{"force", "xiantian-gong"}, {"unarmed", "xiantian-gong"}], "prepared_gates": [{"unarmed", "xiantian-gong"}], "remote_damage": true, "resource_gates": [{"max_neili", "4000"}, {"neili", "600"}], "var_gates": [{"damage", "0"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define FEN "「" HIW "五阴焚灭" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         // object weapon;
  #         int ap, dp, damage;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/xiantian-gong/fen"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(FEN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(FEN "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("xiantian-gong", 1) < 240)
  #                 return notify_fail("你的先天功修为不够，难以施展" FEN "。\n");
  # 
  #         if (me->query("max_neili") < 4000)
  #                 return notify_fail("你的内力修为不足，难以施展" FEN "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "xiantian-gong")
  #                 return notify_fail("你没有激发先天功为拳脚，难以施展" FEN "。\n");
  # 
  #         if (me->query_skill_mapped("force") != "xiantian-gong")
  #                 return notify_fail("你没有激发先天功为内功，难以施展" FEN "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "xiantian-gong")
  #                 return notify_fail("你没有准备使用先天功，难以施展" FEN "。\n");
  # 
  #         if (me->query("neili") < 600)
  #                 return notify_fail("你现在的真气不足，难以施展" FEN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "体内先天真气急速运转，单掌一抖，掌心顿时升起一个气"
  #               "团，朝$n" HIW "猛拍而去。\n" NOR;
  # 
  #         ap = me->query_skill("unarmed") +
  #              me->query_skill("force");
  # 
  #         dp = target->query_skill("parry") +
  #              target->query_skill("force");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = 0;
  #                 if (me->query("max_neili") > target->query("max_neili") * 2)
  #                 {
  #                     me->start_busy(2);
  #                         msg += HIR "$n" HIR "正直诧异间，$N" HIR "一掌已正中$p"
  #                                HIR "脑门，先天真气登时贯脑而入。\n" NOR "( $n"
  #                                RED "受伤过重，已经有如风中残烛，随时都可能断气"
  #                                "。" NOR ")\n";
  #                         damage = -1;
  #                 } else
  #         {
  #                     me->start_busy(3);
  #                     damage = ap / 2 + random(ap);
  #                     me->add("neili", -500);
  #                     msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 90,
  #                                                HIR "结果$N" HIR "这掌正中$n" HIR "胸"
  #                                                    "口，先天真气登时透体而入，接连喷出数"
  #                                                    "口鲜血。\n" NOR);
  #         }
  #         } else
  #         {
  #                 me->start_busy(4);
  #                 me->add("neili", -120);
  #                 msg += CYN "可是$p" CYN "识破了$P"
  #                        CYN "这一招，斜斜一跃躲避开来。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         if (damage < 0)
  #                 target->die(me);
  # 
  #         return 1;
  # }
end
