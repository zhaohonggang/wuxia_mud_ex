defmodule Kantele.Combat.Skills.Performs.YinsuoJinling.Feng do
  @moduledoc """
  perform「风神诀」（source yinsuo-jinling/feng.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "yinsuo-jinling/feng"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "yinsuo-jinling")
    improve = 0
    n = 0
    m = 0
    ap = Stats.skill(stats, "whip")

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
      Stats.skill(stats, "force") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "yinsuo-jinling") < 140 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "whip") != "yinsuo-jinling" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 400 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 30}
    vitals = %{vitals | neili: vitals.neili - 300}
    vitals = %{vitals | neili: vitals.neili - 50}
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
    Performs.feedback(attacker, 50, 1)
    result = Messages.interpolate("$n只觉鞭影重重，眼花缭乱，根本无法作出抵挡，一声惨嚎，鲜血飞溅而出！
$n稍一迟疑，突然感到后背一阵刮骨之痛，已被这招打得血肉模糊！
只听“当”的一声，正打在$p上，$p手腕一麻，再也拿持不住，脱手掉在地上。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-30"}, {"neili", "-300"}, {"neili", "-50"}], "assign_refs": [{"ap", "whip"}, {"damage", "whip"}, {"dp", "dodge"}, {"dp", "force"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(2 + random(4));"], "level_gates": [{"force", "200"}, {"yinsuo-jinling", "140"}], "map_gates": [{"whip", "yinsuo-jinling"}], "remote_damage": true, "resource_gates": [{"neili", "400"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define FENG "「" HIW "风神诀" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         object weapon, weapon2;
  #         string w1, w2;
  #         int ap, dp;
  # 
  #         float improve;
  #         int lvls, m, n;
  #         string martial;
  #         string *ks;
  #         martial = "whip";
  # 
  #         me = this_player();
  # 
  #         if (userp(me) && ! me->query("can_perform/yinsuo-jinling/feng"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(FENG "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "whip")
  #                 return notify_fail("你的武器不对，无法使用" FENG "。\n");
  # 
  #         if (me->query_skill_mapped("whip") != "yinsuo-jinling")
  #                 return notify_fail("你没有激发回银索金铃，不能使用" FENG "。\n");
  # 
  #         if ((int)me->query_skill("yinsuo-jinling", 1) < 140)
  #                 return notify_fail("你的银索金铃不够娴熟，还使不出" FENG "。\n");
  # 
  #         if ((int)me->query_skill("force") < 200)
  #                 return notify_fail("你的内功火候不够，难以施展" FENG "。\n");
  # 
  #         if ((int)me->query("neili") < 400)
  #                return notify_fail("你现在真气不够，难以施展" FENG "。\n"NOR);
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         w1 = weapon->name();
  # 
  #         lvls = to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3));
  #         lvls = lvls * 4 / 5;
  #         ks = keys(me->query_skills(martial));
  #         improve = 0;
  #         n = 0;
  #         //最多给予5个技能的加成
  #         for (m = 0; m < sizeof(ks); m++)
  #         {
  #             if (SKILL_D(ks[m])->valid_enable(martial))
  #             {
  #                 n += 1;
  #                 improve += (int)me->query_skill(ks[m], 1);
  #                 if (n > 4 )
  #                     break;
  #             }
  #         }
  # 
  #         improve = improve * 5 / 100 / lvls;
  # 
  #         damage = (int)me->query_skill("whip") / 2;
  #         damage += random(damage);
  # 
  #         ap = me->query_skill("whip");
  #         dp = target->query_skill("parry");
  # 
  #         ap += ap * improve;
  # 
  #         msg = "\n" HIW "只见$N" HIW "手中" + w1
  #               + HIW "暮地一抖，幻出无数鞭影，霎"
  #               "时破风声骤起，" + w1 + HIW "携着"
  #               "风雷之势扫向$n" HIW "！\n" NOR;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 35,
  #                                            HIR "$n" HIR "只觉鞭影重重，眼花缭乱"
  #                                            "，根本无法作出抵挡，一声惨嚎，鲜血飞"
  #                                            "溅而出！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "镇定自如，"
  #                        "丝毫不为这变幻莫测的招式所动"
  #                        "，凝神抵挡，化解开来！\n" NOR;
  #         }
  # 
  #         ap = me->query_skill("whip");
  #         dp = target->query_skill("dodge");
  # 
  #         msg += "\n" HIW "紧接着$N" HIW "一声"
  #                "娇喝，" + w1 + HIW "猛地向后"
  #                "一撤，" + w1 + HIW "顿时化作"
  #                "一道长虹，已从$n" HIW "背后"
  #                "袭出！\n" NOR;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 42,
  #                                            HIR "$n" HIR "稍一迟疑，突然感到后背"
  #                                            "一阵" HIR "刮骨之痛，已被这招打得血"
  #                                            "肉模糊！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "$p" CYN "一声冷哼，早预料$N"
  #                        CYN "有此一着，凝神聚气，将这招轻"
  #                        "轻格开！\n" NOR;
  #         }
  # 
  #         if (objectp(weapon2 = target->query_temp("weapon")))
  #         {
  #                 msg += "\n" HIW "$N" HIW "眉头微皱，手"
  #                        "腕轻轻一振，只听“飕”的一声，"
  #                        "又攻出一招，" + w1 + HIW "如流"
  #                        "星般弹向$n" HIW "腕部！\n" NOR;
  # 
  #                 ap = me->query_skill("whip");
  #                 dp = target->query_skill("force");
  # 
  #                 if (ap / 4 + random(ap) > dp)
  #                 {
  #                         w2 = weapon2->name();
  #                         msg += HIR "只听“当”的一声，" + w1 +
  #                                HIR "正打在$p" + w2 + HIR "上，"
  #                                "$p" HIR "手腕一麻，" + w2 + HIR
  #                                "再也拿持不住，脱手掉在地上。\n"
  #                                NOR;
  #                         me->add("neili", -50);
  #                         weapon2->move(environment(target));
  #                 } else
  #                 {
  #                         msg += CYN "可是$p" CYN "看破了$P" CYN
  #                                "的企图，急忙斜跳躲开！\n" NOR;
  #                         me->add("neili", -30);
  #                 }
  #         }
  #         me->start_busy(2 + random(4));
  #         me->add("neili", -300);
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
