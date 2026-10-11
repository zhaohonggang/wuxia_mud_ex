defmodule Kantele.Combat.Skills.Performs.TaixuanGong.Xuan do
  @moduledoc """
  perform「太玄激劲」（source taixuan-gong/xuan.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "taixuan-gong/xuan"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "taixuan-gong")
    ap = Stats.skill(stats, "taixuan-gong, 1")
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
      Stats.skill(stats, "force") < 300 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "taixuan-gong") < 240 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "blade") != "taixuan-gong" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      Stats.mapped(stats, "sword") != "taixuan-gong" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      Stats.mapped(stats, "unarmed") != "taixuan-gong" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 5000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 800 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 600}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

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
    Performs.feedback(attacker, 600, 1)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-600"}], "apply_adds": ["attack"], "assign_refs": [{"dp", "dodge"}, {"lvl", "taixuan-gong"}], "busy_lines": ["if (random(2) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(5));"], "level_gates": [{"force", "300"}, {"taixuan-gong", "240"}], "map_gates": [{"blade", "taixuan-gong"}, {"sword", "taixuan-gong"}, {"unarmed", "taixuan-gong"}], "remote_damage": false, "resource_gates": [{"max_neili", "5000"}, {"neili", "800"}], "var_gates": [{"i", "15"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define XUAN "「" HIW "太玄激劲" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int count;
  #         int lvl;
  #         int i, ap, dp;
  #         object weapon;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/taixuan-gong/xuan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(XUAN "只能对战斗中的对手使用。\n");
  # 
  #     if ((int)me->query("neili") < 800)
  #         return notify_fail("你的真气不够，无法施展" XUAN "！\n");
  # 
  #         if (me->query("max_neili") < 5000)
  #                 return notify_fail("你的内力修为还不足以使出" XUAN "。\n");
  # 
  #     if ((int)me->query_skill("force") < 300)
  #         return notify_fail("你的内功火候不够，难以施展" XUAN "！\n");
  # 
  #     if ((lvl = (int)me->query_skill("taixuan-gong", 1)) < 240)
  #         return notify_fail("你的太玄功还不够熟练，无法使用" XUAN "！\n");
  # 
  #         // 未学会如何驾御兵器只能激发为拳脚施展 太玄激劲
  #         if (! me->query("can_learned/taixuan-gong/enable_weapon"))
  #         {
  #              weapon = me->query_temp("weapon");
  #              if (objectp(weapon))
  #                      return notify_fail("你还没有学会如何利用太玄功驾御兵器，这招只能空手施展！\n");
  # 
  #              if (me->query_skill_mapped("unarmed") != "taixuan-gong"
  #                  || me->query_skill_prepared("unarmed" != "taixuan-gong"))
  #                        return notify_fail("你没有准备太玄功，无法使用" XUAN "。\n");
  # 
  #         }
  #         else // 已经学会利用太玄功驾御兵器
  #         {
  #              weapon = me->query_temp("weapon");
  #              // 当没有持武器时判断施展该招需要准备为拳脚
  #              if (! objectp(weapon))
  #              {
  #                     if (me->query_skill_mapped("unarmed") != "taixuan-gong"
  #                         || me->query_skill_prepared("unarmed" != "taixuan-gong"))
  #                               return notify_fail("你没有准备太玄功，无法使用" XUAN "。\n");
  #              }
  #              // 手持有武器必须为刀或者剑
  #              else if (objectp(weapon) && (string)weapon->query("skill_type") != "sword"
  #                       && (string)weapon->query("skill_type") != "blade")
  #                               return notify_fail("你使用的武器不对，无法施展" XUAN "。\n");
  # 
  #              if (objectp(weapon) && me->query_skill_mapped("sword") != "taixuan-gong"
  #                  && (string)weapon->query("skill_type") == "sword")
  #                               return notify_fail("你还没有激发太玄功，无法施展" XUAN "。\n");
  # 
  #              else if (objectp(weapon) && (string)weapon->query("skill_type") == "blade"
  #                       && me->query_skill_mapped("blade") != "taixuan-gong")
  #                               return notify_fail("你还没有激发太玄功，无法施展" XUAN "。\n");
  # 
  #         }
  #         if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIW "\n霎时间$N" HIW "只觉思绪狂涌，当即闭上双眼，再不理睬$n"
  #               HIW "如何招架，只管施招攻出！此时侠客岛石壁上的千百种招"
  #               "式，转眼已从$N" HIW "心底传向手足，尽数向$n" HIW "袭去！\n" NOR;
  # 
  #     message_sort(msg, me, target);
  #     me->add("neili", -600);
  #         ap = me->query_skill("taixuan-gong, 1");
  #         dp = target->query_skill("dodge", 1);
  # 
  #         if (ap / 3 + random(ap) > dp)
  #                   count = ap / 8;
  # 
  #         else count = 0;
  # 
  #         me->add_temp("apply/attack", count);
  # 
  #         for (i = 0; i < 15; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  # 
  #                 if (random(2) == 1 && ! target->is_busy())
  #                         target->start_busy(1);
  # 
  #             if(weapon)
  #                 COMBAT_D->do_attack(me, target, weapon, i * 2);
  #             else
  #                 COMBAT_D->do_attack(me, target, 0, i * 2);
  #         }
  #         me->add_temp("apply/attack", -count);
  #     me->start_busy(1 + random(5));
  #     return 1;
  # }
end
