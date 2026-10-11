defmodule Kantele.Combat.Skills.Performs.MantianXing.Xing do
  @moduledoc """
  perform「穹外飞星」（source mantian-xing/xing.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "mantian-xing/xing"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "mantian-xing")
    n = (2 + Engine.rand(rng, 2))

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
      Stats.skill(stats, "force") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "mantian-xing") < 80 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 1200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 150 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 3)
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
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "parry")
    vitals = character.meta.vitals
        vitals = Vitals.damage(vitals, :qi, 150)
        vitals = Vitals.wound(vitals, :qi, 50)
        vitals = Vitals.damage(vitals, :qi, 100)
        vitals = Vitals.wound(vitals, :qi, 40)
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 100, 3)
    result = Messages.interpolate("$N蓦地飞身跃起，十指箕张，施出「穹外飞星」将手中尽数凌空射出。
霎时破空声骤响，便如同陨星飞坠一般，笼罩$n各处大穴！
结果$n一声惨叫，同时中了$Pbase_unit，直感两耳轰鸣，目不视物。
$n集中生智，双手画圈回旋挥舞，拨弄开了要害处的杀着，可还是受了点轻伤。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}], "apply_adds": ["attack", "dodge", "parry"], "assign_refs": [{"skill", "mantian-xing"}], "busy_lines": ["me->start_busy(1 + random(2));", "me->start_busy(3);"], "level_gates": [{"force", "150"}, {"mantian-xing", "80"}], "remote_damage": false, "resource_gates": [{"max_neili", "1200"}, {"neili", "150"}], "temp_set": ["feixing"]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define XING "「" HIR "穹外飞星" NOR "」"
  # 
  # #include "/kungfu/skill/eff_msg.h";
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int skill/*, i*/, p, n;
  #         int my_exp, ob_exp;
  #         string pmsg;
  #         string msg;
  #         object weapon;
  # 
  #         if (playerp(me) && ! me->query("can_perform/mantian-xing/xing"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(XING "只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("handing")) ||
  #             (string)weapon->query("skill_type") != "throwing")
  #                 return notify_fail("你现在手中没有拿着暗器，难以施展" XING "。\n");
  # 
  #         if (weapon->query_amount() < 15)
  #                 return notify_fail("至少要有十五枚暗器才能施展" XING "。\n");
  # 
  #         if ((skill = me->query_skill("mantian-xing", 1)) < 80)
  #                 return notify_fail("你的满天星不够娴熟，难以施展" XING "。\n");
  # 
  #         if ((int)me->query_skill("force") < 150)
  #                 return notify_fail("你的内功修为不足，难以施展" XING "。\n");
  # 
  #         if ((int)me->query("max_neili") < 1200)
  #                 return notify_fail("你的内力修为不足，难以施展" XING "。\n");
  # 
  #         if ((int)me->query("neili") < 150)
  #                 return notify_fail("你现在真气不足，难以施展" XING "。\n");
  # 
  #         if ((int)target->query_temp("feixing"))
  #                 return notify_fail("对方已经中了你的绝招，现在是废人一个，赶快进攻吧！\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         me->add("neili", -100);
  #         weapon->add_amount(-15);
  # 
  #         msg = HIR "$N" HIR "蓦地飞身跃起，十指箕张，施出「穹外飞星」将"
  #               "手中" + weapon->name() + HIR "尽数凌空射出。\n霎时破空声"
  #               "骤响，" + weapon->name() + HIR "便如同陨星飞坠一般，笼罩"
  #               "$n" HIR "各处大穴！\n" NOR;
  # 
  #         my_exp = COMBAT_D->valid_power(me->query("combat_exp"));
  #         ob_exp = COMBAT_D->valid_power(target->query("combat_exp"));
  # 
  #         me->want_kill(target);
  #         if (my_exp / 2 + random(my_exp * 3 / 2) > ob_exp)
  #         {
  #                 if (target->query_skill("parry") < me->query_skill("throwing"))
  #                 {
  #                         n = 2 + random(2);
  #                         if (random(my_exp) > ob_exp) n += 1 + random(2);
  #                         if (random(my_exp / 2) > ob_exp) n += 1 + random(2);
  #                         if (random(my_exp / 4) > ob_exp) n += 1 + random(2);
  # 
  #                         msg += HIR "结果$n" HIR "一声惨叫，同时中了$P" HIR +
  #                                chinese_number(n) + weapon->query("base_unit") +
  #                                weapon->name() + HIR "，直感两耳轰鸣，目不视"
  #                                "物。\n" NOR;
  # 
  #                         while (n--)
  #                         {
  #                                 COMBAT_D->clear_ahinfo();
  #                                 weapon->hit_ob(me, target,
  #                                                me->query("jiali") + 100 + n * 10);
  #                         }
  # 
  #                         target->set_temp("feixing", 1);
  #                         target->add_temp("apply/attack", -70);
  #                         target->add_temp("apply/dodge", -70);
  #                         target->add_temp("apply/parry", -20);
  #                         target->receive_damage("qi", 150, me);
  #                         target->receive_wound("qi", 50, me);
  # 
  #                         p = (int)target->query("qi") * 100 / (int)target->query("max_qi");
  # 
  #                         if (stringp(pmsg = COMBAT_D->query_ahinfo()))
  #                                 msg += pmsg;
  # 
  #                         msg += "( $n" + eff_status_msg(p) + " )\n";
  #                         message_combatd(msg, me, target);
  # 
  #                         tell_object(target, RED "你现在要穴受到重损，乃至全身"
  #                                             "乏力，提不上半点力道！\n" NOR);
  #                         tell_object(me, HIC "你心知刚才这招已打中对方要寒，不"
  #                                             "禁暗自冷笑。\n" NOR);
  # 
  #                         target->kill_ob(me);
  #                         call_out("back", 2 + random(skill / 15), target);
  #                 } else
  #                 {
  #                         msg += HIR "$n" HIR "集中生智，双手画圈回旋挥舞，拨弄"
  #                                "开了要害处的杀着，可还是受了点轻伤。\n" NOR;
  # 
  #                         target->receive_damage("qi", 100);
  #                         target->receive_wound("qi", 40);
  # 
  #                         p = (int)target->query("qi") * 100 / (int)target->query("max_qi");
  #                         msg += "( $n" + eff_status_msg(p) + " )\n";
  #                         message_combatd(msg, me, target);
  # 
  #                         tell_object(target, RED "你只觉全身几处一阵刺痛，知道"
  #                                             "自己虽被击中，但却是避开了要穴。"
  #                                             "\n" NOR);
  #                         target->kill_ob(me);
  #                         me->start_busy(1 + random(2));
  #                 }
  #         } else
  #         {
  #                  msg += CYN "可是$n" CYN "小巧腾挪，好不容易避开了"
  #                         CYN "$N" CYN "铺天盖地的攻击。\n" NOR;
  #                  me->start_busy(3);
  #                  message_combatd(msg, me, target);
  #         }
  #         return 1;
  # }
  # 
  # void back(object target)
  # {
  #         if (objectp(target))
  #         {
  #                 target->add_temp("apply/attack", 70);
  #                 target->add_temp("apply/dodge", 70);
  #                 target->add_temp("apply/parry", 20);
  #                 tell_object(target, HIY "渐渐的你觉得力气一丝丝的恢复了。\n" NOR);
  #                 target->delete_temp("feixing");
  #         }
  # }
end
