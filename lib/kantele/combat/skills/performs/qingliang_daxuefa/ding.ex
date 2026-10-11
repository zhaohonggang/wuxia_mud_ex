defmodule Kantele.Combat.Skills.Performs.QingliangDaxuefa.Ding do
  @moduledoc """
  perform「透骨钉」（source qingliang-daxuefa/ding.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "qingliang-daxuefa/ding"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "qingliang-daxuefa")
    skill = Stats.skill(stats, "qingliang-daxuefa")
    ap = Stats.skill(stats, "dagger")
    damage = ((100 + div(ap, 3)) + Engine.rand(rng, div(ap, 3)))

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
      Stats.skill(stats, "force") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "dagger") != "qingliang-daxuefa" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 200}
    vitals = %{vitals | neili: vitals.neili - 50}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1)
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
    result = Messages.interpolate("$N侧身将手中斜刺而出，一式「透骨钉」卷带着呼呼风声，将$n包围紧裹。
顿时只听得“噗嗤”一声，$n胸口被$N这一招刺中，溅出一柱鲜血。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}, {"neili", "-50"}], "assign_refs": [{"ap", "dagger"}, {"dp", "parry"}, {"skill", "qingliang-daxuefa"}], "busy_lines": ["me->start_busy(1);", "if (ap / 3 + random(ap) > dp && ! target->is_busy())", "target->start_busy(ap / 25 + 1);", "me->start_busy(3);"], "level_gates": [{"force", "150"}], "map_gates": [{"dagger", "qingliang-daxuefa"}], "remote_damage": true, "resource_gates": [{"neili", "500"}], "var_gates": [{"skill", "100"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define DING "「" HIC "透骨钉" NOR "」"
  # 
  # inherit F_SSERVER;
  #  
  # int perform(object me)
  # {
  #         string msg;
  #         object weapon, target;
  #         int skill, ap, dp, damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/qingliang-daxuefa/ding"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! me->is_fighting(target))
  #                 return notify_fail(DING "只能对战斗中的对手使用。\n");
  # 
  #         weapon = me->query_temp("weapon");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "dagger")
  #                 return notify_fail("你所使用的武器不对，难以施展" DING "。\n");
  # 
  #         skill = me->query_skill("qingliang-daxuefa", 1);
  # 
  #         if (me->query_skill("force") < 150)
  #                 return notify_fail("你的内功修为不够，难以施展" DING "。\n");
  # 
  #         if (me->query("neili") < 500)
  #                 return notify_fail("你现在的真气不足，难以施展" DING "。\n");
  # 
  #         if (skill < 100)
  #                 return notify_fail("你清凉打穴法修为有限，难以施展" DING "。\n");
  # 
  #         if (me->query_skill_mapped("dagger") != "qingliang-daxuefa")
  #                 return notify_fail("你没有激发清凉打穴法，难以施展" DING "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIC "$N" HIC "侧身将手中" + weapon->name() + HIC "斜刺而出，一式「"
  #               HIR "透骨钉" NOR + HIC "」卷带着呼呼风声，将$n" HIC "包围紧裹。\n" NOR;
  #  
  #         ap = me->query_skill("dagger");
  #         dp = target->query_skill("parry");
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 me->add("neili", -200);
  #                 damage = 100 + ap / 3 + random(ap / 3);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
  #                                            HIR "顿时只听得“噗嗤”一声，$n" HIR
  #                                            "胸口被$N" HIR "这一招刺中，溅出一柱鲜血。\n" NOR);
  #                 me->start_busy(1);
  #                 if (ap / 3 + random(ap) > dp && ! target->is_busy())
  #                         target->start_busy(ap / 25 + 1);
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "的看破了$P" CYN
  #                        "的招式，巧妙的一一拆解，没露半点"
  #                        "破绽！\n" NOR;
  #                 me->add("neili", -50);
  #                 me->start_busy(3);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
