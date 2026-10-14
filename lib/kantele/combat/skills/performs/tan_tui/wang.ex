defmodule Kantele.Combat.Skills.Performs.TanTui.Wang do
  @moduledoc """
  perform「犀牛望月转回还」（source tan-tui/wang.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "tan-tui/wang"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "tan-tui")
    ap = Stats.skill(stats, "unarmed")
    damage = div(Stats.skill(stats, "unarmed"), 2)

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
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
         :ok <- check_resources(character),
         :ok <- check_weapon(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 150 -> {:error, "你的内功火候不够，难以施展「犀牛望月转回还」。\n"}
      Stats.skill(stats, "tan-tui") < 120 -> {:error, "你的十二路潭腿不够娴熟，难以施展「犀牛望月转回还」。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "unarmed") != "tan-tui" ->
        {:error, "你没有激发十二路潭腿，难以施展「犀牛望月转回还」。\n"}

      Stats.prepared_perform(stats, "unarmed") == nil or
          String.split(Stats.prepared_perform(stats, "unarmed"), "/") |> hd() != "tan-tui" ->
        {:error, "你没有准备十二路潭腿，难以施展「犀牛望月转回还」。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 300 -> {:error, "你的真气不够，难以施展「犀牛望月转回还」。\n"}
      true -> :ok
    end
  end

  defp check_weapon(character) do
    combat = character.meta.combat

    cond do
      Combat.weapon(combat) != nil -> {:error, "「犀牛望月转回还」只能空手施展。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # 无条件攻击方效果：消耗/Busy/Apply/暗器数量 + 前置广播
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 50}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 3)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}
    conn = Broadcast.publish(conn, "只见$N拔地跃起，凌空一个翻滚，陡然间双腿便如流星般向$n连续踢至。\n", n1: character.name)

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「犀牛望月转回还」只能对战斗中的对手使用。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？", n1: attacker.name, n2: character.name)
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    _stats = character.meta.stats
    ap = Map.get(data, :ap, 0)
    damage = Map.get(data, :damage, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "parry")
    hit = div(ap, 2) + Engine.rand(rng, ap) > dp
    vitals = character.meta.vitals

    if hit do
      vitals = Vitals.damage(vitals, :qi, damage)
    end

    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 50, 4)
    msg = if hit, do: "却听$n一声惨嚎，已被$P单腿正中前胸，顿时心脉受震，喷出一大口鲜血。", else: "可是$p奋力招架，终于将$P的双腿架开，没有受到任何伤害。"
    result = Messages.interpolate(msg, n1: attacker.name, n2: character.name)

    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-50"}], "assign_refs": [{"ap", "unarmed"}, {"damage", "unarmed"}, {"dp", "force"}], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);"], "level_gates": [{"force", "150"}, {"tan-tui", "120"}], "map_gates": [{"unarmed", "tan-tui"}], "prepared_gates": [{"unarmed", "tan-tui"}], "remote_damage": true, "resource_gates": [{"neili", "300"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define WANG "「" HIY "犀牛望月转回还" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         // object weapon;
  #         int damage;
  #         string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/tan-tui/wang"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(WANG "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(WANG "只能空手施展。\n");
  # 
  #         if (me->query_skill("force") < 150)
  #                 return notify_fail("你的内功火候不够，难以施展" WANG "。\n");
  # 
  #         if ((int)me->query_skill("tan-tui", 1) < 120)
  #                 return notify_fail("你的十二路潭腿不够娴熟，难以施展" WANG "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "tan-tui")
  #                 return notify_fail("你没有激发十二路潭腿，难以施展" WANG "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "tan-tui")
  #                 return notify_fail("你没有准备十二路潭腿，难以施展" WANG "。\n");
  # 
  #         if (me->query("neili") < 300)
  #                 return notify_fail("你的真气不够，难以施展" WANG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIY "只见$N" HIY "拔地跃起，凌空一个翻滚，陡然间双腿便如"
  #               "流星般向$n" HIY "连续踢至。\n" NOR;
  # 
  #     me->add("neili", -50);
  #         ap = me->query_skill("unarmed");
  #         dp = target->query_skill("force");
  #         if (ap / 2 + random(ap) > dp)
  #     {
  #         damage = me->query_skill("unarmed") / 2;
  #                 damage += random(damage / 3);
  #         me->add("neili", -100);
  # 
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 35,
  #                                            HIR "却听$n" HIR "一声惨嚎，已被$P" HIR
  #                                            "单腿正中前胸，顿时心脉受震，喷出一大"
  #                                            "口鲜血。\n" NOR);
  #         me->start_busy(3);
  #     } else
  #     {
  #         msg += CYN "可是$p" CYN "奋力招架，终于将$P"
  #                        CYN "的双腿架开，没有受到任何伤害。\n"NOR;
  #         me->start_busy(4);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
