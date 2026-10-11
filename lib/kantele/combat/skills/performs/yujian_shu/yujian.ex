defmodule Kantele.Combat.Skills.Performs.YujianShu.Yujian do
  @moduledoc """
  perform「yujian」（source yujian-shu/yujian.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "yujian-shu/yujian"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "yujian-shu")

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
      Stats.skill(stats, "force") < 400 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "sword") < 400 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 5000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 150 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 1500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    vitals = %{vitals | neili: vitals.neili - 1000}
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
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 1000, 1)
    result = Messages.interpolate("$n看到$N这气拔千钧的一击，竟不知如何招架，登时受了重创！
只听「嗤啦」一声，无形剑气竟在$n上身刺出一个血洞，数股血柱疾射而出！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-1000"}], "assign_refs": [{"damage", "sword"}], "busy_lines": ["me->start_busy(2 + random(4));"], "level_gates": [{"force", "400"}, {"sword", "400"}], "remote_damage": true, "resource_gates": [{"max_neili", "5000"}, {"neili", "150"}, {"neili", "1500"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         int damage;
  #         string msg;
  # 
  #         me->clean_up_enemy();
  #         if (! target) target = me->select_opponent();
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("御剑飞升只能对战斗中的对手使用。\n");
  # 
  #         if( me->query_temp("jueji/sword/feisheng") )
  #                 return notify_fail( WHT "你无法连续使用「御剑飞升」绝技！\n" NOR );
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对。\n");
  # 
  #         if ((int)me->query_skill("sword", 1) < 400)
  #                 return notify_fail("你的剑法尚达不到「御剑飞升」的境界。\n");
  # 
  #         if ((int)me->query_skill("force") < 400)
  #                 return notify_fail("你的内功火候尚达不到「御剑飞升」的境界。\n");
  # 
  #         if ((int)me->query("max_neili") < 5000)
  #                 return notify_fail("你的内力修为太弱，无法灵活的御驾内力。\n");
  # 
  #         if ((int)me->query("neili") < 1500)
  #                 return notify_fail("你现在内力不够。\n");
  # 
  #         msg = HIW "\n$N" HIW "一声巨喝，聚气入腕，只听破空声一响，手中"
  #              + weapon->name() + HIW "携着隐隐风雷之劲向$n" HIW "澎湃贯"
  #               "\n出，疾若电闪，势如雷霆。\n" NOR;
  # 
  #         damage = (int)me->query_skill("sword", 1) +
  #                  (int)me->query_skill("force", 1) +
  #                  (int)me->query_skill("parry", 1) +
  #                  (int)me->query_skill("martial-cognize", 1) / 2;
  # 
  #         damage = damage / 4 + random(damage / 4);
  # 
  #         me->start_busy(2 + random(4));
  #         me->set_temp("jueji/sword/feisheng", 1);
  #         call_out("end_perform2", 600, me, weapon, damage); 
  # 
  #         if (random(me->query_skill("force")) > target->query_skill("force") * 3 / 5)
  #         {
  #                 me->add("neili", -1000);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 20,
  #                                            HIR "$n" HIR "看到$N" HIR "这气拔千钧的一击，竟不"
  #                                            "知如何招架，登时受了重创！\n" NOR);
  #                 message_vision(msg, me, target);
  #                 remove_call_out("perform2");
  #                 call_out("perform2", 2, me);
  #                 return 1;
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "看破了$P" CYN "的企图，斜跃避开。\n" NOR;
  #                 message_vision(msg, me, target);
  #                 me->add("neili", -100);
  #                 remove_call_out("perform2");
  #                 call_out("perform2", 2, me, target);
  #                 return 1;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
  # 
  # int perform2(object me, object target)
  # {
  #         object weapon;
  #         int damage;
  #         string msg;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #         {
  #                 write(HIW "你运转内力，仰天一声清啸，剑在空中盘旋了一圈，又"
  #                       "飞回了你的手中。\n" NOR);
  #                 call_out("end_perform2", 1, me, weapon, damage); 
  #                 return 1;
  #         }
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #         {
  #                 write(HIW "你停止使用「御剑飞升」绝技。\n" NOR);
  #                 call_out("end_perform2", 30, me, weapon, damage); 
  #                 return 1;
  #         }
  # 
  #         if ((int)me->query("neili") < 150)
  #         {
  #                 write(HIW "你剑至中途，可怎奈内息不足，只好停止御剑。\n" NOR);
  #                 call_out("end_perform2", 30, me, weapon, damage); 
  #                 return 1;
  #         }
  # 
  #         msg = HIW "\n$N" HIW "手中御剑凌驾如飞，宛若游龙，灵转千变，一道道"
  #                   "凌厉剑气疾射而出。\n" NOR;
  # 
  #         if (random(me->query_skill("force")) > target->query_skill("force") / 2)
  #         {
  #                 damage = (int)me->query_skill("sword", 1) +
  #                          (int)me->query_skill("force", 1) +
  #                          (int)me->query_skill("parry", 1) +
  #                          (int)me->query_skill("martial-cognize", 1) / 2;
  # 
  #                 damage = damage / 5 + random(damage / 5);
  # 
  #                 me->add("neili", -100);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 20,
  #                                            HIR "只听「嗤啦」一声，" HIW "无形剑气" NOR +
  #                                            HIR "竟在$n" HIR "上身刺出一个血洞，数股血柱"
  #                                            "疾射而出！\n" NOR);
  #                 message_vision(msg, me, target);
  #                 remove_call_out("perform2");
  #                 call_out("perform2", 4, me);
  #                 return 1;
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "看破了$P" CYN "的企图，斜跃避开。\n" NOR;
  #                 message_vision(msg, me, target);
  #                 me->add("neili", -100);
  #                 remove_call_out("perform2");
  #                 call_out("perform2", 4, me);
  #                 return 1;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
  # 
  # void end_perform2(object me)
  # {
  #         if (! me) return;
  #         if (! me->query_temp("jueji/sword/feisheng")) return;
  #         me->delete_temp("jueji/sword/feisheng");
  #         tell_object(me, HIW "\n你经过调气养息，又可以继续使用「"
  #                         "御剑飞升」了。\n" NOR); 
  # }
end
