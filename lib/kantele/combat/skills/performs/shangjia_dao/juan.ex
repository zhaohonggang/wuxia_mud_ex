defmodule Kantele.Combat.Skills.Performs.ShangjiaDao.Juan do
  @moduledoc """
  寒芒暴卷「juan」（对照 `kungfu/skill/shangjia-dao/juan.c`）

  商家刀法单体攻击：需持刀、内功>=80、商家刀法>=50、激发 blade 为商家刀法、
  真气>=100、目标存活。命中判定
  `ap/2 + random(ap) > 目标parry`（ap = blade）：命中造成
  `ap/3 + random(ap/2)`（外伤 35%）并扣 80 真气、忙乱 2；
  未命中扣 30 真气、忙乱 3。

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

  @perform_id "shangjia-dao/juan"
  @move_name "「寒芒暴卷」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
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

  # LPC: if (userp(me) && ! me->query("can_perform/shangjia-dao/juan"))
  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) { me->clean_up_enemy(); target = me->select_opponent(); }
  #      if (! target || ! me->is_fighting(target))
  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #           (string)weapon->query("skill_type") != "blade")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "blade" do
      {:ok, weapon}
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("force") < 80)
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 80 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("shangjia-dao", 1) < 50)
  defp check_level(stats) do
    if Stats.skill(stats, "shangjia-dao") < 50 do
      {:error, "你的商家刀法还不到家，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("blade") != "shangjia-dao")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "blade") == "shangjia-dao" do
      :ok
    else
      {:error, "你没有激发商家刀法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query("neili") < 100)
  defp check_neili(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, weapon, stats) do
    weapon_name = Map.get(weapon, :name, "")

    # LPC: msg = HIW "$N" HIW "手中" + weapon->name() +  HIW "吞吐不定，刀势连环起"
    #           "伏，顿时叠起重重刀芒裹向$n" HIW "全身！\n" NOR;
    #      ap = me->query_skill("blade"); dp = target->query_skill("parry");
    conn =
      Broadcast.publish(
        conn,
        "$N手中" <> weapon_name <> "吞吐不定，刀势连环起伏，顿时叠起重重刀芒裹向$n全身！\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: Stats.skill(stats, "blade"),
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

    # LPC: ap = me->query_skill("blade"); dp = target->query_skill("parry");
    ap = max(Map.get(data, :ap, 0), 1)
    dp = Stats.skill(stats, "parry")

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = ap / 3 + random(ap / 2); do_damage(..., damage, 35, ...);
      #      me->add("neili", -80); me->start_busy(2);
      damage = div(ap, 3) + Engine.rand(rng, max(div(ap, 2), 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 35, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: HIR "$n" HIR "只觉得无数刀光携着寒芒向" "自己涌来，一时躲闪不及，连中数刀！\n" NOR;
      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate(
            "$n只觉得无数刀光携着寒芒向自己涌来，一时躲闪不及，连中数刀！\n",
            bindings
          )
        )

      Performs.feedback(attacker, 80, 2)
      put_character(conn, character)
    else
      # LPC: msg += CYN "可$p" CYN "身子一偏，向后横移数尺，躲开了$P"
      #           CYN "的攻势。\n" NOR;
      #      me->add("neili", -30); me->start_busy(3);
      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate(
            "可$p身子一偏，向后横移数尺，躲开了$P的攻势。\n",
            bindings
          )
        )

      Performs.feedback(attacker, 30, 3)
      conn
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "shangjia-dao/juan",
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
  # #define JUAN "「" HIW "寒芒暴卷" NOR "」"
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
  #         if (userp(me) && ! me->query("can_perform/shangjia-dao/juan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(JUAN "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "blade")
  #                 return notify_fail("你使用的武器不对，难以施展" JUAN "。\n");
  # 
  #         if ((int)me->query_skill("force") < 80)
  #                 return notify_fail("你的内功火候不够，难以施展" JUAN "。\n");
  # 
  #         if ((int)me->query_skill("shangjia-dao", 1) < 50)
  #                 return notify_fail("你的商家刀法还不到家，难以施展" JUAN "。\n");
  # 
  #         if (me->query_skill_mapped("blade") != "shangjia-dao")
  #                 return notify_fail("你没有激发商家刀法，难以施展" JUAN "。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你的真气不够，难以施展" JUAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIW "$N" HIW "手中" + weapon->name() +  HIW "吞吐不定，刀势连环起"
  #               "伏，顿时叠起重重刀芒裹向$n" HIW "全身！\n" NOR;
  # 
  #         ap = me->query_skill("blade");
  #         dp = target->query_skill("parry");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #     {
  #         damage = ap / 3 + random(ap / 2);
  #                 me->add("neili", -80);
  #         msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 35,
  #                                            HIR "$n" HIR "只觉得无数刀光携着寒芒向"
  #                                            "自己涌来，一时躲闪不及，连中数刀！\n" NOR);
  #         me->start_busy(2);
  #     } else
  #     {
  #         msg += CYN "可$p" CYN "身子一偏，向后横移数尺，躲开了$P"
  #                        CYN "的攻势。\n" NOR;
  #                 me->add("neili", -30);
  #         me->start_busy(3);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
