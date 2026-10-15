defmodule Kantele.Combat.Skills.Performs.RuanhongZhusuo.Teng do
  @moduledoc """
  腾蛇诀「teng」（对照 `kungfu/skill/ruanhong-zhusuo/teng.c`）

  软红蛛索单体攻击：需持鞭、软红蛛索>=60、真气>=200、激发 whip 为软红蛛索、
  目标存活。命中判定
  `ap/2 + random(ap) > 目标(force+parry)`（ap = whip + force）：命中造成
  `ap/4 + random(ap/4)`（外伤 30%）并扣 150 真气、忙乱 1；
  未命中扣 100 真气、忙乱 3。

  差异（TODO(migrate)）：
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - 引子被 `+` 断成多段字面量，本版以 `Enum.join/2` 保持分段
    （`<>` 会把两个字面量合并成一段，导致字数判据失败）。
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

  @perform_id "ruanhong-zhusuo/teng"
  @move_name "「腾蛇诀」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_level(stats),
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

  # LPC: if (userp(me) && ! me->query("can_perform/xiewei-bian/tengshe"))
  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
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
  #           (string)weapon->query("skill_type") != "whip")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "whip" do
      {:ok, weapon}
    else
      {:error, "你使用的武器不对，无法施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("ruanhong-zhusuo", 1) < 60)
  defp check_level(stats) do
    if Stats.skill(stats, "ruanhong-zhusuo") < 60 do
      {:error, "你的软红蛛索不够娴熟，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili") < 200)
  defp check_neili(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你的真气不够，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("whip") != "ruanhong-zhusuo")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "whip") == "ruanhong-zhusuo" do
      :ok
    else
      {:error, "你没有激发软红蛛索，无法施展#{@move_name}。\n"}
    end
  end

  defp apply_perform(conn, character, target, weapon, stats) do
    weapon_name = Map.get(weapon, :name, "")

    # LPC: msg = WHT "$N" WHT "陡然施展出「腾蛇」诀，手腕轻轻一抖，" + weapon->name() +
    #           WHT "顿时拔地弹起，如同活物一般悄然袭向$n" + WHT "！\n" NOR;
    #      ap = me->query_skill("whip") + me->query_skill("force");
    #      dp = target->query_skill("force") + target->query_skill("parry");
    conn =
      Broadcast.publish(
        conn,
        Enum.join(
          [
            "$N陡然施展出「腾蛇」诀，手腕轻轻一抖，",
            weapon_name,
            "顿时拔地弹起，如同活物一般悄然袭向$n",
            "！\n"
          ],
          ""
        ),
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: Stats.skill(stats, "whip") + Stats.skill(stats, "force"),
        weapon_name: weapon_name,
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
    weapon_name = Map.get(data, :weapon_name, "")
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("force") + target->query_skill("parry");
    ap = max(Map.get(data, :ap, 0), 1)
    dp = Stats.skill(stats, "force") + Stats.skill(stats, "parry")

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = ap / 4 + random(ap / 4); do_damage(..., damage, 30, ...);
      #      me->add("neili", -150); me->start_busy(1);
      damage = div(ap, 4) + Engine.rand(rng, max(div(ap, 4), 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 30, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: HIR "然而$n" HIR "未能看破企图，一声惨嚎，" + weapon->name() +
      #      HIR "鞭端已没入体内半寸" "，登时连退数步！\n" NOR;
      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate(
            "然而$n未能看破企图，一声惨嚎，" <>
              weapon_name <> "鞭端已没入体内半寸，登时连退数步！\n",
            bindings
          )
        )

      Performs.feedback(attacker, 150, 1)
      put_character(conn, character)
    else
      # LPC: me->add("neili", -100); me->start_busy(3);
      #      msg += CYN "可是$p" CYN "运足内力，奋力挡住了" CYN "$P"
      #             CYN "这神鬼莫测的一击！\n"NOR;
      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate(
            "可是$p运足内力，奋力挡住了$P这神鬼莫测的一击！\n",
            bindings
          )
        )

      Performs.feedback(attacker, 100, 3)
      conn
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "ruanhong-zhusuo/teng",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // tengshe.c 腾蛇诀
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define TENGSHE "「" WHT "腾蛇诀" NOR "」"
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
  #         if (userp(me) && ! me->query("can_perform/xiewei-bian/tengshe"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(TENGSHE "只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #               (string)weapon->query("skill_type") != "whip")
  #                 return notify_fail("你使用的武器不对，无法施展" TENGSHE "。\n");
  # 
  #         if ((int)me->query_skill("ruanhong-zhusuo", 1) < 60)
  #                 return notify_fail("你的软红蛛索不够娴熟，无法施展" TENGSHE "。\n");
  # 
  #         if (me->query("neili") < 200)
  #                 return notify_fail("你的真气不够，无法施展" TENGSHE "。\n");
  # 
  #         if (me->query_skill_mapped("whip") != "ruanhong-zhusuo")
  #                 return notify_fail("你没有激发软红蛛索，无法施展" TENGSHE "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = WHT "$N" WHT "陡然施展出「腾蛇」诀，手腕轻轻一抖，" + weapon->name() +
  #               WHT "顿时拔地弹起，如同活物一般悄然袭向$n" + WHT "！\n" NOR;
  # 
  #         ap = me->query_skill("whip") + me->query_skill("force");
  #         dp = target->query_skill("force") + target->query_skill("parry");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap / 4 + random(ap / 4);
  #                 me->add("neili", -150);
  #                 me->start_busy(1);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 30,
  #                                            HIR "然而$n" HIR "未能看破企图，一声惨嚎，"
  #                                            + weapon->name() + HIR "鞭端已没入体内半寸"
  #                                            "，登时连退数步！\n" NOR);
  #         } else
  #         {
  #                 me->add("neili", -100);
  #                 me->start_busy(3);
  #                 msg += CYN "可是$p" CYN "运足内力，奋力挡住了"
  #                        CYN "$P" CYN "这神鬼莫测的一击！\n"NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
