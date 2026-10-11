defmodule Kantele.Combat.Skills.Performs.JinsheZhang.Fugu do
  @moduledoc """
  perform「fugu」（source jinshe-zhang/fugu.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "jinshe-zhang/fugu"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jinshe-zhang")

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
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "jinshe-zhang") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
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
    vitals = %{vitals | neili: vitals.neili - 150}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
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
    Performs.feedback(attacker, 150, 2)
    result = Messages.interpolate("结果$n被$N的左手所制，在「附骨缠身」下，一时竟然无法还手！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-150"}], "busy_lines": ["if (target->is_busy() ||", "if (! target->is_busy())", "target->start_busy(1);", "me->start_busy(2);", "me->start_busy(2);"], "level_gates": [{"jinshe-zhang", "100"}], "prepared_gates": [{"strike", "jinshe-zhang"}], "remote_damage": false, "resource_gates": [{"neili", "300"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // fugu.c 金蛇游身掌-附骨缠身
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         // object weapon;
  #         // int damage;
  #         string msg;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("附骨缠身只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon"))
  #                 return notify_fail("你不是空手，不能使用附骨缠身。\n");
  # 
  #         if ((int)me->query_skill("jinshe-zhang", 1) < 100)
  #                 return notify_fail("你的金蛇掌不够娴熟，不会使用附骨缠身。\n");
  # 
  #         if ((int)me->query("neili", 1) < 300)
  #                 return notify_fail("你现在内力太弱，不能使用附骨缠身。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "jinshe-zhang")
  #                 return notify_fail("你现在没有激发金蛇掌法，无法使用附骨缠身。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIC "$N" HIC "大喝一声，缠身而上左手一探刁住$n"
  #               HIC "手腕，右掌猛下杀手！\n"NOR;
  #         message_combatd(msg, me, target);
  # 
  #         if (target->is_busy() ||
  #             random(me->query_skill("strike")) > target->query_skill("parry") / 2)
  #         {
  #                 if (! target->is_busy())
  #                         target->start_busy(1);
  # 
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  # 
  #                 me->add("neili", -150);
  #                 me->start_busy(2);
  #                 msg = HIR "结果$n" HIR "被$N" HIR "的左手所制，"
  #                       "在「附骨缠身」下，一时竟然无法还手！\n" NOR;
  #         }
  #         else
  #         {
  #                 me->start_busy(2);
  #                 msg = CYN "可是$p" CYN "识破了$P"
  #                       CYN "这一招，手肘一送，摆脱了对方控制。\n"NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
