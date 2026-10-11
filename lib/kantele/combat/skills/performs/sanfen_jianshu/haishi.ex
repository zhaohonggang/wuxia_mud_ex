defmodule Kantele.Combat.Skills.Performs.SanfenJianshu.Haishi do
  @moduledoc """
  perform「haishi」（source sanfen-jianshu/haishi.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "sanfen-jianshu/haishi"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "sanfen-jianshu")
    ap = Stats.skill(stats, "sword")
    damage = (div(ap, 2) + Engine.rand(rng, div(ap, 2)))

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
      Stats.skill(stats, "dodge") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "sanfen-jianshu") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "sword") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 150}
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
    Performs.feedback(attacker, 150, 1)
    result = Messages.interpolate("$n完全无法辨清虚实，只感一阵触心的刺痛，一声惨叫，已被$N凌厉的剑招刺中。

$N见$n重创之下不禁破绽迭出，冷笑一声，手中挥洒，又攻出一剑，正中$p胸口。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-150"}], "assign_refs": [{"ap", "sword"}, {"dp", "dodge"}], "busy_lines": ["me->start_busy(1 + random(2));"], "level_gates": [{"dodge", "150"}, {"sanfen-jianshu", "150"}, {"sword", "150"}], "remote_damage": true, "resource_gates": [{"neili", "200"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // haishi.c 海市蜃楼
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  #  
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  # //      int delta;
  #  
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (userp(me) && ! me->query("can_perform/sanfen-jianshu/haishi"))
  #                 return notify_fail("你不会使用「海市蜃楼」这一绝技！\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("「海市蜃楼」只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对。\n");
  # 
  #         if (me->query_skill("sword", 1) < 150)
  #                 return notify_fail("你的剑术修为不够，目前不能使用「海市蜃楼」！\n");
  # 
  #         if (me->query_skill("sanfen-jianshu", 1) < 150)
  #                 return notify_fail("你的三分剑术的修为不够，不能使用这一绝技！\n");
  # 
  #         if (me->query_skill("dodge",1) < 150)
  #                 return notify_fail("你的轻功修为不够，无法使用「海市蜃楼」！\n");
  #  
  #         if (me->query("neili") < 200)
  #                 return notify_fail("你的真气不够！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "狂喝一声，手中" + weapon->name() +
  #               HIW "将到之际，突然圈转，使出三分剑术的独得之秘"
  #               "「海市蜃楼」，一招之中\n又另蕴涵三招，招式繁复狠"
  #               "辣，剑招虚虚实实，霍霍剑光径直逼向$n"
  #               HIW "！\n\n" NOR;
  # 
  #         me->add("neili", -150);
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("dodge");
  #         me->start_busy(1 + random(2));
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap / 2 + random(ap);
  #                 msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 70,
  #                                            HIR "$n" HIR "完全无法辨清虚实，只感一阵触心的刺痛，一声惨叫，已被$N"
  #                                            HIR "凌厉的剑招刺中。\n" NOR);
  #                 if (ap / 3 + random(ap) > dp)
  #                 {
  #                         //damage /= 2;
  #                         damage = ap / 2 + random(ap / 2);
  #                         msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 80,
  #                                                    HIR "\n$N" HIR "见$n" HIR "重创之下不禁破绽迭出，"
  #                                                    HIR "冷笑一声，手中" + weapon->name() +
  #                                                    HIR "挥洒，又攻出一剑，正中$p" HIR "胸口。\n" NOR);
  #                 }
  #         } else
  #         {
  #                 msg += HIC "$n" HIC "见状身形急退，避开了$N"
  #                        HIC "凌厉的攻击！\n" NOR;
  #         }
  # 
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
