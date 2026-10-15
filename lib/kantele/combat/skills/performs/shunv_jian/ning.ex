defmodule Kantele.Combat.Skills.Performs.ShunvJian.Ning do
  @moduledoc """
  宁氏一剑「ning」（对照 `kungfu/skill/shunv-jian/ning.c`）

  淑女剑法单体攻击：需持剑、基本轻功>=100、基本内功>=100、淑女剑法>=100、
  激发 sword 为淑女剑法、真气>=250、目标存活。命中判定
  `ap*11/20 + random(ap) > 目标(parry+dodge)`（ap = sword + force）：命中造成
  `ap + random(ap/2)`（外伤 65%）并扣 220 真气、忙乱 `1 + random(3)`；
  未命中扣 120 真气、忙乱 2。

  差异（TODO(migrate)）：
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - 引子走 `message_sort`，本引擎统一 `Broadcast.publish`；结果段走目标侧结算。
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

  @perform_id "shunv-jian/ning"
  @move_name "「宁氏一剑」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_dodge(stats),
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

  # LPC: if (userp(me) && ! me->query("can_perform/shunv-jian/ning"))
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
  #           (string)weapon->query("skill_type") != "sword")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      {:ok, weapon}
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill("dodge", 1) < 100)
  defp check_dodge(stats) do
    if Stats.skill(stats, "dodge") < 100 do
      {:error, "你的基本轻功的修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill("force", 1) < 100)
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 100 do
      {:error, "你的基本内功的修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill("shunv-jian", 1) < 100)
  defp check_level(stats) do
    if Stats.skill(stats, "shunv-jian") < 100 do
      {:error, "你的淑女剑法修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "shunv-jian")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "shunv-jian" do
      :ok
    else
      {:error, "你没有激发淑女剑法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query("neili") < 250)
  defp check_neili(character) do
    if character.meta.vitals.neili < 250 do
      {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, weapon, stats) do
    weapon_name = Map.get(weapon, :name, "")

    # LPC: msg = HIW "\n$N" HIW "娇喝一声，飞身而起，使出绝招「" HIM "宁氏一剑" HIW "」将毕生功力运于"
    #           + weapon->name() + HIW "上，顿时剑光四射，剑势如虹，将$n" HIW "笼罩" HIW "。\n" NOR;
    #      ap = me->query_skill("sword") + me->query_skill("force");
    #      dp = target->query_skill("parry") + target->query_skill("dodge");
    conn =
      Broadcast.publish(
        conn,
        "\n$N娇喝一声，飞身而起，使出绝招「宁氏一剑」将毕生功力运于" <>
          weapon_name <> "上，顿时剑光四射，剑势如虹，将$n笼罩。\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: Stats.skill(stats, "sword") + Stats.skill(stats, "force"),
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

    # LPC: dp = target->query_skill("parry") + target->query_skill("dodge");
    ap = max(Map.get(data, :ap, 0), 1)
    dp = Stats.skill(stats, "parry") + Stats.skill(stats, "dodge")

    if div(ap * 11, 20) + Engine.rand(rng, ap) > dp do
      # LPC: damage = ap + random(ap / 2); do_damage(..., damage, 65, ...);
      #      me->add("neili", -220); me->start_busy(1 + random(3));
      damage = ap + Engine.rand(rng, max(div(ap, 2), 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 65, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: HIR "$n" HIR "开料不及，正欲躲闪，却已经中剑。\n" NOR;
      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate("$n开料不及，正欲躲闪，却已经中剑。\n", bindings)
        )

      Performs.feedback(attacker, 220, 1 + Engine.rand(rng, 3))
      put_character(conn, character)
    else
      # LPC: msg += CYN "可是$n" CYN "随手招架，竟将这招化解。\n"NOR;
      #      me->add("neili", -120); me->start_busy(2);
      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate("可是$n随手招架，竟将这招化解。\n", bindings)
        )

      Performs.feedback(attacker, 120, 2)
      conn
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "shunv-jian/ning",
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
  # #define NING "「" HIM "宁氏一剑" NOR "」"
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
  #         if (userp(me) && ! me->query("can_perform/shunv-jian/ning"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(NING "只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #               (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" NING "。\n");
  # 
  #         if (me->query_skill("dodge", 1) < 100)
  #                 return notify_fail("你的基本轻功的修为不够，难以施展" NING "。\n");
  # 
  #         if (me->query_skill("force", 1) < 100)
  #                 return notify_fail("你的基本内功的修为不够，难以施展" NING "。\n");
  # 
  #         if (me->query_skill("shunv-jian", 1) < 100)
  #                 return notify_fail("你的淑女剑法修为不够，难以施展" NING "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "shunv-jian")
  #                 return notify_fail("你没有激发淑女剑法，难以施展" NING "。\n");
  # 
  #         if (me->query("neili") < 250)
  #                 return notify_fail("你现在真气不够，难以施展" NING "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "\n$N" HIW "娇喝一声，飞身而起，使出绝招「" HIM "宁氏一剑" HIW "」将毕生功力运于"
  #               + weapon->name() + HIW "上，顿时剑光四射，剑势如虹，将$n" HIW "笼罩" HIW "。\n" NOR;
  # 
  #         ap = me->query_skill("sword") + me->query_skill("force");
  #         dp = target->query_skill("parry") + target->query_skill("dodge");
  # 
  #         if (ap * 11 / 20 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 2);
  #                 me->add("neili", - 220);
  #                 me->start_busy(1 + random(3));
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 65,
  #                                            HIR "$n" HIR "开料不及，正欲躲闪，却已经中剑。\n" NOR);
  #         } else
  #         {
  #                 me->add("neili", -120);
  #                 me->start_busy(2);
  #                 msg += CYN "可是$n" CYN "随手招架，竟将这招化解。\n"NOR;
  #         }
  # 
  #         message_sort(msg, me, target);
  # 
  #         return 1;
  # }
end
