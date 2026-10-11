defmodule Kantele.Combat.Skills.Performs.DaojianGuizhen.Xue do
  @moduledoc """
  perform「天下有」（source daojian-guizhen/xue.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "daojian-guizhen/xue"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "daojian-guizhen")
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
      Stats.skill(stats, "daojian-guizhen") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "daojian-guizhen") < 250 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
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
    vitals = %{vitals | neili: vitals.neili - 300}
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
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 300, 1)
    result = Messages.interpolate("$N手中蓦地一抖，将「胡家刀法」并「苗家剑法」连环施出。霎时寒
光点点，犹如夜陨划空，铺天盖地罩向$n，正是一招「天下有血」。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-300"}], "apply_adds": ["attack", "damage"], "assign_refs": [{"ap", "daojian-guizhen"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(1 + random(8));"], "level_gates": [{"daojian-guizhen", "200"}, {"daojian-guizhen", "250"}], "remote_damage": false, "resource_gates": [{"neili", "500"}], "var_gates": [{"i", "9"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define XUE "「" HIW "天下有" HIR "血" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string type, msg;
  #         object weapon;
  #         int i, count;
  #         int ap, dp;
  # 
  #         if (me->query_skill("daojian-guizhen", 1) < 200)
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! me->is_fighting(target))
  #                 return notify_fail(XUE "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "sword"
  #            && (string)weapon->query("skill_type") != "blade" )
  #                 return notify_fail("你所使用的武器不对，难以施展" XUE "。\n");
  # 
  #         type = weapon->query("skill_type");
  # 
  #         if (me->query_skill(type, 1) < 250)
  #                 return notify_fail("你的" + to_chinese(type) + "太差，"
  #                                    "难以施展" XUE "。\n");
  # 
  #         if (me->query_skill_mapped(type) != "daojian-guizhen")
  #                 return notify_fail("你没有激发刀剑归真，难以施展" XUE "。\n");
  # 
  #         if (me->query_skill("daojian-guizhen", 1) < 250)
  #                 return notify_fail("你的刀剑归真等级不够，难以施展" XUE "。\n");
  # 
  #         if (me->query("neili") < 500)
  #                 return notify_fail("你现在的真气不够，难以施展" XUE "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "手中" + weapon->name() + HIW "蓦地一抖"
  #               "，将「" NOR + WHT "胡家刀法" HIW "」并「" NOR + WHT
  #               "苗家剑法" HIW "」连环施出。霎时寒\n光点点，犹如夜陨"
  #               "划空，铺天盖地罩向$n" HIW "，正是一招「" HIW "天下"
  #               "有" HIR "血" HIW "」。\n" NOR;
  # 
  #         ap = me->query_skill("daojian-guizhen", 1) * 3 / 2 +
  #              me->query_skill("martial-cognize", 1);
  # 
  #         dp = target->query_skill("parry") +
  #              target->query_skill("martial-cognize", 1);
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += HIW "$n" HIW "只见无数刀光剑影向自己逼"
  #                        "来，顿感眼花缭乱，心底寒意油然而生。\n" NOR;
  #                 count = ap / 6;
  #                 me->set_temp("daojian-guizhen/max_pfm", 1);
  #         } else
  #         {
  #                 msg += HIG "$n" HIG "突然发现自己四周皆被刀光"
  #                        "剑影所包围，心知不妙，急忙小心招架。\n" NOR;
  #                 count = ap / 12;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         me->add("neili", -300);
  #         me->add_temp("apply/attack", count);
  #         me->add_temp("apply/damage", count * 2 / 3);
  # 
  #         for (i = 0; i < 9; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  # 
  #                 COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  #         me->add_temp("apply/attack", -count);
  #         me->add_temp("apply/damage", -count * 2 / 3);
  #         me->delete_temp("daojian-guizhen/max_pfm");
  #         me->start_busy(1 + random(8));
  #         return 1;
  # }
end
