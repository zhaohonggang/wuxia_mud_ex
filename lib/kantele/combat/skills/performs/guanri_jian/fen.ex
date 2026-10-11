defmodule Kantele.Combat.Skills.Performs.GuanriJian.Fen do
  @moduledoc """
  perform「焚阳剑」（source guanri-jian/fen.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "guanri-jian/fen"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    ap = Stats.skill(stats, "sword")
    damage = (div(ap, 2) + Engine.rand(rng, ap))
    lvl = Stats.skill(stats, "guanri-jian")

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
      Stats.skill(stats, "guanri-jian") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "guanri-jian" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 2000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    vitals = %{vitals | neili: vitals.neili - 300}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
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
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 300, 4)
    result = Messages.interpolate("$N运转内力，陡然一势「焚阳剑」划出，手中携着一股热流卷向$n全身。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-300"}], "affect_by": ["zhurong_jian"], "assign_refs": [{"ap", "sword"}, {"dp", "force"}, {"lvl", "guanri-jian"}], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);"], "level_gates": [{"guanri-jian", "150"}], "map_gates": [{"sword", "guanri-jian"}], "remote_damage": true, "resource_gates": [{"max_neili", "2000"}, {"neili", "500"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define FEN "「" HIR "焚阳剑" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # string final(object me, object target, int damage);
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp, damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/guanri-jian/fen"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(FEN "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你所使用的武器不对，难以施展" FEN "。\n");
  # 
  #         if ((int)me->query_skill("guanri-jian", 1) < 150)
  #                 return notify_fail("你观日剑法不够娴熟，难以施展" FEN "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "guanri-jian")
  #                 return notify_fail("你没有激发观日剑法，难以施展" FEN "。\n");
  # 
  #         if ((int)me->query("max_neili") < 2000)
  #                 return notify_fail("你的内力修为不够，难以施展" FEN "。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你现在的真气不足，难以施展" FEN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = WHT "$N" WHT "运转内力，陡然一势「" HIR "焚阳剑" NOR +
  #               WHT "」划出，手中" + weapon->name() + WHT "携着一股热"
  #               "流卷向$n" WHT "全身。\n" NOR;
  # 
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("force");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap / 2 + random(ap);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 75,
  #                                            (: final, me, target, damage :));
  # 
  #                 me->start_busy(3);
  #                 me->add("neili", -300);
  #         } else
  #         {
  #                 msg += CYN "可是$n" CYN "看破了$N"
  #                        CYN "的企图，斜跃避开。\n" NOR;
  #                 me->start_busy(4);
  #                 me->add("neili", -100);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
  # 
  # string final(object me, object target, int damage)
  # {
  #         int lvl = me->query_skill("guanri-jian", 1);
  # 
  #         target->affect_by("zhurong_jian",
  #                 ([ "level"    : lvl + random(lvl),
  #                    "id"       : me->query("id"),
  #                    "duration" : lvl / 50 + random(lvl / 20) ]));
  # 
  #         return  HIR "只听$n" HIR "一声惨嚎，几柱鲜血射出，剑伤"
  #                 "处腾起一道烈火，烧得嗤嗤作响。\n" NOR;
  # }
end
