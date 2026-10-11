defmodule Kantele.Combat.Skills.Performs.TaixuanGong.Jing do
  @moduledoc """
  perform「白首太玄经」（source taixuan-gong/jing.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "taixuan-gong/jing"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "taixuan-gong")
    flag = 0

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
      Stats.skill(stats, "blade") < 340 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "force") < 340 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "martial-cognize") < 260 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "sword") < 340 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "blade") != "taixuan-gong" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      Stats.mapped(stats, "sword") != "taixuan-gong" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 10000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 850 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
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
  #   target->receive_damage("jing", damage / 2)  # UNSUPPORTED: unknown ident damage
  #   target->receive_wound("jing", damage / 4)  # UNSUPPORTED: unknown ident damage

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    _stats = character.meta.stats
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"assign_refs": [{"ap", "blade"}, {"ap", "sword"}, {"dp", "dodge"}, {"dp", "force"}, {"dp", "unarmed"}, {"lvl", "taixuan-gong"}], "busy_lines": ["me->start_busy(2 + random(3));", "target->start_busy(4 + random(lvl / 40));"], "level_gates": [{"blade", "340"}, {"force", "340"}, {"martial-cognize", "260"}, {"sword", "340"}], "map_gates": [{"blade", "taixuan-gong"}, {"sword", "taixuan-gong"}], "remote_damage": true, "resource_gates": [{"max_neili", "10000"}, {"neili", "850"}], "var_gates": [{"lvl", "340"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define JING "「" HIW "白首太玄经" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # string final1(object me, object target, int damage, object weapon, int lvl);
  # string final2(object me, object target, int damage);
  # string final3(object me, object target, int damage, object weapon, int lvl, string msg);
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg, sub_msg;
  #         int ap, dp;
  #         object weapon;
  #         int flag = 0;
  #         int lvl;
  # 
  #         if (userp(me) && ! me->query("can_perform/taixuan-gong/jing"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(JING "只能对战斗中的对手使用。\n");
  # 
  #         if ((! objectp(weapon = me->query_temp("weapon"))) ||
  #             ((string)weapon->query("skill_type") != "sword" 
  #             && (string)weapon->query("skill_type") != "blade"))
  #                 return notify_fail("你使用的武器不对，难以施展" JING "。\n");
  # 
  #         if ((int)me->query_skill("force", 1) < 340)
  #                 return notify_fail("你内功修为不够，难以施展" JING "。\n");
  # 
  #         if ((int)me->query("max_neili") < 10000)
  #                 return notify_fail("你内力修为不够，难以施展" JING "。\n");
  # 
  #         lvl = (int)me->query_skill("taixuan-gong", 1);
  #         if (lvl < 340)
  #                 return notify_fail("你太玄功火候不够，难以施展" JING "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "taixuan-gong"
  #             && me->query_skill_mapped("blade") != "taixuan-gong")
  #                 return notify_fail("你没有激发太玄功为刀或剑，难以施展" JING "。\n");
  # 
  #         // 分别判断激发刀剑时需要的刀、剑等级。
  #         if (me->query_skill_mapped("sword") == "taixuan-gong")
  #         {               
  #                 if (me->query_skill("sword", 1) < 340)
  #                         return notify_fail("你的基本剑法火候不足，难以施展" JING "。\n");
  # 
  #                 else 
  #                 {
  #                        flag = 1; // 设置激发为sword标志
  #                        sub_msg = "剑";
  #                 }
  #         }
  #         else // 激发为刀
  #         {
  #                 if (me->query_skill("blade", 1) < 340)
  #                         return notify_fail("你的基本刀法火候不足，难以施展" JING "。\n");
  #                 else 
  #                 {
  #                        flag = 0; // 设置激发为blade标志
  #                        sub_msg = "刀";
  #                 }
  #         }
  # 
  #         if ((int)me->query("neili") < 850)
  #                 return notify_fail("你现在真气不够，难以施展" JING "。\n");
  # 
  #         if (me->query_skill("martial-cognize", 1) < 260)
  #                 return notify_fail("你武学修养不足，难以施展" JING "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         message_sort(HIM "\n$N" HIM "情不自禁的纵声长啸，霎时之间，千百种招式纷至沓来，涌"
  #                      "向心头。$N" HIM "随手挥舞，已是不按次序，但觉无论何种招式皆能随心所欲"
  #                      "，既不必存想内息，亦不须记忆招数，石壁上的千百种招式，自然而然的从心"
  #                      "中传向手足，尽数袭向$n" HIM "。\n" NOR, me, target);
  # 
  # 
  #         if (flag)ap = lvl + me->query_skill("sword", 1);
  #         else ap = lvl + me->query_skill("blade", 1);
  # 
  #         // 第一招，判断对方臂力
  #         dp = target->query_str() * 2 + target->query_skill("unarmed", 1) + 
  #              target->query_skill("parry", 1);
  # 
  #         message_sort(HIW "\n$N" HIW "突然间只觉得右肋下‘渊液穴’上一动，一道热线沿着‘足少"
  #                      "阳胆经’，向着‘日月’、‘京门’二穴行去，一招‘十步杀一人’的" + sub_msg + 
  #                      "法已随意使出，各种招式源源而出，将$n" HIW "笼罩。\n" NOR, me, target);
  # 
  #         if (ap * 4 / 5 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap);
  #                 msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 80 + random(10),
  #                                          (: final1, me, target, damage, weapon, lvl :));
  #         } else
  #         {
  #                 msg = HIC "$n" HIC "气贯双臂，凝神以对，竟将$N" HIC "之力卸去。\n" NOR;
  #         }
  #         message_sort(msg, me, target);
  # 
  #         // 第二招，判断对方悟性
  #         dp = target->query_int() * 2 + target->query_skill("dodge", 1) 
  #              + target->query_skill("parry", 1);
  # 
  #         message_sort(HIW "\n$N" HIW "肌肤如欲胀裂，内息不由自主的依着‘赵客缦胡缨’那套经脉运"
  #                      "行图谱转动，同时手舞足蹈，似是大欢喜，又似大苦恼。\n" NOR, me);
  # 
  #         if (ap * 4 / 5 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap);
  #                 msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 95 + random(10),
  #                                           HIY "$n" HIY "冷笑一声，觉得$N" HIY "此招肤浅之极，于"
  #                                           "是随意招架，猛然间，「噗嗤」！一声，" + weapon->name() +
  #                                           HIY "已穿透$n" HIY "的胸膛，鲜血不断涌出。\n" NOR, me , target);
  #         } else
  #         {
  #                 msg = HIC "$n" HIC "会心一笑，看出$N" HIC "这招中的破绽，随意施招竟将这招化去。\n" NOR;
  #         }
  #         message_sort(msg, me, target);
  # 
  #         // 第三招，判断对方根骨
  #         dp = target->query_con() * 2 + target->query_skill("force", 1) + 
  #              target->query_skill("parry", 1);
  # 
  #         message_sort(HIW "\n‘赵客缦胡缨’既毕，接下去便是‘吴钩霜雪明’，$N" HIW "更"
  #                     "不思索，石壁上的图谱一幅幅在脑海中自然涌出，自‘银鞍照白马’直到‘谁能书阁下’，"
  #                     "一气呵成的使了出来。\n" NOR, me);
  # 
  #         if (ap * 4 / 5 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap);
  #                 msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 80 + random(10),
  #                                            (: final2, me, target, damage :));
  #         } else
  #         {
  #                 msg = HIC "$n" HIC "默运内功，内劲贯于全身，奋力抵挡住$N" HIC "这招。\n" NOR;
  #         }
  #         message_sort(msg, me, target);
  # 
  #         // 第四招，判断对方身法
  #         dp = target->query_dex() * 2 + target->query_skill("dodge", 1) + 
  #              target->query_skill("parry", 1);
  # 
  #         message_sort(HIW "\n待得‘谁能书阁下’这套功夫演完，$N" HIW "只觉气息逆转"
  #                      "，‘不惭世上英’倒使上去。\n" NOR, me);
  # 
  #         if (ap * 4 / 5 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap);
  #                 msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 80 + random(10),
  #                                           (: final3, me, target, damage, weapon, lvl, sub_msg :));
  #         } else
  #         {
  #                 msg = HIC "$n" HIC "见这招来势凶猛，身形疾退，瞬间飘出三"
  #                       "丈，方才躲过$N" HIC "这招。\n" NOR;
  #         }
  #         message_sort(msg, me, target);
  # 
  #         me->start_busy(2 + random(3));
  #         me->add("neili", -400 - random(400));
  #         return 1;
  # }
  # 
  # string final1(object me, object target, int damage, object weapon, int lvl)
  # {
  #         target->add("neili", -(lvl + random(lvl)));
  # 
  #         return  HIY "$n" HIY "却觉$N" HIY "这招气势恢弘，于是运力奋力抵挡。但是无奈这"
  #                 "招威力惊人，$n" HIY "闷哼一声，倒退几步，顿觉内息涣散，" + weapon->name() + HIY 
  #                 "上早已染满鲜血！\n" NOR;
  # }
  # 
  # string final2(object me, object target, int damage)
  # {
  #         target->receive_damage("jing", damage / 2, me);
  #         target->receive_wound("jing", damage / 4, me);
  #         return  HIY "$n" HIY "心中一惊，但见$N" HIY "这几招奇异无比，招式变化莫测，"
  #                 "但威力却依然不减，正犹豫间，$n" HIY "却已中招，顿感精力不济，浑"
  #                 "身无力。\n" NOR;
  # }
  # 
  # string final3(object me, object target, int damage, object weapon, int lvl, string msg)
  # {
  #    
  #         target->start_busy(4 + random(lvl / 40));
  #   
  #         return  HIY "$N" HIY + msg + "法奇妙无比，手中" + weapon->name() + HIY "时而宛若游龙，时而"
  #                 "宛若惊鸿，霎那间$n" HIY "已遍体鳞伤，$N" HIY "猛然将手中" + weapon->name() + HIY "一"
  #                 "转，剑势陡然加快，将$n" HIY "团团围住，竟无一丝空隙！\n" NOR;
  # 
  # }
end
