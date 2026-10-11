defmodule Kantele.Combat.Skills.Performs.YiyangZhi.Die do
  @moduledoc """
  perform「阳关三叠」（source yiyang-zhi/die.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "yiyang-zhi/die"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "yiyang-zhi")
    improve = 0
    n = 0
    m = 0
    ap = Stats.skill(stats, "finger")
    damage = (ap + Engine.rand(rng, ap))

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
      Stats.skill(stats, "force") < 300 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "jingluo-xue") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "yiyang-zhi") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "finger") != "yiyang-zhi" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 5000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 1000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 400}
    vitals = %{vitals | neili: vitals.neili - 50}
    vitals = %{vitals | neili: vitals.neili - 80}
    vitals = %{vitals | neili: 0}
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
    Performs.feedback(attacker, 80, 1)
    result = Messages.interpolate("霎时间$n只觉得手腕一麻，手中再也拿持不住，脱手掉在地上。

紧接着$N凝气于指，一式「阳关三叠」点出，顿时一股纯阳的内力直袭$n胸口！
结果$n被$N一指点中，全身真气逆流而上，登时呕出一大口鲜血。
结果$n被$N一指点中，全身真气逆流而上，登时呕出一大口鲜血。
结果$n被$N一指点中，全身真气逆流而上，登时呕出一大口鲜血。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-400"}, {"neili", "-50"}, {"neili", "-80"}], "assign_refs": [{"ap", "finger"}, {"dp", "dodge"}, {"dp", "force"}, {"dp", "parry"}], "busy_lines": ["//me->start_busy(4 + random(4));", "me->start_busy(3 + random(3));"], "level_gates": [{"force", "300"}, {"jingluo-xue", "200"}, {"yiyang-zhi", "200"}], "map_gates": [{"finger", "yiyang-zhi"}], "prepared_gates": [{"finger", "yiyang-zhi"}], "remote_damage": true, "resource_gates": [{"max_neili", "5000"}, {"neili", "1000"}], "set_flags": [{"neili", "0"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define DIE "「" HIR "阳关三叠" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # string *xue_name = ({
  # "劳宫穴", "膻中穴", "曲池穴", "关元穴", "曲骨穴", "中极穴",
  # "承浆穴", "天突穴", "百会穴", "幽门穴", "章门穴", "大横穴",
  # "紫宫穴", "冷渊穴", "天井穴", "极泉穴", "清灵穴", "至阳穴", });
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg, wp;
  #         object weapon;
  #         int ap, dp;
  # 
  #         float improve;
  #         int lvl, m, n;
  #         string martial;
  #         string *ks;
  #         martial = "finger";
  # 
  #         if (userp(me) && ! me->query("can_perform/yiyang-zhi/die"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(DIE "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(DIE "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("yiyang-zhi", 1) < 200)
  #                 return notify_fail("你一阳指诀不够娴熟，难以施展" DIE "。\n");
  # 
  #         if ((int)me->query_skill("jingluo-xue", 1) < 200)
  #                 return notify_fail("你对经络学了解不够，难以施展" DIE "。\n");
  # 
  #         if (me->query_skill_mapped("finger") != "yiyang-zhi")
  #                 return notify_fail("你没有激发一阳指诀，难以施展" DIE "。\n");
  # 
  #         if (me->query_skill_prepared("finger") != "yiyang-zhi")
  #                 return notify_fail("你没有准备一阳指诀，难以施展" DIE "。\n");
  # 
  #         if ((int)me->query_skill("force") < 300)
  #                 return notify_fail("你的内功火候不够，难以施展" DIE "。\n");
  # 
  #         if (me->query("max_neili") < 5000)
  #                 return notify_fail("你的内力修为不足，难以施展" DIE "。\n");
  # 
  #         if ((int)me->query("neili") < 1000)
  #                 return notify_fail("你现在的真气不够，难以施展" DIE "。\n");
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
  #         ap = me->query_skill("finger");
  #         dp = target->query_skill("parry");
  # 
  #         ap += ap * improve;
  #         damage = ap + random(ap);
  # 
  #         msg = HIW "突然间";
  # 
  #         if (objectp(weapon = target->query_temp("weapon")))
  #         {
  #                 wp = weapon->name();
  #                 msg += "$N" HIW "单指一扬，径点$n" HIW "持着" + wp + NOR + HIW
  #                        "的手腕上「" HIY "腕骨" HIW "」、「" HIY "阳谷" HIW "」"
  #                        "、「" HIY "养老" HIW "」三穴。\n" NOR;
  # 
  #                 ap = me->query_skill("finger");
  #                 dp = target->query_skill("force");
  #                 ap += ap * improve;
  # 
  #                 if (ap / 3 + random(ap) > dp)
  #                 {
  #                         msg += HIR "霎时间$n" HIR "只觉得手腕一麻，手中" + wp +
  #                                HIR "再也拿持不住，脱手掉在地上。\n\n" HIW "紧"
  #                                "接着";
  #                         me->add("neili", -80);
  #                         weapon->move(environment(target));
  #                 } else
  #                 {
  #                         msg += CYN "可是$n" CYN "将手中" + wp + NOR + CYN "转"
  #                                "动如轮，终于化解了这一招。\n\n" HIW "紧接着";
  #                         me->add("neili", -50);
  #                 }
  #         }
  # 
  #         msg += "$N" HIW "凝气于指，一式「" HIR "阳关三叠" HIW "」点出，顿时一股"
  #                "纯阳的内力直袭$n" HIW "胸口！\n" NOR;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70,
  #                                            HIR "结果$n" HIR "被$N" HIR "一指点中"
  #                                            HIY + xue_name[random(sizeof(xue_name))] +
  #                                            HIR "，全身真气逆流而上，登时呕出一大"
  #                                            "口鲜血。\n" NOR);
  # 
  #         target->add_temp("yiyang-zhi/die", 1);
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "镇定自如，全力化解了$P"
  #                        CYN "这精妙的一指。\n" NOR;
  #         }
  # 
  #         ap = me->query_skill("finger");
  #         dp = target->query_skill("dodge");
  #         ap += ap * improve;
  # 
  #         msg += "\n" HIW "接着$N" HIW "踏前一步，体内真气迸发，隔空一指劲点$n" HIW
  #                "而去，指气纵横，嗤然作响！\n" NOR;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80,
  #                                            HIR "结果$n" HIR "被$N" HIR "一指点中"
  #                                            HIY + xue_name[random(sizeof(xue_name))] +
  #                                            HIR "，全身真气逆流而上，登时呕出一大"
  #                                            "口鲜血。\n" NOR);
  # 
  #         target->add_temp("yiyang-zhi/die", 1);
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "镇定自如，全力化解了$P"
  #                        CYN "这精妙的一指。\n" NOR;
  #         }
  # 
  #         ap = me->query_skill("finger");
  #         dp = target->query_skill("force");
  #         ap += ap * improve;
  # 
  #         msg += "\n" HIW "最后$N" HIW "一声猛喝，单指“嗤”的一声点出，纯阳指力同"
  #                "时笼罩$n" HIW "全身诸多要穴！\n" NOR;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 90,
  #                                            HIR "结果$n" HIR "被$N" HIR "一指点中"
  #                                            HIY + xue_name[random(sizeof(xue_name))] +
  #                                            HIR "，全身真气逆流而上，登时呕出一大"
  #                                            "口鲜血。\n" NOR);
  # 
  #         target->add_temp("yiyang-zhi/die", 1);
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "镇定自如，全力化解了$P"
  #                        CYN "这精妙的一指。\n" NOR;
  #         }
  # 
  #         if (target->query_temp("yiyang-zhi/die", 1) == 3
  #            && target->query("neili"))
  #         {
  #                 msg += HIY "\n$n" HIY "被$N" HIY "三指连中，全身真气涣"
  #                        "散，宛如黄河决堤，内力登时狂泻而出。\n\n" NOR;
  #         target->set("neili", 0);
  #         }
  #         //me->start_busy(4 + random(4));
  #         me->start_busy(3 + random(3));
  #         me->add("neili", -400);
  #         target->delete_temp("yiyang-zhi/die");
  #         message_combatd(msg, me, target);
  # 
  #         if (! target->query("neili"))
  #                 tell_object(target, HIC "你只觉丹田内竟似空空如也，一时"
  #                                     "说不出的难受。\n" NOR);
  # 
  #         return 1;
  # }
end
