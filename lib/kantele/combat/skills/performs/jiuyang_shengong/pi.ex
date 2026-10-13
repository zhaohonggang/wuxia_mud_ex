defmodule Kantele.Combat.Skills.Performs.JiuyangShengong.Pi do
  @moduledoc """
  perform「骄阳劈天」（source jiuyang-shengong/perform/pi.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招(can_perform + can_learn/enable_weapon) →
  目标战斗中 → 须持 blade → 九阳神功>=220 → force>=240 → blade>=240 →
  max_neili>=5500 → 真气>=400 → 激发 blade 为九阳神功 → 目标存活。
  ap = blade + force；命中 ap*11/20 + random(ap) > 目标(parry + force)，
  伤害 ap + random(ap/3)，85~89% 外伤。起手扣 150 真气/忙乱 2+random(2)，
  命中再扣 200 真气。
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
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Performs

  @perform_id "jiuyang-shengong/pi"
  @move_name "「骄阳劈天」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jiuyang-shengong")
    ap = Stats.skill(stats, "blade") + Stats.skill(stats, "force")
    weapon_name = Map.get(Combat.weapon(combat) || %{}, :name, "")

    with :ok <- check_perform_known(character),
         :ok <- check_learn(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_force(character),
         :ok <- check_blade(character),
         :ok <- check_max_neili(character),
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
          weapon_name: weapon_name,
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

  # LPC: if (userp(me) && ! me->query("can_learn/jiuyang-shengong/enable_weapon"))
  #          return notify_fail("你所使用的外功中没有这种功能。\n");
  defp check_learn(character) do
    if Stats.perform_known?(character.meta.stats, "jiuyang-shengong/enable_weapon") do
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

    if weapon != nil and Map.get(weapon, :skill_type) == "blade" do
      :ok
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill("jiuyang-shengong", 1) < 220)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "jiuyang-shengong") < 220 do
      {:error, "你的九阳神功不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill("force", 1) < 240)
  defp check_force(character) do
    if Stats.skill(character.meta.stats, "force") < 240 do
      {:error, "你的内功根基不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill("blade", 1) < 240)
  defp check_blade(character) do
    if Stats.skill(character.meta.stats, "blade") < 240 do
      {:error, "你的基本刀法火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 5500 do
      {:error, "你的内力修为不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_resources(character) do
    if character.meta.vitals.neili < 400 do
      {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "blade") == "jiuyang-shengong" do
      :ok
    else
      {:error, "你没有激发九阳神功为刀法，难以施展#{@move_name}。\n"}
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

  # LPC: msg = "\n$N猛然间飞身而起…内力源源不绝地涌入" + weapon->name() +
  #           "，刹那间刀芒夺目，自天而下，劈向$n！\n"; me->add("neili", -150);
  defp apply_effect(conn, character, target) do
    weapon_name = Map.get(Combat.weapon(character.meta.combat) || %{}, :name, "")

    msg =
      ["$N猛然间飞身而起，半空中一声长啸，内力源源不绝地涌入",
       weapon_name,
       "，刹那间刀芒夺目，自天而下，劈向$n！\n"]
      |> Enum.join("")

    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 150}
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
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("parry") + target->query_skill("force", 1);
    dp = Stats.skill(stats, "parry") + Stats.skill(stats, "force")

    if div(ap * 11, 20) + Engine.rand(rng, ap) > dp do
      # LPC: 命中：damage = ap + random(ap/3)，85~89% 外伤
      damage = ap + Engine.rand(rng, div(ap, 3))
      percent = 85 + Engine.rand(rng, 5)

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * percent, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      Performs.feedback(attacker, 200, 2 + Engine.rand(rng, 2))

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "$n只觉刀芒夺目，正犹豫间到刀芒已穿透$n身体，顿时鲜血狂涌，内息散乱。\n",
          bindings
        )
      )
      |> put_character(character)
    else
      Performs.feedback(attacker, 0, 2 + Engine.rand(rng, 2))

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "可是$n看透$P此招之中的破绽，镇定逾恒，全神应对自如。\n",
          bindings
        )
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define PO "「" HIW "骄阳劈天" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # string final(object me, object target, int damage);
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/jiuyang-shengong/pi"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (userp(me) && ! me->query("can_learn/jiuyang-shengong/enable_weapon"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");    
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(PO "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "blade")
  #                 return notify_fail("你使用的武器不对，难以施展" PO "。\n");
  # 
  #         if ((int)me->query_skill("jiuyang-shengong", 1) < 220)
  #                 return notify_fail("你的九阳神功不够娴熟，难以施展" PO "。\n");
  # 
  #         if ((int)me->query_skill("force", 1) < 240)
  #                 return notify_fail("你的内功根基不够，难以施展" PO "。\n");
  # 
  #         if ((int)me->query_skill("blade", 1) < 240)
  #                 return notify_fail("你的基本刀法火候不够，难以施展" PO "。\n");
  # 
  #         if ((int)me->query("max_neili") < 5500)
  #                 return notify_fail("你的内力修为不足，难以施展" PO "。\n");
  # 
  #         if (me->query("neili") < 400)
  #                 return notify_fail("你现在真气不够，难以施展" PO "。\n");
  # 
  #         if (me->query_skill_mapped("blade") != "jiuyang-shengong") 
  #                 return notify_fail("你没有激发九阳神功为刀法，难以施展" PO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "\n$N" HIW "猛然间飞身而起，半空中一声长啸，内力源源不绝地涌"
  #               "入" + weapon->name() + HIW "，刹那间刀芒夺目，自天而下，劈向$n" HIW "！\n" NOR;
  # 
  #         me->add("neili", -150);
  #         ap = me->query_skill("blade") + me->query_skill("force", 1);
  #         dp = target->query_skill("parry") + target->query_skill("force", 1);
  # 
  #         me->start_busy(2 + random(2));
  #         if (ap * 11 / 20 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 3);
  #                 me->add("neili", -200);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 85 + random(5),
  #                                            (: final, me, target, damage :));
  #         } else
  #         {
  #                 msg += HIC "可是$n" HIC "看透$P" HIC "此招之中的破绽，镇"
  #                        "定逾恒，全神应对自如。\n" NOR;
  #         }
  #         message_sort(msg, me, target);
  # 
  #         return 1;
  # }
  # 
  # string final(object me, object target, int damage)
  # {
  #         target->add("neili", -(damage / 4));
  #         target->add("neili", -(damage / 8));
  #         return  HIR "$n" HIR "只觉刀芒夺目，正犹豫间到刀芒已穿透$n" HIR "身体，顿时"
  #                 "鲜血狂涌，内息散乱。\n" NOR;
  # }
end
