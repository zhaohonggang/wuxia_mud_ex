defmodule Kantele.Combat.Skills.Performs.XuanmingZhang.Zhe do
  @moduledoc """
  perform「只手遮天」（source xuanming-zhang/zhe.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "xuanming-zhang/zhe"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "xuanming-zhang")
    ap = (Stats.skill(stats, "strike") + Stats.skill(stats, "force"))
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
      Stats.skill(stats, "xuanming-shengong") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "xuanming-zhang") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "force") != "xuanming-shengong" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 2000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 180}
    vitals = %{vitals | neili: vitals.neili - 300}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
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
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-180"}, {"neili", "-300"}], "affect_by": ["xuanming_poison"], "assign_refs": [{"ap", "strike"}, {"dp", "dodge"}, {"lvl", "xuanming-zhang"}], "busy_lines": ["me->start_busy(4);"], "level_gates": [{"xuanming-shengong", "150"}, {"xuanming-zhang", "150"}], "map_gates": [{"force", "xuanming-shengong"}], "prepared_gates": [{"strike", "xuanming-zhang"}], "remote_damage": true, "resource_gates": [{"max_neili", "2000"}, {"neili", "500"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHE "「" HIG "只手遮天" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # #include "/kungfu/skill/eff_msg.h";
  # 
  # string final(object me, object target, int lvl);
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         int ap, dp;
  #         int lvl, p;
  # 
  #         if (userp(me) && ! me->query("can_perform/xuanming-zhang/zhe"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHE "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(ZHE "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("xuanming-shengong", 1) < 150)
  #                 return notify_fail("你的玄冥神功火候不够，无法施展" ZHE "。\n");
  # 
  #         if ((int)me->query_skill("xuanming-zhang", 1) < 150)
  #                 return notify_fail("你的玄冥神掌不够熟练，无法施展" ZHE "。\n");
  # 
  #         if (me->query_skill_mapped("force") != "xuanming-shengong")
  #                 return notify_fail("你没有激发玄冥神功为内功，无法施展" ZHE "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "xuanming-zhang")
  #                 return notify_fail("你没有准备玄冥神掌，无法施展" ZHE "。\n");
  # 
  #         if ((int)me->query("max_neili") < 2000)
  #                 return notify_fail("你的内力修为不足，无法施展" ZHE "。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你的真气不够，无法施展" ZHE "。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "\n$N" HIW "运起玄冥神功，全身浮现出一层紫气，猛然间双掌翻腾不息，施"
  #                   "展出绝招「" HIG "只手遮天" HIW "」，携带着万古至毒至寒之气的掌劲"
  #                   "攻向$n" HIW "！\n"NOR;  
  # 
  #         lvl = me->query_skill("xuanming-zhang", 1);
  # 
  #         ap = me->query_skill("strike") + me->query_skill("force");
  #         dp = target->query_skill("dodge") + target->query_skill("force");
  # 
  #         me->start_busy(4);
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         { 
  #                 damage = ap + random(ap / 2);
  #                 me->add("neili", -300);
  #      
  #                 // 玄冥寒毒反噬
  #                 if (target->query("max_neili") * 3 / 5 > me->query("max_neili"))
  #                 {
  #                         message_sort(msg, me, target);
  #                         message_sort(HIM "$N" HIM "一掌打在$n" HIM "身上，猛然间气血翻腾，一股阴寒之气竟"
  #                                      "反噬回来，$N" HIM "抵御不住，寒毒侵入体内。$N" HIM "闷哼一声，一"
  #                                      "口淤血吐出，脸色顿时发紫。\n" NOR, me, target);
  # 
  #                         me->receive_wound("qi", me->query("jiali") + random(me->query("jiali") / 2));
  # 
  #                         p = (int)me->query("qi") * 100 / (int)me->query("max_qi");
  #                         msg = "( $N" + eff_status_msg(p) + " )\n\n";
  #                         message_vision(msg, me, target);
  # 
  #                         me->affect_by("xuanming_poison",
  #                                       ([ "level" : me->query("jiali") + random(me->query("jiali")),
  #                                          "id"    : me->query("id"),
  #                                          "duration" : lvl / 40 + random(lvl / 20) ]));
  # 
  #                         return 1;
  #                         
  #                 } 
  # 
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70,
  #                                           (: final, me, target, lvl :));
  #                                            
  #         } else
  #         {
  #                 msg += HIY "$n" HIY "看见$N" HIY "来势汹涌，急忙提气跃开。\n" NOR;
  #                 me->add("neili", -180);
  #         }
  #         message_sort(msg, me, target);
  # 
  #         return 1;
  # }
  # 
  # string final(object me, object target, int lvl)
  # {
  #         target->affect_by("xuanming_poison",
  #                          ([ "level" : me->query("jiali") * 3,
  #                             "id"    : me->query("id"),
  #                             "duration" : lvl / 40 + random(lvl / 20) ]));
  # 
  #         return HIR "$n" HIR "只见眼前紫影晃动，突然间胸口一震，已知大势"
  #                "不妙，只感胸口处一股寒气升起，尽损三焦六脉。\n" NOR;
  # }
end
