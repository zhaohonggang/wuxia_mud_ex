defmodule Kantele.Combat.Skills.Performs.QingliangJian.Ming do
  @moduledoc """
  禅心自明「ming」（对照 `kungfu/skill/qingliang-jian/ming.c`）

  清凉剑法单体攻击：需持剑、内功>=100、清凉剑法>=80、激发 sword 为清凉剑法、
  真气>=80、目标存活。命中判定
  `ap*2/3 + random(ap) > 目标parry`（ap = sword）：命中造成
  `ap/3 + random(ap/2)`（外伤 20%）并扣 40 真气、忙乱 2；
  未命中扣 20 真气、忙乱 3。

  差异（TODO(migrate)）：
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - 引子在攻击方广播，命中/落空在目标侧结算。
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

  @perform_id "qingliang-jian/ming"
  @move_name "「禅心自明」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_force(stats),
         :ok <- check_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_neili(character) do
      apply_perform(conn, character, target, weapon, stats)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #           (string)weapon->query("skill_type") != "sword")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      {:ok, weapon}
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill("force") < 100)
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 100 do
      {:error, "你的内功的修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill("qingliang-jian", 1) < 80)
  defp check_level(stats) do
    if Stats.skill(stats, "qingliang-jian") < 80 do
      {:error, "你的清凉剑法修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "qingliang-jian")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "qingliang-jian" do
      :ok
    else
      {:error, "你没有激发清凉剑法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query("neili") < 80)
  defp check_neili(character) do
    if character.meta.vitals.neili < 80 do
      {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, weapon, stats) do
    weapon_name = Map.get(weapon, :name, "")

    # LPC: msg = HIW "$N" HIW "一抖手中" + weapon->name() + HIW "闪出无数个剑花，同时向$n"
    #           HIW "刺去。\n" NOR;
    #      ap = me->query_skill("sword");
    conn =
      Broadcast.publish(
        conn,
        "$N一抖手中" <> weapon_name <> "闪出无数个剑花，同时向$n刺去。\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: Stats.skill(stats, "sword"),
        rng: &:rand.uniform/1
      }
    })

    conn
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
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: ap = me->query_skill("sword"); dp = target->query_skill("parry");
    ap = max(Map.get(data, :ap, 0), 1)
    dp = Stats.skill(stats, "parry")

    if div(ap * 2, 3) + Engine.rand(rng, ap) > dp do
      # LPC: damage = ap / 3 + random(ap / 2); do_damage(..., damage, 20, ...);
      #      me->add("neili", -40); me->start_busy(2);
      damage = div(ap, 3) + Engine.rand(rng, max(div(ap, 2), 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 20, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate(
            "$n看的头昏眼花，不知虚实，登时$n身上几处受伤！\n",
            bindings
          )
        )

      Performs.feedback(attacker, 40, 2)
      put_character(conn, character)
    else
      # LPC: me->add("neili", -20); me->start_busy(3);
      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate(
            "可是$p看破其中虚实，轻轻架开了$P的剑招。\n",
            bindings
          )
        )

      Performs.feedback(attacker, 20, 3)
      conn
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "qingliang-jian/ming",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>  
  # #include <combat.h>  
  #  
  # #define SHENG "「" HIW "禅心自明" NOR "」"  
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
  #         if (! target) target = offensive_target(me);  
  #  
  #         if (! target || ! me->is_fighting(target))  
  #                 return notify_fail(SHENG "只能在战斗中对对手使用。\n");  
  #  
  #  
  #         if (! objectp(weapon = me->query_temp("weapon")) ||  
  #             (string)weapon->query("skill_type") != "sword")  
  #                 return notify_fail("你使用的武器不对，难以施展" SHENG "。\n");  
  #  
  #         if (me->query_skill("force") < 100)  
  #                 return notify_fail("你的内功的修为不够，难以施展" SHENG "。\n");  
  #  
  #         if (me->query_skill("qingliang-jian", 1) < 80)  
  #                 return notify_fail("你的清凉剑法修为不够，难以施展" SHENG "。\n");  
  #  
  #         if (me->query_skill_mapped("sword") != "qingliang-jian")  
  #                 return notify_fail("你没有激发清凉剑法，难以施展" SHENG "。\n");  
  #  
  #         if (me->query("neili") < 80)  
  #                 return notify_fail("你现在真气不够，难以施展" SHENG "。\n");  
  #  
  #         if (! living(target))  
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");  
  #  
  #         msg = HIW "$N" HIW "一抖手中" + weapon->name() + HIW "闪出无数个剑花，同时向$n"      HIW "刺去。\n" NOR;  
  #         ap = me->query_skill("sword");  
  #         dp = target->query_skill("parry");  
  #  
  #         if (ap * 2 / 3 + random(ap) > dp)  
  #         { 
  #                 damage = ap / 3 + random(ap / 2);  
  #                 me->add("neili", -40);  
  #                 me->start_busy(2);  
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 20,  
  #                                            HIR "$n" HIR "看的头昏眼花，不知虚实，登时$n"  
  #                                            HIR "身上几处受伤！\n" NOR);  
  #         } else  
  #         { 
  #                 me->add("neili", -20);  
  #                 me->start_busy(3);  
  #                 msg += CYN "可是$p" CYN "看破其中虚实，轻轻架开了$P"  
  #                        CYN "的剑招。\n"NOR;  
  #         } 
  #  
  #         message_combatd(msg, me, target);  
  #          
  #         return 1;  
  # } 
end
