defmodule Kantele.Combat.Skills.Performs.WushenJian.Qian do
  @moduledoc """
  perform「千剑纵横势」（source wushen-jian/qian.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "wushen-jian/qian"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "wushen-jian")
    ap = Stats.skill(stats, "sword")
    attack_time = 9
    count = 0
    i = 0

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
      Stats.skill(stats, "wushen-jian") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "wushen-jian" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
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
    result = Messages.interpolate("结果$n被$N攻了个措手不及，$n慌忙招架，心中叫苦。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"apply_adds": ["attack", "damage"], "assign_refs": [{"ap", "sword"}, {"dp", "dodge"}], "busy_lines": ["me->start_busy(1 + random(attack_time / 2));", "if (! target->is_busy() && random(3) == 1)", "target->start_busy(1);"], "level_gates": [{"wushen-jian", "200"}], "map_gates": [{"sword", "wushen-jian"}], "remote_damage": false, "resource_gates": [{"neili", "300"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define QIAN "「" HIW "千剑纵横势" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg;
  #     int ap, dp;
  #         int count;
  #     int i, attack_time;
  # 
  #         if (userp(me) && ! me->query("can_perform/wushen-jian/qian"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #                 return notify_fail(QIAN "只能对战斗中的对手使用。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" QIAN "。\n");
  # 
  #     if ((int)me->query_skill("wushen-jian", 1) < 200)
  #         return notify_fail("你的衡山五神剑不够娴熟，难以施展" QIAN "。\n");
  # 
  #     if (me->query("neili") < 300)
  #         return notify_fail("你的真气不够，难以施展" QIAN "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "wushen-jian")
  #                 return notify_fail("你没有激发衡山五神剑，难以施展" QIAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIW "\n$N" HIW "运转衡山五神剑，手中" + weapon->name() +
  #               HIW "迸出无数剑光，宛若飞虹擎天，席卷$n" HIW "而去。" NOR;
  # 
  #         message_sort(msg, me, target);
  # 
  #     ap = me->query_skill("sword");
  #     dp = target->query_skill("dodge");
  #         attack_time = 4;
  # 
  #     if (ap / 2 + random(ap * 2) > dp)
  #     {
  #         msg = HIR "结果$n" HIR "被$N" HIR "攻了个措手不及，$n"
  #                       HIR "慌忙招架，心中叫苦。\n" NOR;
  # 
  #                 count = ap / 5;
  #                 attack_time += random(ap / 45);
  #         } else
  #         {
  #                 msg = HIC "$n" HIC "见$N" HIC "这几剑招式凌厉，凶猛异"
  #                       "常，只得苦苦招架。\n" NOR;
  #                 count = 0;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         if (attack_time > 9)
  #                 attack_time = 9;
  # 
  #         me->add_temp("apply/attack", count);
  #         me->add_temp("apply/damage", count / 2);
  #         me->add("neili", -attack_time * 30);
  #     me->start_busy(1 + random(attack_time / 2));
  # 
  #         me->set_temp("perform_wushenjian/qian", 1);
  #     for (i = 0; i < attack_time; i++)
  #     {
  #         if (! me->is_fighting(target))
  #                break;
  # 
  #                 if (! target->is_busy() && random(3) == 1)
  #                        target->start_busy(1);
  # 
  #             COMBAT_D->do_attack(me, target, weapon, 0);
  #     }
  #         me->delete_temp("perform_wushenjian/qian");
  # 
  #         me->add_temp("apply/attack", -count);
  #         me->add_temp("apply/damage", -count / 2);
  #     return 1;
  # }
end
