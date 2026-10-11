defmodule Kantele.Combat.Skills.Performs.PanguQishi.Kai do
  @moduledoc """
  perform「开天辟地」（source pangu-qishi/kai.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "pangu-qishi/kai"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "pangu-qishi")

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
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
      Stats.skill(stats, "force") < 300 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "pangu-qishi") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "hammer") != "pangu-qishi" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 400 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 300}
    vitals = %{vitals | neili: vitals.neili - 500}
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
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 500, 4)
    result = Messages.interpolate("$n躲避不及，被$N这锤正中胸口，顿时一声闷响，稻草般向后横飞出去。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-300"}, {"neili", "-500"}], "assign_refs": [{"ap", "hammer"}, {"dp", "force"}], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);"], "level_gates": [{"force", "300"}, {"pangu-qishi", "180"}], "map_gates": [{"hammer", "pangu-qishi"}], "remote_damage": true, "resource_gates": [{"neili", "400"}]}

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
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/pangu-qishi/kai"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(KAI "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #               (string)weapon->query("skill_type") != "hammer")
  #                 return notify_fail("你使用的武器不对，难以施展" KAI "。\n");
  # 
  #         if (me->query_skill("force") < 300)
  #                 return notify_fail("你的内功的修为不够，难以施展" KAI "。\n");
  # 
  #         if (me->query_skill("pangu-qishi", 1) < 180)
  #                 return notify_fail("你的盘古七势修为不够，难以施展" KAI "。\n");
  # 
  #         if (me->query("neili") < 400)
  #                 return notify_fail("你的真气不够，难以施展" KAI "。\n");
  # 
  #         if (me->query_skill_mapped("hammer") != "pangu-qishi")
  #                 return notify_fail("你没有激发盘古七势，难以施展" KAI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = WHT "$N" WHT "一声断喝，手中" + weapon->name() +
  #               WHT "如山岳巍峙，携着开天辟地之势向$n" WHT "猛劈而下！\n" NOR;
  # 
  #         ap = me->query_skill("hammer") + me->query("str") * 10;
  #         dp = target->query_skill("force") + target->query("con") * 10;
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap / 2 + random(ap);
  #                 me->add("neili", -500);
  #                 me->start_busy(3);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 80,
  #                                            HIR "$n" HIR "躲避不及，被$N" HIR "这"
  #                                            "锤正中胸口，顿时一声闷响，稻草般向后"
  #                                            "横飞出去。\n" NOR);
  #         } else
  #         {
  #                 me->add("neili", -300);
  #                 me->start_busy(4);
  #                 msg += HIC "可是$n" HIC "真气鼓荡，$N" HIC "雷霆般"
  #                        "的劲力竟如中败絮，登时被解于无形。\n"NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
