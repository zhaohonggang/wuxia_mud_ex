defmodule Kantele.Combat.Skills.Performs.CanheZhi.Canhe do
  @moduledoc """
  perform「参合剑气」（source canhe-zhi/canhe.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "canhe-zhi/canhe"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "canhe-zhi")
    improve = 0
    n = 0
    m = 0
    damage = (Stats.skill(stats, "finger") + Stats.skill(stats, "force"))
    ap = Stats.skill(stats, "finger")

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
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "canhe-zhi") < 220 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "force") < 320 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 6000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 900 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 6)
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
    Performs.feedback(attacker, 0, 6)
    result = Messages.interpolate("但见$n斜斜一指点出，指出如风，剑气纵横，嗤然作响，竟将$N的剑气全部折回，反向自己射去！
你听到「嗤啦」一声轻响，脸上竟溅到一些血滴！

顿时只听“嗤啦”的一声，$n躲闪不及，剑气顿时穿胸而过，带出一蓬血雨。

忽见$n左手小指一伸，一招「少泽剑」至指尖透出，真气鼓荡，轻灵迅速，顿将$N剑气逼回！
你听到「嗤啦」一声轻响，脸上竟溅到一些血滴！

只听$n一声惨嚎，被$N的剑气刺中了要害，血肉模糊，鲜血迸流不止。

可电光火石之间，$n猛然翻掌，右手陡然探出，中指「中冲剑」向$N一竖，登将参合剑气化于无形！
你听到「嗤啦」一声轻响，脸上竟溅到一些血滴！

$n奋力招架，仍是不敌，$N的无形剑气已透体而入，鲜血飞射，无力再战。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"assign_refs": [{"ap", "finger"}, {"clv", "canhe-zhi"}, {"damage", "finger"}, {"dp", "dodge"}, {"dp", "force"}, {"dp", "parry"}, {"slv", "liumai-shenjian"}], "busy_lines": ["me->start_busy(3 + random(3));", "&&! target->is_busy()", "&&! target->is_busy()", "&&! target->is_busy()", "me->start_busy(6);"], "level_gates": [{"canhe-zhi", "220"}, {"force", "320"}], "prepared_gates": [{"finger", "canhe-zhi"}], "remote_damage": true, "resource_gates": [{"max_neili", "6000"}, {"neili", "900"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # #include "/kungfu/skill/eff_msg.h";
  # 
  # #define CANHE "「" HIW "参合剑气" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         int ap, dp, slv, clv, p;
  # 
  #         float improve;
  #         int lvl, m, n;
  #         string martial;
  #         string *ks;
  #         martial = "finger";
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/canhe-zhi/canhe"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(CANHE "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(me->query_temp("weapon")))
  #                 return notify_fail("你必须空手才能使用" CANHE "。\n");
  # 
  #         if (clv = (int)me->query_skill("canhe-zhi", 1) < 220)
  #                 return notify_fail("你的参合指修为有限，难以施展" CANHE "。\n");
  # 
  #         if (me->query_skill_prepared("finger") != "canhe-zhi")
  #                 return notify_fail("你现在没有准备使用参合指，难以施展" CANHE "。\n");
  # 
  #         if ((int)me->query_skill("force") < 320)
  #                 return notify_fail("你的内功修为太差，难以施展" CANHE "。\n");
  # 
  #         if ((int)me->query("max_neili") < 6000)
  #                 return notify_fail("你的内力修为不足，难以施展" CANHE "。\n");
  # 
  #         if ((int)me->query("neili") < 900)
  #                 return notify_fail("你的真气不够，难以施展" CANHE "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         lvl = to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3));
  #         lvl = lvl * 4 / 5;
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
  #         improve = improve * 5 / 100 / lvl;
  # 
  #         damage = me->query_skill("finger") + me->query_skill("force");
  #         damage += random(damage);
  #         slv = target->query_skill("liumai-shenjian", 1);
  # 
  #         ap = me->query_skill("finger");
  #         dp = target->query_skill("dodge");
  # 
  #         ap += ap * improve;
  # 
  #         msg = HIW "只见$N" HIW "十指分摊，霎时破空声骤响，数股剑气至指尖激"
  #               "射而出，朝$n" HIW "径直奔去！\n" NOR;
  # 
  #         me->start_busy(3 + random(3));
  # 
  #         if (slv >= 140
  #             && random(5) == 0
  #             && slv >= clv - 60 // 如果参合指等级比六脉神剑等级高60级以上取消特殊效果
  #             &&! target->is_busy()
  #             && target->query_skill_prepared("finger") == "liumai-shenjian")
  #         {
  #                 msg += HIY "\n但见$n" HIY "斜斜一指点出，指出如风，剑气纵横，嗤然"
  #                        "作响，竟将$N" HIY "的剑气全部折回，反向自己射去！\n" NOR +
  #                        HIR "你听到「嗤啦」一声轻响，脸上竟溅到一些血滴！\n" NOR;
  # 
  #                 me->receive_wound("qi", slv / 3 + random(slv / 4), target);
  #                 p = (int)me->query("qi") * 100 / (int)me->query("max_qi");
  #                 msg += "( $N" + eff_status_msg(p) + ")\n";
  # 
  #         } else
  #         if (ap * 3 / 4 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 64,
  #                                            HIR "\n顿时只听“嗤啦”的一声，$n" HIR
  #                                            "躲闪不及，剑气顿时穿胸而过，带出一蓬"
  #                                            "血雨。\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "\n$n" CYN "见$N" CYN "来势汹涌，急忙飞身一跃而"
  #                        "起，避开了这一击。\n" NOR;
  #         }
  # 
  #         ap = me->query_skill("finger");
  #         dp = target->query_skill("force");
  # 
  #         if (slv >= 160
  #             && random(8) == 0
  #             && slv >= clv - 60  // 如果参合指等级比六脉神剑等级高60级以上取消特殊效果
  #             &&! target->is_busy()
  #             && target->query_skill_prepared("finger") == "liumai-shenjian")
  #         {
  #                 msg += HIY "\n忽见$n" HIY "左手小指一伸，一招「少泽剑」至指尖透出"
  #                        "，真气鼓荡，轻灵迅速，顿将$N" HIY "剑气逼回！\n" NOR + HIR
  #                        "你听到「嗤啦」一声轻响，脸上竟溅到一些血滴！\n" NOR;
  # 
  #                 me->receive_wound("qi", slv / 2 + random(slv / 4), target);
  #                 p = (int)me->query("qi") * 100 / (int)me->query("max_qi");
  #                 msg += "( $N" + eff_status_msg(p) + ")\n";
  # 
  #         } else
  #         if (ap * 3 / 4 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 75,
  #                                            HIR "\n只听$n" HIR "一声惨嚎，被$N" HIR
  #                                            "的剑气刺中了要害，血肉模糊，鲜血迸流不"
  #                                            "止。\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "\n$n" CYN "见$N" CYN "来势汹涌，急忙飞身一跃而"
  #                        "起，避开了这一击。\n" NOR;
  #         }
  # 
  #         ap = me->query_skill("finger");
  #         dp = target->query_skill("parry");
  # 
  #         if (slv >= 180
  #             && random(10) == 0
  #             && slv >= clv - 50  // 如果参合指等级比六脉神剑等级高50级以上取消特殊效果
  #             &&! target->is_busy()
  #             && target->query_skill_prepared("finger") == "liumai-shenjian")
  #         {
  #                 msg += HIY "\n可电光火石之间，$n" HIY "猛然翻掌，右手陡然探出，中"
  #                        "指「中冲剑」向$N" HIY "一竖，登将参合剑气化于无形！\n" NOR
  #                        + HIR "你听到「嗤啦」一声轻响，脸上竟溅到一些血滴！\n" NOR;
  # 
  #                 me->receive_wound("qi", slv / 2 + random(slv / 2), target);
  #                 p = (int)me->query("qi") * 100 / (int)me->query("max_qi");
  #                 msg += "( $N" + eff_status_msg(p) + ")\n";
  #                 me->start_busy(6);
  # 
  #         } else
  #         if (ap * 2 / 3 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 100,
  #                                            HIR "\n$n" HIR "奋力招架，仍是不敌，$N"
  #                                            "的" HIR "无形剑气已透体而入，鲜血飞射"
  #                                            "，无力再战。\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "\n$n" CYN "见$N" CYN "来势汹涌，急忙飞身一跃而"
  #                        "起，避开了这一击。\n" NOR;
  #         }
  #         me->add("neili", -400 - random(100));
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
