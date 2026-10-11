defmodule Kantele.Combat.Skills.Performs.LiumaiShenjian.Zong do
  @moduledoc """
  perform「万剑纵横」（source liumai-shenjian/zong.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "liumai-shenjian/zong"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "liumai-shenjian")
    skill = Stats.skill(stats, "liumai-shenjian")
    ap = (Stats.skill(stats, "liumai-shenjian") + Stats.skill(stats, "jingluo-xue"))
    damage = (div((ap * 3), 2) + Engine.rand(rng, ap))

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
      Stats.skill(stats, "force") < 480 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 8500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 1000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 400}
    vitals = %{vitals | neili: vitals.neili - 600}
    vitals = %{vitals | neili: vitals.neili - 800}
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

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    _stats = character.meta.stats
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 800, 4)
    result = Messages.interpolate("只听$n一声惨叫，万道剑气已透体而过，伤口处鲜血顿时狂涌，痛苦难当！
$n奋力抵挡，却哪里招架得住，被$N这一指戳得鲜血迸流！
接着$N拇指一屈，食指随即点出，嗤嗤两声急响，「商阳剑」激射刺出。
$n试图抵挡，只听哧的一声，无形剑气已破体而入，透体而出！
$n一愣，只听哧啦的一声，已被剑气划得鲜血飞溅！
$n躲闪不及，被戳了碗口大个血窟窿，鲜血喷涌而出！
$n运气抵挡，只觉得一股透体凉意袭了上来，一个激凌，丹田立刻变得空空荡荡！
$n已然放弃抵抗，任凭气流摧袭只盼望一切早点结束....", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-400"}, {"neili", "-600"}, {"neili", "-800"}], "assign_refs": [{"ap", "finger"}, {"ap", "liumai-shenjian"}, {"damage", "finger"}, {"dp", "dodge"}, {"dp", "force"}, {"dp", "parry"}, {"skill", "liumai-shenjian"}], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);", "me->start_busy(4);", "me->start_busy(3 + random(4));"], "level_gates": [{"force", "480"}], "prepared_gates": [{"finger", "liumai-shenjian"}], "remote_damage": true, "resource_gates": [{"max_neili", "8500"}, {"neili", "1000"}], "var_gates": [{"skill", "260"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define ZONG "「" HIM "万剑纵横" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int ap, dp;
  #         int damage, skill;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/liumai-shenjian/zong"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZONG "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_skill_prepared("finger") != "liumai-shenjian")
  #                 return notify_fail("你没有准备使用六脉神剑，无法施展" ZONG "。\n");
  # 
  #         skill = me->query_skill("liumai-shenjian", 1);
  # 
  #         if (skill < 260)
  #                 return notify_fail("你的六脉神剑修为有限，无法使用" ZONG "！\n");
  # 
  #         if (me->query_skill("force") < 480)
  #                 return notify_fail("你的内功火候不够，难以施展" ZONG "！\n");
  # 
  #         if (me->query("max_neili") < 8500)
  #                 return notify_fail("你的内力修为不够,无法施展" ZONG "！\n");
  # 
  #         if (me->query("neili") < 1000)
  #                 return notify_fail("你的真气不够，现在无法施展" ZONG "！\n");
  # 
  #         if (me->query_temp("weapon"))
  #                 return notify_fail("你必须是空手才能施展" ZONG "！\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  # 
  #         msg = HIM "$N" HIM "一声清啸，十指纷弹，顿觉六脉剑谱已涌上心头，此起"
  #               "彼伏、连绵不绝。霎时剑气如奔，连绵无尽的万道剑气豁然贯向$n" HIM
  #               "！\n" NOR;
  # /*
  #         ap = me->query_skill("finger") + me->query_skill("force");
  #         dp = target->query_skill("parry") + target->query_skill("force");
  #         me->start_busy(3);
  # 
  #         if ((int)target->query_skill("jingluo-xue", 1) >= 300
  #             && target->query_skill("dodge", 1) >= 300
  #             && random (10) == 1 )
  #         {
  #                 me->add("neili", -600);
  #                 me->start_busy(4);
  #                 msg += HIY "但见$n" HIY "会心一笑，轻拂衣袖，轻易的躲过这一招！\n"NOR;
  #         } else
  #         if (ap * 3 / 4 + random(ap) > dp)
  #         {
  #                 damage = ap * 3 / 2 + random(ap);
  #                 me->add("neili", -800);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 200,
  #                                            HIR "只听$n" HIR "一声惨叫，万道剑气已"
  #                                            "透体而过，伤口处鲜血顿时狂涌，痛苦难当！\n" NOR);
  #         } else
  #         {
  #                 me->add("neili", -400);
  #                 me->start_busy(4);
  #                 msg += CYN "$n" CYN "见$N" CYN "来势汹涌，不敢轻易"
  #                        "招架，急忙提气跃开。\n" NOR;
  #         }
  #         message_sort(msg, me, target);
  # 
  #         return 1;
  # */
  # 
  # 
  #   damage = (int)me->query_skill("finger",1)/2 + (int)me->query_skill("liumai-shenjian",1);
  # 
  # 
  #        // 第一招
  #         ap = me->query_skill("liumai-shenjian",1)+ me->query_skill("jingluo-xue", 1);
  #         dp = target->query_skill("parry",1) + target->query_skill("jingluo-xue", 1);
  # 
  #         msg += HIM "$N" HIM "双手拇指同时捺出，嗤嗤两声急响，「"+ HIY "少商剑"+ HIM "」有如石破天惊、风雨大至。\n" NOR ;
  # 
  #         if (ap * 3 / 4 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
  #                                            HIR "$n" HIR "奋力抵挡，却哪里招架得住，被$N"
  #                                            HIR "这一指戳得鲜血迸流！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "使出浑身解数，终于将$N"
  #                        CYN "这一指架开，丝毫无损。\n" NOR;
  #         }
  # 
  #         // 第二招
  #         ap = me->query_skill("liumai-shenjian",1) + me->query_skill("jingluo-xue", 1);
  #         dp = target->query_skill("parry",1)+ target->query_skill("jingluo-xue", 1);
  # 
  #         msg += HIY "接着" HIY "$N" HIY "拇指一屈，食指随即点出，嗤嗤两声急响，「" HIR "商阳剑" HIY "」激射刺出。\n"NOR;
  # 
  #         if (ap * 3 / 4 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
  #                                            HIR "$n" HIR "试图抵挡，只听哧的一声，"
  #                                            HIR "无形剑气已破体而入，透体而出！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "使出浑身解数，终于将$N"
  #                        CYN "这一指架开，丝毫无损。\n" NOR;
  #         }
  # 
  #         //// 第三招
  #         ap = me->query_skill("liumai-shenjian",1)+me->query_skill("jingluo-xue", 1);
  #         dp = target->query_skill("dodge",1)+target->query_skill("jingluo-xue", 1);
  # 
  #         msg += HIG "只见" HIG "$N" HIG "右手中指一竖，「" HIC "中冲剑" HIG "」向前刺出。真气鼓荡，嗤然声响，无形剑气直指$n。 \n"NOR;
  # 
  #         if (ap * 3 / 4 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 40,
  #                                            HIR "$n" HIR "一愣，只听哧啦的一声，"
  #                                            HIR "已被剑气划得鲜血飞溅！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "使出浑身解数，终于将$N"
  #                        CYN "这一指架开，丝毫无损。\n" NOR;
  #         }
  # 
  #         //// 第四招
  #         ap = me->query_skill("liumai-shenjian",1)+me->query_skill("jingluo-xue", 1);
  #         dp = target->query_skill("dodge",1)+target->query_skill("jingluo-xue", 1);
  # 
  #         msg += HIC "$N" HIC "无名指轻轻一挥，「嗤啦」一声，拙滞古朴的「" MAG "关冲剑" HIC "」剑气向" HIC"$n" HIC"直射而出。\n"NOR;
  # 
  #          if (ap * 3 / 4 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 40,
  #                                            HIR "$n" HIR "躲闪不及，被戳了碗口大个血窟窿，"
  #                                            HIR "鲜血喷涌而出！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "左闪右跳，终于将$N"
  #                        CYN "这一指避开，丝毫无损。\n" NOR;
  #         }
  # 
  # 
  #         //// 第五招
  #         ap = me->query_skill("liumai-shenjian",1)+ me->query_skill("jingluo-xue", 1);
  #         dp = target->query_skill("force",1)+target->query_skill("jingluo-xue", 1);
  # 
  #         msg += HIB "忽见$N" HIB "左手小指一伸，一条气流从少冲穴中激射而出，一股「" HIW "少泽剑" HIB "」登时射向$n。\n"NOR;
  # 
  #          if (ap * 3 / 4 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60,
  #                                            HIR "$n" HIR "运气抵挡，只觉得一股透体凉意"
  #                                            "袭了上来，一个激凌，丹田立刻变得空空荡荡！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "运气抵挡，硬生生接下了$N"
  #                        CYN "这一指。\n" NOR;
  #         }
  #         //// 第六招
  #         ap = me->query_skill("liumai-shenjian",1)+ me->query_skill("jingluo-xue", 1);
  #         dp = target->query_skill("force",1)+target->query_skill("jingluo-xue", 1);
  # 
  #         msg += HIW "最后"HIW "$N" HIW"右手小指一挥，一招「" HIG "少冲剑" HIW "」点点刺刺破空刺出，宛如雕花刺画一般。\n"NOR;
  # 
  #          if (ap * 3 / 4 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60,
  #                                            HIR "$n" HIR "已然放弃抵抗，任凭气流摧袭"
  #                                            "只盼望一切早点结束....\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "运气抵挡，终于接下了$N"
  #                        CYN "这一指，已是狼狈不堪。\n" NOR;
  #         }
  # 
  #         message_combatd(msg, me, target);
  #         me->add("neili", -800);
  #         me->start_busy(3 + random(4));
  # 
  #         return 1;
  # }
end
