defmodule Kantele.Combat.Skills.Performs.JinwuGoufa.Duo do
  @moduledoc """
  perform「金钩夺魄」（source jinwu-goufa/duo.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "jinwu-goufa/duo"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jinwu-goufa")
    damage = (-1)

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
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
      Stats.skill(stats, "jinwu-goufa") < 160 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "jinwu-goufa" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 300 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 200}
    vitals = %{vitals | neili: vitals.neili - 50}
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
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 50, 4)
    result = Messages.interpolate("只见$N这一击来势好快，寒光一闪，正钩中$n的咽喉，$n一声惨叫，软绵绵的瘫了下去。
( $n受伤过重，已经有如风中残烛，随时都可能断气。)
只听“嗤啦”一声，$n手腕被钩个正中，手中再也捉拿不住，脱手而飞！
$n飞身躲闪，然而只听“嗤啦”一声，$N的正钩在$n上，顿时鲜血狂溅而出。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}, {"neili", "-50"}], "assign_refs": [{"ap", "jinwu-goufa"}, {"damage", "force"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(2 + random(2));", "me->start_busy(2 + random(2));", "target->start_busy(2);", "me->start_busy(4);"], "level_gates": [{"jinwu-goufa", "160"}], "map_gates": [{"sword", "jinwu-goufa"}], "remote_damage": true, "resource_gates": [{"neili", "300"}], "var_gates": [{"damage", "0"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define DUO "「" HIY "金钩夺魄" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon, weapon2;
  #         int damage;
  #         string  msg;
  #         string  pmsg;
  #         string *limbs;
  #         string  limb;
  #         int ap, dp;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/jinwu-goufa/duo"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(DUO "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，无法施展" DUO "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "jinwu-goufa") 
  #                 return notify_fail("你没有激发金蜈钩法，无法施展" DUO "。\n");
  # 
  #         if ((int)me->query_skill("jinwu-goufa", 1) < 160)
  #                 return notify_fail("你的金蜈钩法还不够娴熟，无法施展" DUO "。\n");
  #                                 
  #         if ((int)me->query("neili", 1) < 300)
  #                 return notify_fail("你现在真气不够，无法施展" DUO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "突然$N" HIY "一声冷哼，手中" + weapon->name() +
  #               NOR + HIY "挥出，在空中划出个美丽的弧线，直攻$n" HIY
  #               "的要穴！\n" NOR;
  #         me->add("neili", -50);
  # 
  #         ap = me->query_skill("jinwu-goufa", 1) +
  #              me->query_skill("sword", 1) / 2;
  #         dp = target->query_skill("parry");
  # 
  #         me->want_kill(target);
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 me->start_busy(2 + random(2));
  #                 me->add("neili", -200);
  #                 damage = 0;
  # 
  #                 if (me->query("max_neili") > target->query("max_neili") * 2)
  #                 {
  #                         msg += HIR "只见$N" HIR "这一击来势好快，寒光一"
  #                                "闪，正钩中$n" HIR "的咽喉，$n" HIR "一声"
  #                                "惨叫，软绵绵的瘫了下去。\n" NOR "( $n" RED
  #                                "受伤过重，已经有如风中残烛，随时都可能断"
  #                                "气。" NOR ")\n";
  #                         damage = -1;
  #                 } else
  #                 if (objectp(weapon2 = target->query_temp("weapon")) &&
  #                 me->query_skill("sword") > target->query_skill("parry"))
  #                 {
  #                         // if(userp(me))
  #                         msg += HIR "只听“嗤啦”一声，$n" HIR "手腕被"
  #                               "钩个正中，手中" + weapon2->name() + NOR
  #                               + HIR "再也捉拿不住，脱手而飞！\n" NOR;
  #                         me->start_busy(2 + random(2));
  #                         target->start_busy(2);
  #                         weapon2->move(environment(target));
  #                 } else
  #                 {
  #                         damage = ap + (int)me->query_skill("force");
  #                         damage = damage / 2 + random(damage / 2);
  #                         
  #                         if (arrayp(limbs = target->query("limbs")))
  #                                 limb = limbs[random(sizeof(limbs))];
  #                         else
  #                                 limb = "要害";
  #                         pmsg = HIR "$n" HIR "飞身躲闪，然而只听“嗤啦”"
  #                                "一声，$N" HIR "的" + weapon->name()+ NOR
  #                                + HIR "正钩在$n" HIR + limb + "上，顿时鲜"
  #                                "血狂溅而出。\n" NOR;
  #                         msg += COMBAT_D->do_damage(me, target,
  #                                WEAPON_ATTACK, damage, 40, pmsg);
  #                 }
  #         } else 
  #         {
  #                 me->start_busy(4);
  #                 msg += CYN "可是$p" CYN "看破了$P"
  #                        CYN "的企图，避开了这一招。\n"NOR;
  #         }
  # 
  #         message_combatd(msg, me, target);
  #         if (damage < 0) target->die(me);
  # 
  #         return 1;
  # }
end
