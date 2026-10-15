defmodule Kantele.Combat.Skills.Performs.YunheJian.Chong do
  @moduledoc """
  鹤冲九霄「chong」（对照 `kungfu/skill/yunhe-jian/chong.c`）

  云鹤七剑绝技：需持剑、内功>=150、云鹤七剑>=100、真气>=100、激发 sword 为
  云鹤七剑、目标存活。命中判定 `ap/2 + random(ap) > 目标parry`（ap = sword）：
  命中造成 `50 + ap/2 + random(ap/2)`（外伤 25%）并扣 80 真气、忙乱 2；
  未命中扣 60 真气、忙乱 3。

  差异（TODO(migrate)）：
  - 引子在攻击方广播，命中/落空在目标侧结算；
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的
    `dead` 分支兜底；
  - 攻守双方 sword/parry 通过事件数据传递。
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

  @perform_id "yunhe-jian/chong"
  @move_name "「鹤冲九霄」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_force(stats),
         :ok <- check_skill_level(stats),
         :ok <- check_neili(character),
         :ok <- check_mapped(stats) do
      apply_perform(conn, character, target, weapon, stats)
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

  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      {:ok, weapon}
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill("force") < 150)
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 150 do
      {:error, "你的内功的修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill("yunhe-jian", 1) < 100)
  defp check_skill_level(stats) do
    if Stats.skill(stats, "yunhe-jian") < 100 do
      {:error, "你的云鹤七剑修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili") < 100)
  defp check_neili(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "yunhe-jian")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "yunhe-jian" do
      :ok
    else
      {:error, "你没有激发云鹤七剑，难以施展#{@move_name}。\n"}
    end
  end

  defp apply_perform(conn, character, target, weapon, stats) do
    weapon_name = Map.get(weapon, :name, "")

    # LPC: msg = HIM "$N" HIM "陡然一声长啸，手中" + weapon->name()
    #           + HIM "疾射而出，勾勒出一道绚丽的剑芒，直划$n" HIM "前胸！\n" NOR;
    conn =
      Broadcast.publish(
        conn,
        "$N陡然一声长啸，手中" <> weapon_name <> "疾射而出，勾勒出一道绚丽的剑芒，直划$n前胸！\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        sword: Stats.skill(stats, "sword"),
        rng: &:rand.uniform/1
      }
    })

    conn
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      # LPC: if (! living(target))
      #          return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
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
    ap = max(Map.get(data, :sword, 0), 1)
    dp = Stats.skill(stats, "parry")

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = 50 + ap / 2 + random(ap / 2); me->add("neili", -80);
      #      me->start_busy(2);
      #      msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 25,
      #          HIR "$n" HIR "奋力格挡，终究不敌，被$N"
      #          HIR "一剑刺中胸口，鲜血飞溅而出！\n" NOR);
      damage = 50 + div(ap, 2) + Engine.rand(rng, max(div(ap, 2), 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 25, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate("$n奋力格挡，终究不敌，被$N一剑刺中胸口，鲜血飞溅而出！\n", bindings)
        )

      Performs.feedback(attacker, 80, 2)
      put_character(conn, character)
    else
      # LPC: me->add("neili", -60); me->start_busy(3);
      #      msg += CYN "可是$p" CYN "并不慌乱，收敛心神，轻轻格挡开了$P"
      #             CYN "的剑招。\n"NOR;
      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate("可是$p并不慌乱，收敛心神，轻轻格挡开了$P的剑招。\n", bindings)
        )

      Performs.feedback(attacker, 60, 3)
      conn
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "yunhe-jian/chong",
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
  # #define CHONG "「" HIM "鹤冲九霄" NOR "」"
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
  #         if (userp(me) && ! me->query("can_perform/yunhe-jian/chong"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(CHONG "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #               (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" CHONG "。\n");
  # 
  #         if (me->query_skill("force") < 150)
  #                 return notify_fail("你的内功的修为不够，难以施展" CHONG "。\n");
  # 
  #         if (me->query_skill("yunhe-jian", 1) < 100)
  #                 return notify_fail("你的云鹤七剑修为不够，难以施展" CHONG "。\n");
  # 
  #         if (me->query("neili") < 100)
  #                 return notify_fail("你的真气不够，难以施展" CHONG "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "yunhe-jian")
  #                 return notify_fail("你没有激发云鹤七剑，难以施展" CHONG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIM "$N" HIM "陡然一声长啸，手中" + weapon->name() +
  #               HIM "疾射而出，勾勒出一道绚丽的剑芒，直划$n" HIM "前胸！\n" NOR;
  # 
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("parry");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = 50 + ap / 2 + random(ap / 2);
  #                 me->add("neili", -80);
  #                 me->start_busy(2);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 25,
  #                                            HIR "$n" HIR "奋力格挡，终究不敌，被$N"
  #                                            HIR "一剑刺中胸口，鲜血飞溅而出！\n" NOR);
  #         } else
  #         {
  #                 me->add("neili", -60);
  #                 me->start_busy(3);
  #                 msg += CYN "可是$p" CYN "并不慌乱，收敛心神，轻轻格挡开了$P"
  #                        CYN "的剑招。\n"NOR;
  #         }
  # 
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
