defmodule Kantele.Combat.Skills.Performs.NeverDefeated.Po do
  @moduledoc """
  perform「po」（source never-defeated/po.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "never-defeated/po"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "never-defeated")
    skill = Stats.skill(stats, "never-defeated")
    skill2 = Stats.skill(stats, "martial-cognize")
    ap = (div((skill * 3), 2) + div((skill2 * 3), 2))
    n = (4 + Engine.rand(rng, 4))

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
  defp check_gates(character), do: check_resources(character)

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 150 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
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
    Performs.feedback(attacker, 100, 1)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}], "assign_refs": [{"dp", "parry"}, {"skill", "never-defeated"}, {"skill2", "martial-cognize"}], "busy_lines": ["me->start_busy(1 + random(n));", "if (random(2) && ! target->is_busy())", "target->start_busy(1);", "target->start_busy(4 + random(skill / 30));", "me->start_busy(3 + random(2));"], "remote_damage": false, "resource_gates": [{"neili", "150"}], "var_gates": [{"skill", "100"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // po.c 破字诀
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         object weapon, weapon2;
  #         int n;
  #         int skill, skill2, ap, dp;
  #         string type;
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         skill = me->query_skill("never-defeated", 1);
  # 
  #         skill2 = me->query_skill("martial-cognize", 1);
  # 
  #         if (! me->is_fighting(target))
  #                 return notify_fail("破字诀只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")))
  #                 return notify_fail("你必须手持兵刃才能施展破字诀！\n");
  # 
  #         type = weapon->query("skill_type");
  #         if (me->query_skill(type, 1) < 150)
  #                 return notify_fail("你的" + to_chinese(type) + "水平有限，无法施展破字诀！\n");
  # 
  #         if (me->query_skill_mapped(type) != "never-defeated")
  #                 return notify_fail("你没有激发不败神功，无法施展破字诀！\n");
  # 
  #         if (skill < 100)
  #                 return notify_fail("你的不败神功等级不够，无法施展破字诀！\n");
  # 
  #         if (me->query("neili") < 150)
  #                 return notify_fail("你现在真气不够！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         me->add("neili", -100);
  # 
  #         ap = skill * 3 / 2 + skill2 * 3 / 2;
  #         dp = target->query_skill("parry") +
  #              target->query_skill("martial-cognize", 1);
  # 
  #         msg = HIC "$N" HIC "手中" + weapon->name() +
  #               HIC "一抖，犹如夜雨流星，铺天盖地的攻向$n"
  #               HIC "，没有半点规矩可循。\n" NOR;
  #         if (ap / 2 + random(ap * 2) > dp)
  #         {
  #                 n = 4 + random(4);
  #                 if (ap / 2 + random(ap) > dp)
  #                 {
  #                         msg += HIY "$n" HIY "见来招即巧又拙，不同于人间"
  #                                "任何招式，不禁大为慌乱，一时破绽迭出，$N"
  #                                HIY "见状连出" + chinese_number(n) + "招！\n" NOR;
  #                         message_combatd(msg, me, target);
  #                         me->start_busy(1 + random(n));
  #                         while (n-- && me->is_fighting(target))
  #                         {
  #                                 if (random(2) && ! target->is_busy())
  #                     target->start_busy(1);
  #                                 COMBAT_D->do_attack(me, target, weapon, 0);
  #                         }
  # 
  #                         weapon2 = target->query_temp("weapon");
  #                         if (weapon2 && random(ap) / 2 > dp && weapon2->query("type") != "pin")
  #                         {
  #                                 msg = HIW "$n" HIW "觉得眼前眼花缭乱，手中的" + weapon2->name() +
  #                                       HIW "一时竟然拿捏不住，脱手而出！\n" NOR;
  #                                 weapon2->move(environment(me));
  #                         } else
  #                         {
  #                                 msg = HIY "$n竭力抵挡，一时间再也无力反击。\n" NOR;
  #                         }
  # 
  #                         if (! me->is_fighting(target))
  #                                 // Don't show the message
  #                                 return 1;
  #                 } else
  #                 {
  #                         msg += HIY "$n" HIY "只办了个勉力遮挡，全然无法反击。\n" NOR;
  #                         target->start_busy(4 + random(skill / 30));
  #                 }
  #         } else
  #         {
  #                 msg += HIC "不过$n" HIC "一丝不苟，严守门户，没有露出半点破绽。\n" NOR;
  #                 me->start_busy(3 + random(2));
  #         }
  # 
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
