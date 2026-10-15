defmodule Kantele.Combat.Skills.Performs.MingwangJian.Xiang do
  @moduledoc """
  降魔「xiang」（对照 `kungfu/skill/mingwang-jian/xiang.c`）

  明王剑法绝技：需持剑、不动明王剑>=140、激发 sword 为不动明王剑、真气>=200、
  目标存活。命中判定 `ap/2 + random(ap) > 目标parry`（ap = 自身 sword）：
  命中造成 `ap/2 + random(ap/2)`（外伤 45%）并扣 150 真气、忙乱 2；
  未命中扣 50 真气、忙乱 3。

  差异（TODO(migrate)）：
  - LPC 首句并入 `message_combatd`，本引擎引子在攻击方广播、命中/落空在目标侧结算；
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - 攻击方真气/忙乱经 `Performs.feedback/3` 由目标侧回传。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "mingwang-jian/xiang"
  @move_name "「降魔」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat
    rng = &:rand.uniform/1
    level = Stats.skill(stats, "mingwang-jian")
    sword = Stats.skill(stats, "sword")

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_skill_level(level),
         :ok <- check_mapped(stats),
         :ok <- check_neili(character) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: level,
          sword: sword,
          rng: rng
        }
      })

      apply_perform(conn, character, target, weapon)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/mingwang-jian/xiang"))
  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #          (string)weapon->query("skill_type") != "sword")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      {:ok, weapon}
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("mingwang-jian", 1) < 140)
  defp check_skill_level(level) do
    if level < 140 do
      {:error, "你不动明王剑不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "mingwang-jian")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "mingwang-jian" do
      :ok
    else
      {:error, "你没有激发不动明王剑，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query("neili") < 200)
  defp check_neili(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, weapon) do
    weapon_name = Map.get(weapon, :name, "")

    # LPC: msg = HIY "$N" HIY "纵身跃入半空，将全身劲气贯于" + weapon->name() +
    #           HIY "中，剑尖顿时吐出一股剑气直指$n" HIY "而去。\n" NOR;
    conn
    |> Broadcast.publish(
      "$N纵身跃入半空，将全身劲气贯于" <>
        weapon_name <> "中，剑尖顿时吐出一股剑气直指$n而去。\n",
      n1: character.name,
      n2: target.name
    )
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？\n",
        n1: attacker.name,
        n2: character.name
      )
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :sword, 0), 1)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: ap = me->query_skill("sword"); dp = target->query_skill("parry");
    dp = Stats.skill(stats, "parry")

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = ap / 2 + random(ap / 2);
      #      me->add("neili", -150); me->start_busy(2);
      #      msg += do_damage(me, target, WEAPON_ATTACK, damage, 45, HIR "..." );
      damage = div(ap, 2) + Engine.rand(rng, max(div(ap, 2), 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 45, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate(
            "$n只见一道黄芒闪过，微作差异，登时只觉全身一麻，剑气已透胸而过！\n",
            bindings
          )
        )

      Performs.feedback(attacker, 150, 2)
      put_character(conn, character)
    else
      # LPC: me->add("neili", -50); me->start_busy(3);
      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate("可是$n一声冷笑，飞身一跃而起，避开$N发出的剑气。\n", bindings)
        )

      Performs.feedback(attacker, 50, 3)
      conn
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define XIANG "「" HIY "降魔" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/mingwang-jian/xiang"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(XIANG "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" XIANG "。\n");
  # 
  #         if ((int)me->query_skill("mingwang-jian", 1) < 140)
  #                 return notify_fail("你不动明王剑不够娴熟，难以施展" XIANG "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "mingwang-jian")
  #                 return notify_fail("你没有激发不动明王剑，难以施展" XIANG "。\n");
  # 
  #         if (me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不足，难以施展" XIANG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "纵身跃入半空，将全身劲气贯于" + weapon->name() +
  #               HIY "中，剑尖顿时吐出一股剑气直指$n" HIY "而去。\n" NOR;
  # 
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("parry");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap / 2 + random(ap / 2);
  #                 me->add("neili", -150);
  #                 me->start_busy(2);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 45,
  #                                            HIR "$n" HIR "只见一道黄芒闪过，微作差"
  #                                            "异，登时只觉全身一麻，剑气已透胸而过！"
  #                                            "\n" NOR);
  #         } else
  #         {
  #                 me->add("neili", -50);
  #                 me->start_busy(3);
  #                 msg += CYN "可是$n" CYN "一声冷笑，飞身一跃而起，避开"
  #                        CYN "$N" CYN "发出的剑气。\n"NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
