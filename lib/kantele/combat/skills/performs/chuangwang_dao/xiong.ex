defmodule Kantele.Combat.Skills.Performs.ChuangwangDao.Xiong do
  @moduledoc """
  雄霸群山「xiong」（对照 `kungfu/skill/chuangwang-dao/xiong.c`，inherit F_SSERVER）

  闯王刀法单体攻击：要求内力 >= 50、内功 force >= 60、chuangwang-dao >= 40、
  武器为刀(blade) 且已激发映射；按 blade+martial-cognize 与 parry+martial-cognize
  判定命中，命中扣攻击方内力 30（落空 10）并令其忙乱。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "chuangwang-dao/xiong"
  @move_name "「雄霸群山」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_force(stats),
         :ok <- check_skill_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      apply_perform(conn, character, target, stats)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
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

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "blade" do
      :ok
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 60 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "chuangwang-dao") < 40 do
      {:error, "你的闯王刀法还不到家，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "blade") == "chuangwang-dao" do
      :ok
    else
      {:error, "你没有激发闯王刀法，难以施展#{@move_name}。\n"}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 50 do
      {:error, "你的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_perform(conn, character, target, stats) do
    combat = character.meta.combat
    weapon = Combat.weapon(combat)
    weapon_name = weapon && Map.get(weapon, :name)

    # LPC: msg = HIY "$N" HIY "一声怒喝，手中" + weapon->name() +
    #            HIY "凌空劈斩" "而出，刀锋顿时如闪电般贯向$n" HIY "！\n" NOR;
    part1 = "$N一声怒喝，手中"
    part2 = "凌空劈斩而出，刀锋顿时如闪电般贯向$n！\n"
    start_msg = part1 <> (weapon_name || "") <> part2
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    ap = Stats.skill(stats, "blade") + Stats.skill(stats, "martial-cognize")
    dp = Stats.skill(target.meta.stats, "parry") + Stats.skill(target.meta.stats, "martial-cognize")

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: ap,
        dp: dp,
        rng: &:rand.uniform/1
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
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
    ap = Map.get(data, :ap, 0)
    dp = Map.get(data, :dp, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)

    # LPC: if (ap / 2 + random(ap) > dp)
    hit = div(ap, 2) + Engine.rand(rng, ap) > dp

    if hit do
      # LPC: damage = ap / 3 + random(ap / 2);  me->add("neili", -30);  me->start_busy(2);
      #      COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 25, msg);
      damage = div(ap, 3) + Engine.rand(rng, div(ap, 2))
      vitals = Vitals.damage(character.meta.vitals, :qi, damage)
      vitals = Vitals.wound(vitals, :qi, div(damage, 4))
      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: "$n" "稍作迟疑，不想被$N" "一刀劈中，顿时一声惨呼，血溅五步！\n"
      hit_msg = "稍作迟疑，不想被$N一刀劈中，顿时一声惨呼，血溅五步！\n"
      hit_msg = "$n" <> hit_msg
      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 30, 2)
    else
      # LPC: "可是$p" "微微一笑，身子朝一旁偏过尺许，躲开$P" "这一刀。\n"
      #      me->add("neili", -10);  me->start_busy(3);
      miss_msg = "可是$p微微一笑，身子朝一旁偏过尺许，躲开$P这一刀。\n"
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 10, 3)
    end

    conn
    |> put_character(character)
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  # ===== 原始 LPC 源码（逐行保留，供核对；移植稳定后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  #
  # #define XIONG "「" HIY "雄霸群山" NOR "」"
  #
  # inherit F_SSERVER;
  #
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     int damage;
  #     string msg;
  #         int ap, dp;
  #
  #         if (userp(me) && ! me->query("can_perform/chuangwang-dao/xiong"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  #
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  #
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(XIONG "只能对战斗中的对手使用。\n");
  #
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "blade")
  #                 return notify_fail("你使用的武器不对，难以施展" XIONG "。\n");
  #
  #         if ((int)me->query_skill("force", 1) < 60)
  #                 return notify_fail("你的内功火候不够，难以施展" XIONG "。\n");
  #
  #         if ((int)me->query_skill("chuangwang-dao", 1) < 40)
  #                 return notify_fail("你的闯王刀法还不到家，难以施展" XIONG "。\n");
  #
  #         if (me->query_skill_mapped("blade") != "chuangwang-dao")
  #                 return notify_fail("你没有激发闯王刀法，难以施展" XIONG "。\n");
  #
  #         if ((int)me->query("neili") < 50)
  #                 return notify_fail("你的真气不够，难以施展" XIONG "。\n");
  #
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  #
  #     msg = HIY "$N" HIY "一声怒喝，手中" + weapon->name() +
  #           HIY "凌空劈斩" "而出，刀锋顿时如闪电般贯向$n" HIY "！\n" NOR;
  #
  #         ap = me->query_skill("blade") + me->query_skill("martial-cognize", 1);
  #         dp = target->query_skill("parry") + target->query_skill("martial-cognize", 1);
  #
  #         if (ap / 2 + random(ap) > dp)
  #     {
  #         damage = ap / 3 + random(ap / 2);
  #                 me->add("neili", -30);
  #         msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 25,
  #                                            HIR "$n" HIR "稍作迟疑，不想被$N"
  #                                            HIR "一刀劈中，顿时一声惨呼，血溅五步！\n" NOR);
  #         me->start_busy(2);
  #     } else
  #     {
  #         msg += CYN "可是$p" CYN "微微一笑，身子朝一旁偏过尺许，躲开$P"
  #                        CYN "这一刀。\n" NOR;
  #                 me->add("neili", -10);
  #         me->start_busy(3);
  #     }
  #     message_combatd(msg, me, target);
  #
  #     return 1;
  # }
end
