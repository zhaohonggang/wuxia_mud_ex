defmodule Kantele.Combat.Skills.Performs.ShenghuoLing.Hua do
  @moduledoc """
  perform「光华令」（source shenghuo-ling/hua.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "shenghuo-ling/hua"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "shenghuo-ling")
    skill = Stats.skill(stats, "shenghuo-ling")
    ap = (Stats.skill(stats, "sword") + Stats.skill(stats, "force"))
    damage = (ap + Engine.rand(rng, div(ap, 2)))

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
  defp check_gates(character), do: check_resources(character)

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 1500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 340 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 150}
    vitals = %{vitals | neili: vitals.neili - 300}
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
    Performs.feedback(attacker, 300, 4)
    result = Messages.interpolate("$n只觉万道金芒铺天盖地席卷而来，完全无法阻挡。顿时只感全身几处刺痛，鲜血飞溅而出！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-150"}, {"neili", "-300"}], "assign_refs": [{"ap", "sword"}, {"dp", "parry"}, {"skill", "shenghuo-ling"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(4);"], "remote_damage": true, "resource_gates": [{"max_neili", "1500"}, {"neili", "340"}], "var_gates": [{"skill", "140"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define GUANG "「" HIY "光华令" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         int damage, skill, ap, dp;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/shenghuo-ling/hua"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         skill = me->query_skill("shenghuo-ling",1);
  # 
  #         if (! (me->is_fighting()))
  #                 return notify_fail(GUANG "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的兵器不对，不能使用圣火令法之" GUANG "。\n");
  # 
  #         if (skill < 140)
  #                 return notify_fail("你的圣火令法等级不够, 不能使用圣火令法之" GUANG "。\n");
  # 
  #         if (me->query("max_neili") < 1500)
  #                 return notify_fail("你的内力修为不足，不能使用圣火令法之" GUANG "。\n");
  # 
  #         if (me->query("neili") < 340)
  #                 return notify_fail("你的内力不够，不能使用圣火令法之" GUANG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "猛吸一口气，使出圣火令法之「" HIW "光华令" HIY "」，手中"
  #               + weapon->name() + NOR + HIY "御驾如飞，幻出无数道金"
  #               "芒，将$n" HIY "笼罩起来！\n" NOR;
  # 
  #         ap = me->query_skill("sword") + me->query_skill("force");
  #         dp = target->query_skill("parry") + target->query_skill("force");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 2);
  # 
  #                 me->add("neili", -300);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 80,
  #                        HIR "$n" HIR "只觉万道金芒铺天盖地席卷而来，"
  #                        "完全无法阻挡。顿时只感全身几处刺痛，鲜血飞"
  #                        "溅而出！\n" NOR);
  # 
  #                 me->start_busy(2);
  #         } else
  #         {
  #                 msg += CYN "可是$n" CYN "看准$N" CYN "的破绽，猛地向"
  #                        "前一跃，跳出了$N" CYN "的攻击范围。\n"NOR;
  #                 me->add("neili", -150);
  #                 me->start_busy(4);
  #         }
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
