defmodule Kantele.Combat.Skills.Performs.ShiyingLianhuan.Sha do
  @moduledoc """
  perform「无痕杀」（source shiying-lianhuan/sha.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "shiying-lianhuan/sha"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "shiying-lianhuan")
    ap = Stats.skill(stats, "blade")
    damage = (div(ap, 2) + Engine.rand(rng, ap))

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
      Stats.skill(stats, "shiying-lianhuan") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "blade") != "shiying-lianhuan" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
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
    vitals = %{vitals | neili: vitals.neili - 250}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
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
    Performs.feedback(attacker, 250, 4)
    result = Messages.interpolate("$N回转手中施出「无痕杀」绝技，刀身顿时漾起一道血色刀芒，直斩$n而去！
只听“嗤啦”一声，$n被$N的刀芒划中气门，登时痛声长呼，几欲晕倒。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-250"}], "assign_refs": [{"ap", "blade"}, {"dp", "dodge"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(4);"], "level_gates": [{"force", "200"}, {"shiying-lianhuan", "150"}], "map_gates": [{"blade", "shiying-lianhuan"}], "remote_damage": true, "resource_gates": [{"neili", "300"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define SHA "「" HIR "无痕杀" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  #  
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/shiying-lianhuan/sha"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(SHA "只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #               (string)weapon->query("skill_type") != "blade")
  #                 return notify_fail("你使用的武器不对，难以施展" SHA "。\n");
  # 
  #         if (me->query_skill("force") < 200)
  #                 return notify_fail("你的内功修为不够，难以施展" SHA "。\n");
  # 
  #         if (me->query_skill("shiying-lianhuan", 1) < 150)
  #                 return notify_fail("你弑鹰九连环修为不够，难以施展" SHA "。\n");
  # 
  #         if (me->query_skill_mapped("blade") != "shiying-lianhuan")
  #                 return notify_fail("你没有激发弑鹰九连环，难以施展" SHA "。\n");
  # 
  #         if (me->query("neili") < 300)
  #                 return notify_fail("你现在的真气不足，难以施展" SHA "。\n");
  # 
  #         if (! living(target))
  #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "$N" HIR "回转手中" + weapon->name() + HIR "施出「" NOR +
  #               RED "无痕杀" HIR "」绝技，刀身顿时漾起一道血色刀芒，直斩$n"
  #               HIR "而去！\n" NOR;
  # 
  #         ap = me->query_skill("blade");
  #         dp = target->query_skill("dodge");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap / 2 + random(ap);
  #                 me->add("neili", -250);
  #                 me->start_busy(2);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 70,
  #                                            HIR "只听“嗤啦”一声，$n" HIR "被$N"
  #                                            HIR "的刀芒划中气门，登时痛声长呼，几"
  #                                            "欲晕倒。\n" NOR);
  #         } else
  #         {
  #                 me->add("neili", -100);
  #                 me->start_busy(4);
  #                 msg += CYN "$n" CYN "见$P" CYN "来势汹涌，连忙飞"
  #                        "身向后挪移数尺，躲闪开来。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
