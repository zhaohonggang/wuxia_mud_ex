defmodule Kantele.Combat.Skills.Performs.JiuyinShengong.Zhua do
  @moduledoc """
  perform「九阴神爪」（source jiuyin-shengong/perform/zhua.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 空手 →
  九阴神功>=280 → 内力>=300 → 准备 claw 或 unarmed 为九阴神功 → 目标存活。
  ap = max(拳脚, 爪法) + 武学常识；dp = 招架 + 武学常识（目标侧）。
  起手扣 20 内力；命中再扣 180 内力、忙乱 2，并按双方最大内力分两支：
  - 内力碾压（max_neili > 目标*2）：打中檀中大穴，damage = -1 → target->die
    （模型化为气血清零 + 死亡标记）。
  - 常规：目标忙乱 1+random(3)，damage = (ap+内功)/2 + random(ap+内功)，110% 外伤，
    pmsg 被 `+ limb +` 拆成两段字面量，limb 取目标 limbs 随机、无则“要害”。
  未命中：忙乱 2。
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

  @perform_id "jiuyin-shengong/zhua"
  @move_name "「九阴神爪」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jiuyin-shengong")
    ap = max(Stats.skill(stats, "unarmed"), Stats.skill(stats, "claw")) + Stats.skill(stats, "martial-cognize")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_prepared(character),
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
          max_neili: character.meta.vitals.max_neili,
          force: Stats.skill(stats, "force"),
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

  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_temp("weapon")) return notify_fail(ZHUA "只能空手施展！\n");
  defp check_weapon(combat) do
    if Combat.weapon(combat) != nil do
      {:error, "#{@move_name}只能空手施展！\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("jiuyin-shengong", 1) < 280)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "jiuyin-shengong") < 280 do
      {:error, "你的九阴神功还不够娴熟，不能使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_resources(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你现在内力太弱，不能使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("claw") != "jiuyin-shengong"
  #          && me->query_skill_prepared("unarmed") != "jiuyin-shengong")
  # prepared_perform 返回绝招 ID（如 jiuyin-shengong/zhua），须取技能前缀比对
  defp check_prepared(character) do
    stats = character.meta.stats
    prepared_claw = Stats.prepared_perform(stats, "claw")
    prepared_unarmed = Stats.prepared_perform(stats, "unarmed")
    ok_claw = prepared_claw != nil and hd(String.split(prepared_claw, "/")) == "jiuyin-shengong"
    ok_unarmed = prepared_unarmed != nil and hd(String.split(prepared_unarmed, "/")) == "jiuyin-shengong"

    if not ok_claw and not ok_unarmed do
      {:error, "你没有准备使用九阴神功，无法施展#{@move_name}。\n"}
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

  # LPC: msg = "$N微微一笑…要穴！\n"; me->add("neili", -20);
  defp apply_effect(conn, character, target) do
    msg = "$N微微一笑，右手成爪，忽的抓向$n的要穴！\n"

    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 20}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn
    |> Broadcast.publish(Messages.interpolate(msg, [n1: character.name, n2: target.name]))
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
    attacker_max_neili = Map.get(data, :max_neili, 0)
    attacker_force = Map.get(data, :force, 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("parry") + target->query_skill("martial-cognize", 1);
    dp = Stats.skill(stats, "parry") + Stats.skill(stats, "martial-cognize")

    # LPC: if (ap / 2 + random(ap * 2) > dp)
    if div(ap, 2) + Engine.rand(rng, ap * 2) > dp do
      # LPC: me->start_busy(2); me->add("neili", -180);
      Performs.feedback(attacker, 180, 2)
      target_max_neili = character.meta.vitals.max_neili

      if attacker_max_neili > target_max_neili * 2 do
        # LPC: damage = -1; ... if (damage < 0) target->die(me);
        # 模型化为气血清零 + 死亡标记
        vitals = %{character.meta.vitals | qi: 0}
        combat = %{character.meta.combat | dead: true}
        character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

        conn
        |> Broadcast.publish(
          Messages.interpolate(
            "$N这一爪来势好快，正抓中$n的檀中大穴，$n一声惨叫，软绵绵的瘫了下去。\n",
            bindings
          )
        )
        |> put_character(character)
      else
        # LPC: target->start_busy(1 + random(3));
        combat = Combat.start_busy(character.meta.combat, 1 + Engine.rand(rng, 3))
        character = %{character | meta: %{character.meta | combat: combat}}

        # LPC: damage = ap + me->query_skill("force");
        #          damage = damage / 2 + random(damage);
        damage_base = ap + attacker_force
        damage = div(damage_base, 2) + Engine.rand(rng, damage_base)

        # LPC: if (arrayp(limbs = target->query("limbs")))
        #          limb = limbs[random(sizeof(limbs))];
        #      else limb = "要害";
        # 框架未建模角色个体 limbs，缺失时回退“要害”
        limb =
          case Map.get(character.meta, :limbs) do
            nil -> "要害"
            limbs -> Enum.at(limbs, max(Engine.rand(rng, length(limbs)) - 1, 0))
          end

        # LPC: do_damage(me, target, UNARMED_ATTACK, damage, 110, pmsg)
        vitals =
          character.meta.vitals
          |> Vitals.damage(:qi, damage)
          |> Vitals.wound(:qi, div(damage * 110, 100))

        character = %{character | meta: %{character.meta | vitals: vitals}}

        # LPC 的 pmsg 被 `+ limb +` 拆成两段字面量，E 侧须保持同样拆分
        msg =
          [
            "$n连忙腾挪躲闪，然而“扑哧”一声，$N五指正插入$n的",
            limb,
            "，$n一声惨叫，血溅五步。\n"
          ]
          |> Enum.join("")

        conn
        |> Broadcast.publish(Messages.interpolate(msg, bindings))
        |> put_character(character)
      end
    else
      # LPC: me->start_busy(2);
      Performs.feedback(attacker, 0, 2)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "可是$p看破了$P的来势，应对得法，避开了这一抓。\n",
          bindings
        )
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // zhua.c 九阴神抓
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define ZHUA "「" HIR "九阴神爪" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #     int damage;
  #     string msg;
  #     string pmsg;
  #     string *limbs;
  #     string limb;
  #     int ap, dp;
  # 
  #     if (userp(me) && !me->query("can_perform/jiuyin-shengong/zhua"))
  #         return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (!target)
  #         target = offensive_target(me);
  # 
  #     if (!target || !me->is_fighting(target))
  #         return notify_fail(ZHUA "只能对战斗中的对手使用。\n");
  # 
  #     if (me->query_temp("weapon"))
  #         return notify_fail(ZHUA "只能空手施展！\n");
  # 
  #     if ((int)me->query_skill("jiuyin-shengong", 1) < 280)
  #         return notify_fail("你的九阴神功还不够娴熟，不能使用" ZHUA "。\n");
  # 
  #     if ((int)me->query("neili", 1) < 300)
  #         return notify_fail("你现在内力太弱，不能使用" ZHUA "。\n");
  # 
  #     if (me->query_skill_prepared("claw") != "jiuyin-shengong" && me->query_skill_prepared("unarmed") != "jiuyin-shengong")
  #         return notify_fail("你没有准备使用九阴神功，无法施展" ZHUA "。\n");
  # 
  #     if (!living(target))
  #         return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIY "$N" HIY "微微一笑，右手成爪，忽的抓向$n" HIY "的要穴！\n" NOR;
  #     me->add("neili", -20);
  # 
  #     ap = me->query_skill("unarmed");
  #     if (ap < me->query_skill("claw"))
  #         ap = me->query_skill("claw");
  #     ap += me->query_skill("martial-cognize", 1);
  #     dp = target->query_skill("parry") +
  #          target->query_skill("martial-cognize", 1);
  # 
  #     me->want_kill(target);
  #     if (ap / 2 + random(ap * 2) > dp)
  #     {
  #         me->start_busy(2);
  #         me->add("neili", -180);
  #         damage = 0;
  # 
  #         if (me->query("max_neili") > target->query("max_neili") * 2)
  #         {
  #             msg += HIR "$N" HIR "这一爪来势好快，正抓中$n" HIR "的檀中大穴，$n" HIR
  #                        "一声惨叫，软绵绵的瘫了下去。\n" NOR;
  #             damage = -1;
  #         }
  #         else
  #         {
  #             target->start_busy(1 + random(3));
  # 
  #             damage = ap + (int)me->query_skill("force");
  #             //damage = damage / 2 + random(damage / 2);
  #             damage = damage / 2 + random(damage);
  # 
  #             if (arrayp(limbs = target->query("limbs")))
  #                 limb = limbs[random(sizeof(limbs))];
  #             else
  #                 limb = "要害";
  #             pmsg = HIR "$n连忙腾挪躲闪，然而“扑哧”一声，$N" HIR "五指正插入$n" HIR "的" + limb + "，$n" HIR "一声惨叫，血溅五步。\n" NOR;
  #             msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 110, pmsg);
  #         }
  #     }
  #     else
  #     {
  #         me->start_busy(2);
  #         msg += CYN "可是$p" CYN "看破了$P" CYN "的来势，应对得法，避开了这一抓。\n" NOR;
  #     }
  # 
  #     message_combatd(msg, me, target);
  #     if (damage < 0)
  #         target->die(me);
  # 
  #     return 1;
  # }
end
