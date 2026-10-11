defmodule Kantele.Combat.Skills.Performs.ChousuiZhang.Shi do
  @moduledoc """
  perform「shi」（source chousui-zhang/shi.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "chousui-zhang/shi"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "chousui-zhang")
    lvp = Stats.skill(stats, "poison")

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
         :ok <- check_mapped(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "throwing") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "chousui-zhang" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 1200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 200}
    vitals = %{vitals | neili: vitals.neili - 300}
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

  # TODO(migrate) 目标侧结算：命中/闪避/伤害公式与文案需按原始源码（见文末）补齐。
  #   target->receive_damage("jing", damage / 4)  # UNSUPPORTED: unknown ident damage
  #   target->receive_wound("jing", damage / 8)  # UNSUPPORTED: unknown ident damage

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    _stats = character.meta.stats
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 300, 4)
    result = Messages.interpolate("$N随手抓起，将「腐尸毒」毒质运于其上，朝$n猛掷而去。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}, {"neili", "-300"}], "affect_by": ["corpse_poison"], "assign_refs": [{"ap", "strike"}, {"dp", "dodge"}, {"lvl", "chousui-zhang"}, {"lvp", "poison"}], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);"], "level_gates": [{"throwing", "180"}], "map_gates": [{"strike", "chousui-zhang"}], "prepared_gates": [{"strike", "chousui-zhang"}], "remote_damage": true, "resource_gates": [{"max_neili", "1200"}, {"neili", "500"}], "var_gates": [{"lvl", "140"}, {"lvl", "200"}, {"lvl", "250"}, {"lvp", "200"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define SHI "「" NOR + WHT "腐尸毒" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # string final(object me, object target, int damage);
  # 
  # int perform(object me, object target)
  # {
  #         object *corpse;
  #         int lvl, lvp, damage;
  #         int ap, dp;
  #         string name, msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/chousui-zhang/shi"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(SHI "只能对战斗中的对手使用。\n");
  # 
  #         if (userp(me) && (me->query_temp("weapon")
  #            || me->query_temp("secondary_weapon")))
  #                 return notify_fail(SHI "只能空手施展。\n");
  # 
  #         lvl = me->query_skill("chousui-zhang", 1);
  #         //lvp = me->query_skill("poison");
  #         lvp = me->query_skill("poison",1);
  # 
  #         if (lvl < 140)
  #                 return notify_fail("你的抽髓掌不够娴熟，难以施展" SHI "。\n");
  # 
  #         if (lvp < 200)
  #                 return notify_fail("你对毒技的了解不够，难以施展" SHI "。\n");
  # 
  #         if ((int)me->query_skill("throwing") < 180)
  #                 return notify_fail("你暗器手法火候不够，难以施展" SHI "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "chousui-zhang")
  #                 return notify_fail("你没有激发抽髓掌，难以施展" SHI "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "chousui-zhang")
  #                 return notify_fail("你没有准备抽髓掌，难以施展" SHI "。\n");
  # 
  #         if ((int)me->query("max_neili") < 1200)
  #                 return notify_fail("你的内力修为不足，难以施展" SHI "。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你现在的内息不足，难以施展" SHI "。\n");
  # 
  #         corpse = filter_array(all_inventory(environment(me)),
  #                              (: base_name($1) == CORPSE_OB
  #                              && ($1->query("defeated_by") == this_player()
  #                              || ! $1->query("defeated_by")) :));
  # 
  #         //if (userp(me) && sizeof(corpse) < 1)
  #         if (userp(me) && sizeof(corpse) < 1 && lvl < 200)
  #                 return notify_fail("你附近没有合适的尸体，难以施展" SHI "。\n");
  # 
  #         // 允许等级 250 以上的任务 NPC 施展此招
  #         //if (! userp(me) && lvl < 250 && sizeof(corpse) < 1)
  #                 //return notify_fail("你附近没有合适的尸体，难以施展" SHI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         if (sizeof(corpse) >= 1)
  #                 name = corpse[0]->name();
  #         else
  #                 name = "路边的行人";
  # 
  #         msg = WHT "$N" WHT "随手抓起" + name + WHT "，将「"
  #               HIR "腐尸毒" NOR + WHT"」毒质运于其上，朝$n"
  #               WHT "猛掷而去。\n" NOR;
  # 
  #         ap = me->query_skill("strike") +
  #              //me->query_skill("poison");
  #              me->query_skill("poison",1);
  # 
  #         // 将任务NPC和玩家区分，再计算防御状况
  #         if (userp(me))
  #                 dp = target->query_skill("dodge") +
  #                      target->query_skill("martial-cognize",1);
  #         else
  #                 dp = target->query_skill("dodge") +
  #                      //target->query_skill("parry");
  #                      target->query_skill("parry",1);
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 2);
  #                 msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 75,
  #                                           (: final, me, target, damage :));
  #                 me->start_busy(3);
  #                 me->add("neili", -300);
  #         } else
  #         {
  #                 msg += CYN "可是$n" CYN "见势不妙，急忙腾挪身形，终"
  #                        "于避开了$N" CYN "掷来的尸体。\n" NOR;
  #                 me->start_busy(4);
  #                 me->add("neili", -200);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         if (sizeof(corpse) >= 1)
  #                 destruct(corpse[0]);
  # 
  #         return 1;
  # }
  # 
  # string final(object me, object target, int damage)
  # {
  #         //int lvp = me->query_skill("poison") * 2 / 3;
  #         int lvp = me->query_skill("poison",1);
  # 
  #         target->affect_by("corpse_poison",
  #                 ([ "level"    : lvp + random(lvp),
  #                    "id"       : me->query("id"),
  #                    "duration" : 5 + random(lvp / 20) ]));
  # 
  #         target->receive_damage("jing", damage / 4, me);
  #         target->receive_wound("jing", damage / 8, me);
  # 
  #         return  HIR "$n" HIR "只闻一股恶臭传来，大惊之下难以招"
  #                 "架，顿被尸体击个正中。\n" NOR;
  # }
end
