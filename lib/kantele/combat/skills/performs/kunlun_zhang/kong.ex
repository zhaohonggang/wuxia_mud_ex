defmodule Kantele.Combat.Skills.Performs.KunlunZhang.Kong do
  @moduledoc """
  perform「日入空山」（source kunlun-zhang/kong.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 不可双手都持武器 →
  目标未忙乱 → 昆仑掌法>=120 → 激发 strike 为昆仑掌法 → 准备昆仑掌法 →
  内力>=200 → 目标存活。
  ap = 掌法（strike）；dp = 目标招架。命中判定：ap/2 + random(ap) > dp。
  命中：伤害 = ap/3 + random(ap/3)、20% 外伤（UNARMED_ATTACK），扣 150 内力、
        忙乱 1，目标忙乱 ap/30+2；
  未命中：扣 80 内力、忙乱 3。

  差异（TODO(migrate)）：
  - 双持武器门槛的副手（`secondary_weapon`）未建模，取 `combat.equipped`
    的副手键，缺键时按未双持处理；
  - `target->is_busy()` 门槛取敌人引用快照 meta 的 combat.busy（缺 meta 时
    按未忙处理），使成为真正的施法前门槛（无起手广播、无内力消耗）；
  - 起手式的三段字面量在 C 侧由 `+ NOR + HIR +`（颜色宏）拆开，E 侧用
    list + `Enum.join("")` 保持三段；
  - `living(target)` 门槛在攻击方无 meta 可查时恒判存活，由目标侧
    `combat/perform-incoming` 的死亡检查兜底。
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

  @perform_id "kunlun-zhang/kong"
  @move_name "「日入空山」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "kunlun-zhang")
    ap = Stats.skill(stats, "strike")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_dual_weapon(combat),
         :ok <- check_target_busy(target),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_prepared(character),
         :ok <- check_resources(character),
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

  # LPC: if (me->query_temp("weapon") && me->query_temp("secondary_weapon"))
  # 副手武器未建模，取 equipped 的副手键（缺键时按未双持处理）
  defp check_dual_weapon(combat) do
    if Combat.weapon(combat) != nil and
         Map.get(combat.equipped, :secondary_weapon) != nil do
      {:error, "你两只手都拿着武器，怎么施展#{@move_name}？\n"}
    else
      :ok
    end
  end

  # LPC: if (target->is_busy())
  #          return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 目标忙乱取引用快照 meta 的 combat.busy（缺 meta 时按未忙处理）
  defp check_target_busy(target) do
    if busy?(target) do
      {:error, "#{Map.get(target, :name)}目前正自顾不暇，放胆攻击吧。\n"}
    else
      :ok
    end
  end

  defp busy?(target) do
    case target do
      %{meta: %{combat: %{busy: busy}}} -> busy > 0
      _ -> false
    end
  end

  # LPC: if (skill < 120)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "kunlun-zhang") < 120 do
      {:error, "你昆仑掌法等级不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "kunlun-zhang")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "strike") != "kunlun-zhang" do
      {:error, "你没有激发昆仑掌法，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "kunlun-zhang")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "strike")

    if prepared == nil or hd(String.split(prepared, "/")) != "kunlun-zhang" do
      {:error, "你没有准备昆仑掌法，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili") < 200)
  defp check_resources(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
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

  # LPC: msg = HIW "$N" HIW "陡然施出昆仑掌法绝技「" NOR + HIR "日入空山"
  #               NOR + HIW "」，一掌猛然拍出，掌影重重叠叠，笼罩$n" HIW "四面八方。\n" NOR;
  # 三段字面量在 C 侧由颜色宏的 + 拆开，E 侧用 list + Enum.join("") 保持三段
  defp apply_effect(conn, character, target) do
    msg =
      [
        "$N陡然施出昆仑掌法绝技「",
        "日入空山",
        "」，一掌猛然拍出，掌影重重叠叠，笼罩$n四面八方。\n"
      ]
      |> Enum.join("")

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

    # LPC: dp = target->query_skill("parry");
    dp = Stats.skill(stats, "parry")

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = ap / 3 + random(ap / 3);
      #          do_damage(me, target, UNARMED_ATTACK, damage, 20, …);
      #          me->add("neili", -150); me->start_busy(1);
      damage = div(ap, 3) + Engine.rand(rng, div(ap, 3))
      character = apply_damage(character, damage, 20)

      # LPC: target->start_busy(ap / 30 + 2);
      combat = Combat.start_busy(character.meta.combat, div(ap, 30) + 2)
      character = %{character | meta: %{character.meta | combat: combat}}
      Performs.feedback(attacker, 150, 1)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "$n只见$P的无数掌影向自己压来，一时不知该如何抵挡，顿时连中数招，无暇反击。\n",
          bindings
        )
      )
      |> put_character(character)
    else
      # LPC: me->add("neili", -80); me->start_busy(3);
      Performs.feedback(attacker, 80, 3)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "可是$p的看破了$P的企图，巧妙的拆招，没露半点破绽。\n",
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
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define KONG "「" HIR "日入空山" NOR "」"
  # 
  # inherit F_SSERVER;
  #  
  # int perform(object me)
  # {
  #         string msg;
  #         object /*weapon,*/ target;
  #         int skill, ap, dp, damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/kunlun-zhang/kong"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(KONG "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") && me->query_temp("secondary_weapon"))
  #                 return notify_fail("你两只手都拿着武器，怎么施展" KONG "？\n");
  # 
  #         skill = me->query_skill("kunlun-zhang", 1);
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #         if (skill < 120)
  #                 return notify_fail("你昆仑掌法等级不够，难以施展" KONG "。\n");
  #  
  #         if (me->query_skill_mapped("strike") != "kunlun-zhang")
  #                 return notify_fail("你没有激发昆仑掌法，难以施展" KONG "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "kunlun-zhang")
  #                 return notify_fail("你没有准备昆仑掌法，难以施展" KONG "。\n");
  # 
  #         if (me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不够，难以施展" KONG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "陡然施出昆仑掌法绝技「" NOR + HIR "日入空山"
  #               NOR + HIW "」，一掌猛然拍出，掌影重重叠叠，笼罩$n" HIW "四"
  #               "面八方。\n" NOR;
  # 
  #         ap = me->query_skill("strike");
  #         dp = target->query_skill("parry");
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 me->add("neili", -150);
  #                 damage = ap / 3 + random(ap / 3);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 20,
  #                                            HIR "$n" HIR "只见$P" HIR "的无数掌影"
  #                                            "向自己压来，一时不知该如何抵挡，顿时"
  #                                            "连中数招，无暇反击。\n" NOR);
  #                 me->start_busy(1);
  #                 target->start_busy(ap / 30 + 2);
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "的看破了$P" CYN
  #                        "的企图，巧妙的拆招，没露半点破绽"
  #                        "。\n" NOR;
  #                 me->add("neili", -80);
  #                 me->start_busy(3);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
