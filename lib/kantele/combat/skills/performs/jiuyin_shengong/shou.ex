defmodule Kantele.Combat.Skills.Performs.JiuyinShengong.Shou do
  @moduledoc """
  perform「九阴神手」（source jiuyin-shengong/perform/shou.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 空手 →
  九阴神功>=260 → 内力>=300 → 准备 hand 或 unarmed 为九阴神功 → 目标存活。
  ap = 九阴神功；dp = 目标实战经验/10000。起手扣 60 内力、忙乱 1+random(3)。
  - dp>=100（百万经验以上）：此招无效但仍受伤害。ap1 = 九阴神功+内功，
    dp1 = 招架+闪避；命中则 damage = ap1*2+random(ap1)、90% 外伤、再扣 140 内力，
    未命中仅文案；之后目标忙乱 1+random(2)。
  - 否则 random(ap)>dp：打中檀中大穴，扣 200 内力，target->die（气血清零+死亡标记）。
  - 否则：侥幸得脱，无伤害。
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

  @perform_id "jiuyin-shengong/shou"
  @move_name "「九阴神手」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jiuyin-shengong")
    ap = lvl
    ap1 = lvl + Stats.skill(stats, "force")

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
          ap1: ap1,
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
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (me->query_temp("weapon")) return notify_fail("此招只能空手施展！\n");
  defp check_weapon(combat) do
    if Combat.weapon(combat) != nil do
      {:error, "此招只能空手施展！\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill("jiuyin-shengong", 1) < 260)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "jiuyin-shengong") < 260 do
      {:error, "你的九阴神功还不够娴熟，不能使用#{@move_name}！\n"}
    else
      :ok
    end
  end

  defp check_resources(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你的真气不够！\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("hand") != "jiuyin-shengong"
  #          && me->query_skill_prepared("unarmed") != "jiuyin-shengong")
  # prepared_perform 返回绝招 ID（如 jiuyin-shengong/shou），须取技能前缀比对
  defp check_prepared(character) do
    stats = character.meta.stats
    prepared_hand = Stats.prepared_perform(stats, "hand")
    prepared_unarmed = Stats.prepared_perform(stats, "unarmed")
    ok_hand = prepared_hand != nil and hd(String.split(prepared_hand, "/")) == "jiuyin-shengong"
    ok_unarmed = prepared_unarmed != nil and hd(String.split(prepared_unarmed, "/")) == "jiuyin-shengong"

    if not ok_hand and not ok_unarmed do
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

  # LPC: me->add("neili", -60); me->start_busy(1 + random(3)); 起手文案
  defp apply_effect(conn, character, target) do
    rng = &:rand.uniform/1
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 60}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    combat = Combat.start_busy(character.meta.combat, 1 + Engine.rand(rng, 3))
    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> Broadcast.publish(
      Messages.interpolate(
        "$N“哈”的一声吐出了一口气，手势奇特，软绵绵的奔向$n的要穴！\n",
        [n1: character.name, n2: target.name]
      )
    )
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
    ap1 = max(Map.get(data, :ap1, 0), 1)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query("combat_exp") / 10000;
    dp = div(stats.combat_exp, 10000)

    cond do
      dp >= 100 ->
        # LPC: 此招对百万经验以上的人无效，但是仍然受到伤害
        # ap1 = jiuyin-shengong + force；dp1 = parry + dodge
        dp1 = Stats.skill(stats, "parry") + Stats.skill(stats, "dodge")
        damage = ap1 * 2 + Engine.rand(rng, ap1)
        hit = div(ap1, 2) + Engine.rand(rng, ap1) > dp1

        character =
          if hit do
            # LPC: me->add("neili", -140); do_damage(..., damage, 90, ...)
            Performs.feedback(attacker, 140, 0)
            apply_damage(character, damage, 90)
          else
            character
          end

        # LPC: target->start_busy(1 + random(2));
        combat = Combat.start_busy(character.meta.combat, 1 + Engine.rand(rng, 2))
        character = %{character | meta: %{character.meta | combat: combat}}

        msg =
          if hit do
            "$n只觉此招，阴柔无比，诡异莫测，心中一惊，却猛然间觉得一股阴风透骨而过。\n"
          else
            "$n知道来招不善，小心应对，没出一点差错。\n"
          end

        conn
        |> Broadcast.publish(Messages.interpolate(msg, bindings))
        |> put_character(character)

      Engine.rand(rng, ap) > dp ->
        # LPC: random(ap) > dp → 打中檀中大穴，target->die(me)
        Performs.feedback(attacker, 200, 0)
        vitals = %{character.meta.vitals | qi: 0}
        combat = %{character.meta.combat | dead: true}
        character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

        conn
        |> Broadcast.publish(
          Messages.interpolate(
            "这一招完全超出了$n的想象，被$N结结实实的打中了檀中大穴，浑身真气登时涣散！\n",
            bindings
          )
        )
        |> put_character(character)

      true ->
        conn
        |> Broadcast.publish(
          Messages.interpolate(
            "$n大吃一惊，连忙胡乱抵挡，居然没有一点伤害，侥幸得脱！\n",
            bindings
          )
        )
        |> put_character(character)
    end
  end

  # LPC: COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, percent, msg)
  # wound = damage * percent / 100（armor 未建模，按 percent 直算）
  defp apply_damage(character, damage, percent) do
    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage * percent, 100))

    %{character | meta: %{character.meta | vitals: vitals}}
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // shou.c 九阴神手
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define SHOU "「" HIG "九阴神手" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #     string msg;
  #     int ap, dp, ap1, dp1, damage;
  # 
  #     if (userp(me) && !me->query("can_perform/jiuyin-shengong/shou"))
  #         return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (!target)
  #         target = offensive_target(me);
  # 
  #     if (!target || !me->is_fighting(target))
  #         return notify_fail(SHOU "只能在战斗中对对手使用。\n");
  # 
  #     if (me->query_temp("weapon"))
  #         return notify_fail("此招只能空手施展！\n");
  # 
  #     if (me->query_skill("jiuyin-shengong", 1) < 260)
  #         return notify_fail("你的九阴神功还不够娴熟，不能使用" SHOU "！\n");
  # 
  #     if (me->query("neili") < 300)
  #         return notify_fail("你的真气不够！\n");
  # 
  #     if (me->query_skill_prepared("hand") != "jiuyin-shengong" && me->query_skill_prepared("unarmed") != "jiuyin-shengong")
  #         return notify_fail("你没有准备使用九阴神功，无法施展" SHOU "。\n");
  # 
  #     if (!living(target))
  #         return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIY "$N" HIY "“哈”的一声吐出了一口气，手势奇特，软绵绵的奔向$n" HIY "的要穴！\n";
  # 
  #     ap = me->query_skill("jiuyin-shengong");
  #     dp = target->query("combat_exp") / 10000;
  #     me->add("neili", -60);
  #     me->start_busy(1 + random(3));
  # 
  #     me->want_kill(target);
  # 
  #     if (dp >= 100) // 此招对百万经验以上的人无效
  #     {              // 但是仍然受到伤害
  # 
  #         ap1 = me->query_skill("jiuyin-shengong", 1) + me->query_skill("force", 1);
  #         dp1 = target->query_skill("parry", 1) + target->query_skill("dodge", 1);
  #         //damage = ap1 + random(ap1);
  #         damage = ap1 * 2 + random(ap1);
  #         if (ap1 / 2 + random(ap1) > dp1)
  #         {
  #             msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 90,
  #                                        HIR "$n" HIR "只觉此招，阴柔无比，诡异莫测，"
  #                                            "心中一惊，却猛然间觉得一股阴风透骨而过。\n" NOR);
  #             me->add("neili", -140);
  #         }
  # 
  #         else
  #             msg += HIC "$n" HIC "知道来招不善，小心应对，没出一点差错。\n" NOR;
  #         message_combatd(msg, me, target);
  #         target->start_busy(1 + random(2));
  #         return 1;
  #     }
  #     else if (random(ap) > dp)
  #     {
  #         msg += HIR "这一招完全超出了$n" HIR "的想象，被$N" HIR "结结实实的打中了檀中大穴，浑身真气登时涣散！\n" NOR;
  #         message_combatd(msg, me, target);
  #         me->add("neili", -200);
  #         target->die(me);
  #         return 1;
  #     }
  #     else
  #     {
  #         msg += HIM "$n" HIM "大吃一惊，连忙胡乱抵挡，居"
  #                    "然没有一点伤害，侥幸得脱！\n" NOR;
  #     }
  # 
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
