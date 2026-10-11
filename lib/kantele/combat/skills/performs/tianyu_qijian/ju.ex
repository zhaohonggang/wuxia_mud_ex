defmodule Kantele.Combat.Skills.Performs.TianyuQijian.Ju do
  @moduledoc """
  perform「聚剑诀」（source tianyu-qijian/ju.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "tianyu-qijian/ju"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "tianyu-qijian")
    ap = Stats.skill(stats, "force")

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
      Stats.skill(stats, "force") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "tianyu-qijian") < 130 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "tianyu-qijian" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 160}
    vitals = %{vitals | neili: vitals.neili - 80}
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
    Performs.feedback(attacker, 80, 4)
    result = Messages.interpolate("$N手腕轻轻一抖，手中的化作一道彩虹，光华眩目，笼罩了$n。
只见$N剑花聚为一线，穿向$n，$p只觉一股热流穿心而过，喉头一甜，鲜血狂喷而出！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-160"}, {"neili", "-80"}], "assign_refs": [{"ap", "force"}, {"damage", "sword"}, {"dp", "force"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(4);"], "level_gates": [{"force", "180"}, {"tianyu-qijian", "130"}], "map_gates": [{"sword", "tianyu-qijian"}], "remote_damage": true, "resource_gates": [{"neili", "200"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define JU "「" HIR "聚剑诀" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     int damage;
  #     int ap, dp;
  #     string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/tianyu-qijian/ju"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #                 return notify_fail(JU "只能对战斗中的对手使用。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon")) ||
  #         (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" JU "。\n");
  # 
  #     if ((int)me->query_skill("tianyu-qijian", 1) < 130)
  #                 return notify_fail("你的天羽奇剑不够娴熟，难以施展" JU "。\n");
  # 
  #         if ((int)me->query_skill("force") < 180)
  #                 return notify_fail("你的内功火候不足，难以施展" JU "。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不足，难以施展" JU "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "tianyu-qijian")
  #                 return notify_fail("你没有激发天羽奇剑，难以施展" JU "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIR "$N" HIR "手腕轻轻一抖，手中的" + weapon->name() +
  #           HIR "化作一道彩虹，光华眩目，笼罩了$n" HIR "。\n" NOR;
  # 
  #     ap = me->query_skill("force");
  #     dp = target->query_skill("force");
  #     if (ap / 2 + random(ap) > dp)
  #     {
  #         damage = (int)me->query_skill("sword");
  #         damage += random(damage);
  # 
  #         me->add("neili", -160);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
  #                                            HIR "只见$N" HIR "剑花聚为一线，穿向$n"
  #                                            HIR "，$p" HIR "只觉一股热流穿心而过，"
  #                                            "喉头一甜，鲜血狂喷而出！\n" NOR);
  #         me->start_busy(2);
  #     } else
  #     {
  #         msg += CYN "可是$p" CYN "猛地向前一跃,跳出了$P"
  #                        CYN "的攻击范围。\n"NOR;
  #         me->add("neili", -80);
  #         me->start_busy(4);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
