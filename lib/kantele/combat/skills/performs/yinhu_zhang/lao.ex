defmodule Kantele.Combat.Skills.Performs.YinhuZhang.Lao do
  @moduledoc """
  perform「大海捞针」（source yinhu-zhang/lao.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "yinhu-zhang/lao"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "yinhu-zhang")
    ap = Stats.skill(stats, "staff")
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
      Stats.skill(stats, "force") < 140 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "yinhu-zhang") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "staff") != "yinhu-zhang" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
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
    vitals = %{vitals | neili: vitals.neili - 100}
    vitals = %{vitals | neili: vitals.neili - 180}
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
    Performs.feedback(attacker, 180, 4)
    result = Messages.interpolate("$n完全无法看清招中虚实，只听「嘭」地一声，已被$N击中肩膀。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-180"}], "assign_refs": [{"ap", "staff"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);"], "level_gates": [{"force", "140"}, {"yinhu-zhang", "100"}], "map_gates": [{"staff", "yinhu-zhang"}], "remote_damage": true, "resource_gates": [{"neili", "200"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define TONG "「" HIW "大海捞针" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp, damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/yinhu-zhang/lao"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail(TONG "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "staff")
  #                 return notify_fail("你使用的武器不对，难以施展" TONG "。\n");
  # 
  #         if ((int)me->query_skill("force") < 140)
  #                 return notify_fail("你的内功火候不够，难以施展" TONG "。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不够，难以施展" TONG "。\n");
  # 
  #         if ((int)me->query_skill("yinhu-zhang", 1) < 100)
  #                 return notify_fail("你银瑚杖法火候不够，难以施展" TONG "。\n");
  # 
  #         if (me->query_skill_mapped("staff") != "yinhu-zhang")
  #                 return notify_fail("你没有激发银瑚杖法，难以施展" TONG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIM "\n$N" HIM "一声暴喝，猛然间腾空而起，施出绝招「" HIW "大海捞"
  #               "针" HIM "」，手中" + weapon->name() + HIM "从天而降，气势惊人地"
  #               "袭向$n" HIM "。\n" NOR;
  # 
  #         message_sort(msg, me, target);
  # 
  #         ap = me->query_skill("staff");
  #         dp = target->query_skill("parry");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 2);
  # 
  #                 msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 75,
  #                                            HIR "$n" HIR "完全无法看清招中虚实，只"
  #                                            "听「嘭」地一声，已被$N" HIR "击中肩膀。\n" NOR);
  #                 me->start_busy(3);
  #                 me->add("neili", -180);
  #         } else
  #         {
  #                 msg = CYN "可是$n" CYN "奋力招架，左闪右避，好不容"
  #                        "易抵挡住了$N" CYN "的攻击。\n" NOR;
  #                 me->start_busy(4);
  #                 me->add("neili", -100);
  #         }
  #         message_vision(msg, me, target);
  # 
  #         return 1;
  # }
end
