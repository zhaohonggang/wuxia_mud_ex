defmodule Kantele.Combat.Skills.Performs.JiuyinShengong.Zhen do
  @moduledoc """
  perform「真·天诛龙蛟诀」（source jiuyin-shengong/perform/zhen.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：目标为战斗中的对手 → 装备鞭类武器 → 内功>=300 →
  九阴神功>=220 → 内力>=400 → 激发鞭法为九阴神功 → 目标存活。
  ap = 鞭法 + 内功 + 武学常识；dp = 内功 + 招架 + 武学常识。
  起手文案被 `+ weapon->name() +` 拆成两段字面量。
  命中：伤害 ap + random(ap/2)、扣 300 内力、忙乱 2、100% 外伤；
  未命中：扣 100 内力、忙乱 3。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs
  alias Kantele.Character.Vitals

  @perform_id "jiuyin-shengong/zhen"
  @move_name "「真·天诛龙蛟诀」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jiuyin-shengong")
    ap = Stats.skill(stats, "whip") + Stats.skill(stats, "force") + Stats.skill(stats, "martial-cognize")
    damage = ap + Engine.rand(rng, div(ap, 2))

    with {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_mapped(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
          damage: damage,
          rng: rng
        }
      })

      apply_effect(conn, character, target)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (!objectp(weapon = me->query_temp("weapon")) ||
  #          weapon->query("skill_type") != "whip")
  defp check_weapon(combat) do
    case Combat.weapon(combat) do
      %{skill_type: "whip"} -> :ok
      _ -> {:error, "你使用的武器不对。\n"}
    end
  end

  # LPC: if (me->query_skill("force") < 300) / if (me->query_skill("jiuyin-shengong", 1) < 220)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 300 ->
        {:error, "你的内功火候不够，使不了#{@move_name}。\n"}

      Stats.skill(stats, "jiuyin-shengong") < 220 ->
        {:error, "你的九阴神功功力太浅，使不了#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    if character.meta.vitals.neili < 400 do
      {:error, "你的真气不够，无法使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("whip") != "jiuyin-shengong")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "whip") != "jiuyin-shengong" do
      {:error, "你没有激发九阴神功为鞭法，使不了#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  # LPC: 起手文案（`+ weapon->name() +` 拆成两段字面量，E 侧须保持同样拆分）
  defp apply_effect(conn, character, target) do
    weapon = Combat.weapon(character.meta.combat)
    weapon_name = Map.get(weapon, :name)

    lead =
      "$N诡异的一笑，手中" <> weapon_name <>
        "犹如一条银龙猛然飞向$n，正是九阴真经中的绝招「真·天诛龙蛟诀」！\n"

    conn
    |> Broadcast.publish(Messages.interpolate(lead, [n1: character.name, n2: target.name]))
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    damage = max(Map.get(data, :damage, 0), 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("force") + target->query_skill("parry")
    #          + target->query_skill("martial-cognize", 1);
    dp = Stats.skill(stats, "force") + Stats.skill(stats, "parry") + Stats.skill(stats, "martial-cognize")

    if div(ap * 11, 20) + Engine.rand(rng, ap) > dp do
      # LPC: 命中：do_damage(me, target, WEAPON_ATTACK, damage, 100, ...)
      character = apply_damage(character, damage, 100)
      Performs.feedback(attacker, 300, 2)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "结果$n一声惨叫，未能看破$N的企图，被这一鞭硬击在胸口，鲜血飞溅，皮肉绽开！\n",
          bindings
        )
      )
      |> put_character(character)
    else
      # LPC: 未命中：me->add("neili", -100); me->start_busy(3);
      Performs.feedback(attacker, 100, 3)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "可是$p飞身一跃而起，躲避开了$P的攻击！\n",
          bindings
        )
      )
      |> put_character(character)
    end
  end

  # LPC: COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, percent, msg)
  # wound = damage * percent / 100（armor 未建模，按 percent 直算）
  defp apply_damage(character, damage, percent) do
    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage * percent, 100))

    %{character | meta: %{character.meta | vitals: vitals}}
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define DUO "「" HIC "真·天诛龙蛟诀" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg;
  #     int ap, dp;
  #     int damage;
  # 
  #     //if (playerp(me) && ! me->query("can_perform/yinlong-bian/zhu"))
  #     //return notify_fail("你使用的外功中没有这种功能。\n");
  # 
  #     if (!target)
  #         target = offensive_target(me);
  # 
  #     if (!target || !me->is_fighting(target))
  #         return notify_fail(DUO "只能在战斗中对对手使用。\n");
  # 
  #     if (!objectp(weapon = me->query_temp("weapon")) ||
  #         weapon->query("skill_type") != "whip")
  #         return notify_fail("你使用的武器不对。\n");
  # 
  #     if (me->query_skill("force") < 300)
  #         return notify_fail("你的内功火候不够，使不了" DUO "。\n");
  # 
  #     if (me->query_skill("jiuyin-shengong", 1) < 220)
  #         return notify_fail("你的九阴神功功力太浅，使不了" DUO "。\n");
  # 
  #     if (me->query("neili") < 400)
  #         return notify_fail("你的真气不够，无法使用" DUO "。\n");
  # 
  #     if (me->query_skill_mapped("whip") != "jiuyin-shengong")
  #         return notify_fail("你没有激发九阴神功为鞭法，使不了" DUO "。\n");
  # 
  #     if (!living(target))
  #         return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIW "$N" HIW "诡异的一笑，手中" + weapon->name() +
  #           HIW "犹如一条银龙猛然飞向$n" HIW "，正是九阴真经中的"
  #               "绝招「" HIC "真·天诛龙蛟诀" HIW "」！\n" NOR;
  # 
  #     ap = me->query_skill("whip") + me->query_skill("force") + me->query_skill("martial-cognize", 1);
  #     dp = target->query_skill("force") + target->query_skill("parry") + target->query_skill("martial-cognize", 1);
  # 
  #     if (ap * 11 / 20 + random(ap) > dp)
  #     {
  #         damage = ap + random(ap / 2);
  #         me->add("neili", -300);
  #         me->start_busy(2);
  # 
  #         msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 100,
  #                                    HIR "结果$n" HIR "一声惨叫，未能看破$N" HIR "的企图，被这一鞭硬击在胸口，鲜血飞"
  #                                        "溅，皮肉绽开！\n" NOR);
  #         message_combatd(msg, me, target);
  #     }
  #     else
  #     {
  #         me->add("neili", -100);
  #         me->start_busy(3);
  #         msg += CYN "可是$p" CYN "飞身一跃而起，躲避开了" CYN "$P" CYN "的攻击！\n" NOR;
  #         message_combatd(msg, me, target);
  #     }
  # 
  #     return 1;
  # }
end
