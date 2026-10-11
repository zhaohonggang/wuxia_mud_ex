defmodule Kantele.Combat.Skills.Performs.LiuyangZhang.Zhong do
  @moduledoc """
  perform「生死符」（source liuyang-zhang/zhong.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "liuyang-zhang/zhong"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "liuyang-zhang")
    ap = ((Stats.skill(stats, "force") + Stats.skill(stats, "throwing")) + Stats.skill(stats, "medical"))
    damage = (div(ap, 2) + Engine.rand(rng, div(ap, 2)))

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
      Stats.skill(stats, "liuyang-zhang") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "liuyang-zhang" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "throwing") != "liuyang-zhang" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 100 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    combat = character.meta.combat
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
    stats = character.meta.stats
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "parry")
    hit = div(ap, 2) + Engine.rand(rng, ap) > dp
    vitals = character.meta.vitals
    if hit do
          vitals = Vitals.wound(vitals, :jing, (10 + Engine.rand(rng, 5)))
    end

    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 0, 3)
    result = if hit, do: Messages.interpolate("只见$n被$N一掌拍中，紧接着身子一颤，$P那枚生死符已种入$p体内！", n1: attacker.name, n2: character.name), else: Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"affect_by": ["ss_poison"], "assign_refs": [{"ap", "force"}, {"dp", "force"}], "busy_lines": ["me->start_busy(1 + random(4));", "me->start_busy(3);", "target->start_busy(1);"], "level_gates": [{"force", "200"}, {"liuyang-zhang", "150"}], "map_gates": [{"strike", "liuyang-zhang"}, {"throwing", "liuyang-zhang"}], "prepared_gates": [{"strike", "liuyang-zhang"}], "remote_damage": true, "resource_gates": [{"neili", "100"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHONG "「" HIW "生死符" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int damage;
  #         int ap, dp, flvl;
  # 
  #         if (userp(me) && ! me->query("can_perform/liuyang-zhang/zhong"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHONG "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_skill("force") < 200)
  #                 return notify_fail("你的内功不够火候，难以施展" ZHONG "。\n");
  # 
  #         if ((int)me->query_skill("liuyang-zhang", 1) < 150)
  #                 return notify_fail("你的天山六阳掌不够娴熟，难以施展" ZHONG "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "liuyang-zhang")
  #                 return notify_fail("你没有激发掌法天山六阳掌，难以施展" ZHONG "。\n");
  # 
  #         if (me->query_skill_mapped("throwing") != "liuyang-zhang")
  #                 return notify_fail("你没有激发暗器天山六阳掌，难以施展" ZHONG "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "liuyang-zhang")
  #                 return notify_fail("你现在没有准备天山六阳掌，难以施展" ZHONG "。\n");
  # 
  #         if (me->query("neili") < 100)
  #                 return notify_fail("你的真气不够，难以施展" ZHONG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "逆运真气，化空气中的水露为寒冰，凝于掌中，继而掌"
  #               "出如风，轻飘飘地向$n" HIW "拍落。\n";
  # 
  #         ap = me->query_skill("force") + me->query_skill("throwing") + me->query_skill("medical");
  #         dp = target->query_skill("force") + target->query_skill("medical");
  #         flvl = me->query("jiali");
  #         if (ap / 3 + random(ap) > dp)
  #         {
  #                 target->receive_wound("jing", 10 + random(5), me);
  #                 damage = ap / 2 + random(ap / 2);
  #                 msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 50,
  #                                            HIR "只见$n" HIR "被$N" HIR "一掌拍中"
  #                                            "，紧接着身子一颤，$P" HIR "那枚生死符"
  #                                            "已种入$p" HIR "体内！\n" NOR);
  #                 target->affect_by("ss_poison",
  #                                ([ "level" : flvl + random(flvl * 2),
  #                                   "id"    : me->query("id"),
  #                                   "duration" : ap / 70 + random(ap / 30) ]));
  #                 me->start_busy(1 + random(4));
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "内力激荡，将$P"
  #                        CYN "那枚生死符硬生生震出体外。\n" NOR;
  #                 me->start_busy(3);
  #                 target->start_busy(1);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
