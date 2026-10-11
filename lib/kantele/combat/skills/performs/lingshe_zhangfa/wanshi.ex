defmodule Kantele.Combat.Skills.Performs.LingsheZhangfa.Wanshi do
  @moduledoc """
  perform「wanshi」（source lingshe-zhangfa/wanshi.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "lingshe-zhangfa/wanshi"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "lingshe-zhangfa")
    ap = Stats.skill(stats, "staff")
    damage = (ap + Engine.rand(rng, div(ap, 4)))

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
      Stats.skill(stats, "lingshe-zhangfa") < 160 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "staff") != "lingshe-zhangfa" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
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
    vitals = %{vitals | neili: vitals.neili - 100}
    vitals = %{vitals | neili: vitals.neili - 350}
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
    damage = Map.get(data, :damage, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "parry")
    hit = div(ap, 2) + Engine.rand(rng, ap) > dp
    vitals = character.meta.vitals
    if hit do
          vitals = Vitals.damage(vitals, :jing, div(damage, 4))
          vitals = Vitals.wound(vitals, :jing, div(damage, 8))
    end

    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 350, 1)
    result = if hit, do: Messages.interpolate("", n1: attacker.name, n2: character.name), else: Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-350"}, {"poison_applied", "-1"}], "assign_refs": [{"ap", "staff"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(2 + random(4));"], "level_gates": [{"lingshe-zhangfa", "160"}], "map_gates": [{"staff", "lingshe-zhangfa"}], "remote_damage": true, "resource_gates": [{"neili", "400"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // wanshi.c 灵蛇杖法「千蛇万噬」
  # // by jeeny
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # //#define LINGSHE_ZHANG    "/clone/weapon/lingshe"
  # #define LINGSHE_ZHANG    "d/baituo/obj/lingshezhang"
  # 
  # inherit F_SSERVER;
  # 
  # string final(object me, object target, int damage, object weapon);
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  #         
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/lingshe-zhangfa/wanshi"))
  #                 return notify_fail("你还不会使用「千蛇万噬」这一绝技。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("「千蛇万噬」只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "staff")
  #                 return notify_fail("你使用的武器不对。\n");
  # 
  # 
  #         if ((int)me->query_skill("lingshe-zhangfa", 1) < 160)
  #                 return notify_fail("你的灵蛇杖法不够娴熟，不会使用「千蛇万噬」。\n");
  # 
  #         if (me->query("neili") < 400)
  #                 return notify_fail("你现在真气不够，无法使用「千蛇万噬」。\n");
  # 
  #         if (me->query_skill_mapped("staff") != "lingshe-zhangfa") 
  #                 return notify_fail("你没有激发灵蛇杖法，无法使用「千蛇万噬」！\n");
  # 
  #         if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIB "$N" HIB "手持" + weapon->name() + HIB "，直捣$n中宫" HIB "。\n" NOR;
  # 
  #         ap = me->query_skill("staff");
  #         dp = target->query_skill("parry");
  #         
  #         if (target->is_good()) ap += ap / 10;
  # 
  #         me->start_busy(2 + random(4));
  #         if (ap / 3 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 4);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
  #                                            (: final, me, target, damage, weapon :));
  #                 me->add("neili", -350);
  #                 if (LINGSHE_ZHANG->query("poison_applied") > 0 && weapon == find_object("/d/baituo/obj/lingshezhang"))
  #                 {
  #                         target->apply_condition("snake_poison", ap / 2, me);
  #                         LINGSHE_ZHANG->add("poison_applied", -1);
  #                 }
  #         } else
  #         {
  #                 msg += HIG "可是$p" HIG "看破了$P" HIG "的企图，一"
  #                        "缩胸，急退三步，避开了这一招。\n" NOR;
  #                 me->add("neili", -100);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
  # 
  # string final(object me, object target, int damage, object weapon)
  # {
  #         target->receive_damage("jing", damage / 4, me);
  #         target->receive_wound("jing", damage / 8, me);
  #         return HIW "哪知" HIW + weapon->name() + HIW "突然拐弯，绕到$p" HIW "背后，"
  #                 "重重地击在了$p" HIW "的颈脖子上！\n"
  #                 HIB "$p" HIB "“噗”地吐出一口鲜血，随"
  #                 HIB "即只觉脖颈一阵麻痒。\n" NOR;
  # }
end
