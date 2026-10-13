defmodule Kantele.Combat.Skills.Performs.LingsheZhangfa.Wuji do
  @moduledoc """
  perform「横行无忌」（source lingshe-zhangfa/wuji.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 持杖类武器 → 内功>=200 →
  真气>=300 → 灵蛇杖法>=150 → 激发 staff 为灵蛇杖法 → 目标存活。
  前置广播后攻击方忙乱 3；命中判定 `ap/2 + random(ap)` > 目标 `parry`，
  命中扣 200 真气、伤害 `ap + random(ap)`（55% 外伤比例）、目标忙乱 1；
  未命中扣 80 真气、攻击方忙乱 4、目标忙乱 1。

  差异（TODO(migrate)）：
  - `COMBAT_D->do_damage(WEAPON_ATTACK, damage, 55, msg)` 折算为
    `Vitals.damage(:qi, damage) |> Vitals.wound(:qi, div(damage*55, 100))`；
  - LPC 命中/未命中两分支均有 `target->start_busy(1)`，E 侧目标忙乱恒为 1；
  - 攻击方 `me->start_busy(3)`（命中）/ `me->start_busy(4)`（未命中）与分支
    neili 由目标侧 feedback 回执（feedback(200,3) / feedback(80,4)）。
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
  alias Kantele.Combat.Performs

  @perform_id "lingshe-zhangfa/wuji"
  @move_name "「横行无忌」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "lingshe-zhangfa")
    ap = Stats.skill(stats, "staff")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_force(character),
         :ok <- check_resources(character),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_target_alive(target) do
      weapon_name =
        case Combat.weapon(combat) do
          nil -> ""
          weapon -> Map.get(weapon, :name)
        end

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

  # LPC: if (userp(me) && ! me->query("can_perform/lingshe-zhangfa/wuji"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你还不会使用#{@move_name}。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon) || weapon->query("skill_type") != "staff")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if is_map(weapon) and Map.get(weapon, :skill_type) == "staff" do
      :ok
    else
      {:error, "运用#{@move_name}必须手中持杖！\n"}
    end
  end

  # LPC: if ((int)me->query_skill("force") < 200)
  defp check_force(character) do
    if Stats.skill(character.meta.stats, "force") < 200 do
      {:error, "你的内功火候不够，难以运用使用#{@move_name}！\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 300)
  defp check_resources(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你现在的真气不够，无法使用#{@move_name}！\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("lingshe-zhangfa", 1) < 150)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "lingshe-zhangfa") < 150 do
      {:error, "你的灵蛇杖法还不到家，无法使用#{@move_name}！\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("staff") != "lingshe-zhangfa")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "staff") == "lingshe-zhangfa" do
      :ok
    else
      {:error, "你没有激发灵蛇杖法，无法使用#{@move_name}！\n"}
    end
  end

  # LPC: if (! living(target))
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIY "$N" HIY "一声冷笑，手中的" + weapon->name() +
    #      HIY "忽然变得如同活物一般，时上时下，忽左忽右，不知攻向$n" HIY "何处！\n" NOR;
    # weapon->name() 前后用 <> 拆段；其后的相邻字面量在 C 侧被空白分隔合并为一段。
    # me->start_busy 与分支 neili 由目标侧 feedback 回执。
    weapon_name =
      case Combat.weapon(character.meta.combat) do
        nil -> ""
        weapon -> Map.get(weapon, :name)
      end

    conn =
      Broadcast.publish(
        conn,
        "$N一声冷笑，手中的" <> weapon_name <>
          "忽然变得如同活物一般，时上时下，忽左忽右，不知攻向$n何处！\n",
        n1: character.name,
        n2: target.name
      )

    conn
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
    dp = Stats.skill(stats, "parry")

    # LPC: if (ap / 2 + random(ap) > dp)
    hit? = div(ap, 2) + Engine.rand(rng, ap) > dp

    # LPC: damage = ap + random(ap);
    #      COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 55, msg);
    #      me->add("neili", -200); me->start_busy(3); target->start_busy(1);
    # else: me->add("neili", -80); me->start_busy(4); target->start_busy(1);
    {vitals, combat, msg, neili_cost, attacker_busy} =
      if hit? do
        damage = ap + Engine.rand(rng, ap)

        v =
          character.meta.vitals
          |> Vitals.damage(:qi, damage)
          |> Vitals.wound(:qi, div(damage * 55, 100))

        c = Combat.start_busy(character.meta.combat, 1)
        {v, c, hit_message(), 200, 3}
      else
        {character.meta.vitals, Combat.start_busy(character.meta.combat, 1), miss_message(), 80, 4}
      end

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    Performs.feedback(attacker, neili_cost, attacker_busy)

    conn
    |> Broadcast.publish(msg, n1: attacker.name, n2: character.name)
    |> put_character(character)
  end

  # LPC: HIR "$n" HIR "实在无法捕捉到$P" HIR "的实招，接连挡空，连中数招，登时吐了一口鲜血！\n" NOR
  # （相邻字面量合并为单段）
  defp hit_message do
    "$n实在无法捕捉到$P的实招，接连挡空，连中数招，登时吐了一口鲜血！\n"
  end

  # LPC: CYN "$n" CYN "奋力招架，总算抵挡住了$P" CYN "的攻击！\n" NOR
  # （相邻字面量合并为单段）
  defp miss_message do
    "$n奋力招架，总算抵挡住了$P的攻击！\n"
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // wuji.c 横行无忌
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #           object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/lingshe-zhangfa/wuji"))
  #               return notify_fail("你还不会使用「横行无忌」。\n");
  # 
  #           if (! target || ! me->is_fighting(target))
  #                   return notify_fail("「横行无忌」只能对战斗中的对手使用。\n");
  # 
  #           if (! objectp(weapon = me->query_temp("weapon")) ||
  #               (string)weapon->query("skill_type") != "staff")
  #                   return notify_fail("运用「横行无忌」必须手中持杖！\n");
  # 
  #           if ((int)me->query_skill("force") < 200)
  #                   return notify_fail("你的内功火候不够，难以运用使用「横行无忌」！\n");
  # 
  #           if ((int)me->query("neili") < 300)
  #                   return notify_fail("你现在的真气不够，无法使用「横行无忌」！\n");
  # 
  #           if ((int)me->query_skill("lingshe-zhangfa", 1) < 150)
  #                   return notify_fail("你的灵蛇杖法还不到家，无法使用「横行无忌」！\n");
  # 
  #           if (me->query_skill_mapped("staff") != "lingshe-zhangfa")
  #                   return notify_fail("你没有激发灵蛇杖法，无法使用「横行无忌」！\n");
  # 
  #         if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "一声冷笑，手中的" + weapon->name() + HIY "忽然变得"
  #               "如同活物一般，时上时下，忽左忽右，不知攻向$n" HIY "何处！\n" NOR;
  #         ap = me->query_skill("staff");
  #         dp = target->query_skill("parry");
  #         if (ap / 2 + random(ap) > dp)
  #     {
  #         damage = ap + random(ap);
  #                 me->add("neili", -200);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 55,
  #                                    HIR "$n" HIR "实在无法捕捉到$P"
  #                                            HIR "的实招，接连挡空，连中数招，"
  #                                            "登时吐了一口鲜血！\n" NOR);
  #         me->start_busy(3);
  #                 target->start_busy(1);
  #     } else
  #     {
  #         msg += CYN "$n" CYN "奋力招架，总算抵挡住了$P"
  #                        CYN "的攻击！\n" NOR;
  #                 me->add("neili", -80);
  #         me->start_busy(4);
  #                 target->start_busy(1);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
