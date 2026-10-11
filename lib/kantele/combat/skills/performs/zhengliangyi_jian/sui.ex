defmodule Kantele.Combat.Skills.Performs.ZhengliangyiJian.Sui do
  @moduledoc """
  perform「玉碎昆冈」（source zhengliangyi-jian/sui.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "zhengliangyi-jian/sui"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "zhengliangyi-jian")
    ap = Stats.skill(stats, "sword")
    damage = 0

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
      Stats.skill(stats, "force") < 250 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "zhengliangyi-jian") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "zhengliangyi-jian" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 3000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | max_neili: vitals.max_neili - 50}
    vitals = %{vitals | neili: 0}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 6)
    combat = Combat.start_busy(combat, 8)
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
    Performs.feedback(attacker, 0, 8)
    result = Messages.interpolate("可是$n一声冷哼，飞身闪开来招，又顺势转身一掌拍向$N面门。
只听“喀嚓”一声，$n那掌正好打在$N头顶，$N哀嚎一声，软软的瘫倒。
$n眼见$N来势如此凶悍，这一招决计无法抵挡，骇怖达于极点，竟致僵立，束手待毙。
只听“噗嗤”一声，已然透过$n前胸而入，喷出一股血雨。
$n眼见$N来势如此凶悍，只觉这一招决计无法抵挡，骇怖达于极点，慌乱之中一掌猛拍而出，击
向$N面门，竟也是同归于尽的招数。只听“噗嗤”一声，已然透过$n前胸，喷出一股血雨。
同时$n那一掌也正好打在$N头顶，听得“喀嚓”一声，$N头盖骨完全碎裂，软软的瘫倒。
$n眼见$N来势如此凶悍，只觉这一招决计无法抵挡，急忙飞身闪避，然而只听“嗤啦”一声，那
柄已然刺穿，喷出一股血雨。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"max_neili", "-50"}], "assign_refs": [{"ap", "sword"}, {"damage", "force"}, {"dp", "force"}], "busy_lines": ["me->start_busy(6);", "target->start_busy(2 + random(6));", "me->start_busy(8);"], "level_gates": [{"force", "250"}, {"zhengliangyi-jian", "180"}], "map_gates": [{"sword", "zhengliangyi-jian"}], "remote_damage": true, "resource_gates": [{"max_neili", "3000"}, {"neili", "200"}], "set_flags": [{"neili", "0"}], "temp_set": ["die_reason"]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define SUI "「" HIW "玉碎昆冈" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         int damage;
  #         string msg;
  #         string pmsg;
  #         string *limbs;
  #         string  limb;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/zhengliangyi-jian/sui"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(SUI "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，无法施展" SUI "。\n");
  # 
  #         if ((int)me->query_skill("zhengliangyi-jian", 1) < 180)
  #                 return notify_fail("你的正两仪剑法不够娴熟，难以施展" SUI "。\n");
  # 
  #         if ((int)me->query_skill("force") < 250)
  #                 return notify_fail("你的内功火候不足，难以施展" SUI "。\n");
  # 
  #         if (me->query("max_neili") < 3000)
  #                 return notify_fail("你的内力修为不足，难以施展" SUI "。\n");
  # 
  #         if (me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不够，难以施展" SUI "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "zhengliangyi-jian") 
  #                 return notify_fail("你没有激发正两仪剑法，难以施展" SUI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "仰天一声惨笑，将" + weapon->name() + HIY
  #               "剑尖指向自己胸口，剑柄斜斜向外，连人带剑电射而出，直"
  #               "扑$n" HIY "而去！\n" NOR;
  #         me->add("max_neili", -50);
  # 
  #         me->want_kill(target);
  #         target->kill_ob(me);
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("force");
  # 
  #         if (ap / 2 + random(ap * 3 / 2) > dp)
  #         {
  #                 me->start_busy(6);
  #                 me->set("neili", 0);
  #                 me->add("max_neili", -random(50));
  #                 damage = 0;
  # 
  #                 if (ap < dp * 3 / 4 &&
  #                    me->query("max_neili") < target->query("max_neili") * 3 / 4)
  #                 {
  #                         msg += HIY "可是$n" HIY "一声冷哼，飞身闪开来招，又顺势转身一"
  #                                "掌拍向$N" HIY "面门。\n" NOR + HIR "只听“喀嚓”一声"
  #                                "，$n" HIR "那掌正好打在$N" HIR "头顶，$N" HIR "哀嚎一"
  #                                "声，软软的瘫倒。\n" NOR;
  #                         message_combatd(msg, me, target);
  #                         me->set_temp("die_reason", "使用一招玉碎昆冈，拼命不成，反被"
  #                                      + target->name() + "击毙");
  #                         me->die(target);
  #                         return 1;
  #                 } else
  #                 if (ap > dp &&
  #                    me->query("max_neili") > target->query("max_neili"))
  #                 {
  #                         msg += HIR "$n" HIR "眼见$N" HIR "来势如此凶悍，这一招决计无"
  #                                "法抵挡，骇怖达于极点，竟致僵立，束手待毙。\n只听“噗"
  #                                "嗤”一声，" + weapon->name() + HIR "已然透过$n" HIR
  #                                "前胸而入，喷出一股血雨。\n" NOR;
  #                         message_combatd(msg, me, target);
  #                         target->set_temp("die_reason", "被" + me->name() + "使一招玉"
  #                                          "碎昆冈刺死了");
  #                         target->die(me);
  #                         return 1;
  #                 } else
  #                 if (ap / 2 + random(ap * 2 / 3) > dp)
  #                 {
  #                         msg += HIR "$n" HIR "眼见$N" HIR "来势如此凶悍，只觉这一招决"
  #                                "计无法抵挡，骇怖达于极点，慌乱之中一掌猛拍而出，击\n"
  #                                "向$N" HIR "面门，竟也是同归于尽的招数。只听“噗嗤”一"
  #                                "声，" + weapon->name() + HIR "已然透过$n" HIR "前胸，"
  #                                "喷出一股血雨。\n同时$n" HIR "那一掌也正好打在$N" HIR
  #                                "头顶，听得“喀嚓”一声，$N" HIR "头盖骨完全碎裂，软软"
  #                                "的瘫倒。\n" NOR;
  #                         message_combatd(msg, me, target);
  #                         me->set_temp("die_reason", "使用一招玉碎昆冈与" +
  #                                      target->name() + "同归于尽了");
  #                         target->set_temp("die_reason", "被" + me->name() + "使一招玉"
  #                                          "碎昆冈，两人一块去见了黑白无常");
  #                         target->die(me);
  #                         me->die();
  #                         return 1;
  #                 } else
  #                 {
  #                         target->start_busy(2 + random(6));
  #         
  #                         damage = ap + (int)me->query_skill("force");
  #                         damage = damage / 2 + random(damage);
  # 
  #                         if (arrayp(limbs = target->query("limbs")))
  #                                 limb = limbs[random(sizeof(limbs))];
  #                         else
  #                                 limb = "要害";
  #                         pmsg = HIR "$n" HIR "眼见$N" HIR "来势如此凶悍，只觉这一招决"
  #                                "计无法抵挡，急忙飞身闪避，然而只听“嗤啦”一声，那\n"
  #                                "柄" + weapon->name() + HIR "已然刺穿" + limb + HIR "，"
  #                                "喷出一股血雨。\n" NOR;
  #                         msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage,
  #                                150, pmsg);
  #                 }
  #         } else 
  #         {
  #                 me->start_busy(8);
  #                 msg += HIY "可是$n" HIY "早已料到$N"
  #                        HIY "有此一着，身形急动，躲开"
  #                        "了这一杀着。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
