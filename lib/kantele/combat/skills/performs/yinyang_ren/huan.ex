defmodule Kantele.Combat.Skills.Performs.YinyangRen.Huan do
  @moduledoc """
  perform「阴阳环」（source yinyang-ren/huan.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "yinyang-ren/huan"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "yinyang-ren")
    ap = Stats.skill(stats, "blade")
    attack_time = 8
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
      Stats.skill(stats, "dodge") < 220 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "yinyang-ren") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "blade") != "yinyang-ren" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      Stats.mapped(stats, "sword") != "yinyang-ren" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 270 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
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
  #   %{"apply_adds": ["attack"], "assign_refs": [{"ap", "blade"}, {"ap", "sword"}, {"dp", "dodge"}], "busy_lines": ["me->start_busy(1 + random(attack_time));"], "level_gates": [{"dodge", "220"}, {"yinyang-ren", "180"}], "map_gates": [{"blade", "yinyang-ren"}, {"sword", "yinyang-ren"}], "remote_damage": false, "resource_gates": [{"neili", "270"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define HUAN "「" HIG "阴阳环" NOR "」"
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
  #         if (userp(me) && ! me->query("can_perform/yinyang-ren/huan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(HUAN "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon"))
  #            || ((string)weapon->query("skill_type") != "sword"
  #            && (string)weapon->query("skill_type") != "blade"))
  #                 return notify_fail("你使用的武器不对，难以施展" HUAN "。\n");
  # 
  #         if (me->query_skill("yinyang-ren", 1) < 180)
  #                 return notify_fail("你的阴阳刃法修为不够，难以施展" HUAN "。\n");
  # 
  #         if (me->query_skill("dodge") < 220)
  #                 return notify_fail("你的阴阳刃法修为不够，难以施展" HUAN "。\n");
  # 
  #         if (me->query("neili") < 270)
  #                 return notify_fail("你的真气不够，难以施展" HUAN "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "yinyang-ren"
  #             && me->query_skill_mapped("blade") != "yinyang-ren")
  #                 return notify_fail("你没有激发阴阳刃法，难以施展" HUAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIY "$N" HIY "长啸一声，手中" + weapon->name() + HIY "化出"
  #               "无数光环，猛然间光芒瀑涨，连连洒向$n" HIY "。\n" NOR;
  # 
  #         // 根据所激发的是sword或blade来判断ap值。
  #         if (me->query_skill_mapped("sword") == "yinyang-ren")
  #                 ap = me->query_skill("sword");
  #         else
  #                 ap = me->query_skill("blade");
  # 
  #     dp = target->query_skill("dodge");
  #         attack_time = 4;
  # 
  #     if (ap / 2 + random(ap * 2) > dp)
  #     {
  #         msg += HIR "结果$n" HIR "被$N" HIR "攻了个措手不及，$n"
  #                        HIR "慌忙招架，心中叫苦。\n" NOR;
  #                 count = ap / 12;
  #                 attack_time += random(ap / 45);
  #                 me->add_temp("apply/attack", count);
  #         } else
  #         {
  #                 msg += HIC "$n" HIC "见$N" HIC "这几招凌厉无比，凶猛异"
  #                        "常，只得苦苦招架。\n" NOR;
  #                 count = 0;
  #         }
  #     message_combatd(msg, me, target);
  # 
  #         if (attack_time > 8)
  #                 attack_time = 8;
  # 
  #     me->add("neili", -attack_time * 20);
  # 
  #     for (i = 0; i < attack_time; i++)
  #     {
  #         if (! me->is_fighting(target))
  #             break;
  # 
  #             COMBAT_D->do_attack(me, target, weapon, 0);
  #     }
  #         me->add_temp("apply/attack", -count);
  #     me->start_busy(1 + random(attack_time));
  # 
  #     return 1;
  # }
end
