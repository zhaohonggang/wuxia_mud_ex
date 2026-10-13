defmodule Kantele.Combat.Skills.Performs.KuihuaMogong.Bian do
  @moduledoc """
  perform「无边无际」（source kuihua-mogong/bian.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 武器须为剑/针（空手则须
  准备 unarmed 为葵花魔功）→ 葵花魔功>=260 → 内力上限>=3700 → 内力>=300 →
  有武器则须激发 sword、空手则须准备 unarmed 为葵花魔功 → 目标存活 →
  目标未处於「无法控制真气」（no_perform）状态。
  ap = 葵花魔功 + 轻功；dp = 目标武学修养 + 目标轻功。
  命中判定：ap*3/5 + random(ap) > dp。
  命中：伤害 = ap + random(ap)、90% 外伤（REMOTE_ATTACK），扣 200 内力、忙乱 2，
        目标被点中穴道（no_perform），10+random(ap/30) 后自行恢复；
  未命中：扣 150 内力、忙乱 3。

  差异（TODO(migrate)）：
  - `final()` 的 `target->set_temp("no_perform", 1)` 折算为目标侧 combat.temp 标记；
    `call_out("bian_end", …)` 定时清除未建模，恢复文案保留在命中分支内；
  - LPC `can_perform` 的键是 `pixie-jian/po`（葵花魔功源自辟邪剑谱的取巧写法），
    本框架按本招自身 id `kuihua-mogong/bian` 把关，多出的门槛文案不影响对齐；
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

  @perform_id "kuihua-mogong/bian"
  @move_name "「无边无际」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "kuihua-mogong")
    ap = Stats.skill(stats, "kuihua-mogong") + Stats.skill(stats, "dodge")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon_type(combat, character),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_weapon_mapped(combat, character),
         :ok <- check_target_alive(target),
         :ok <- check_target_no_perform(target) do
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

      apply_effect(conn, character, target, combat)
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

  # LPC: if (weapon = me->query_temp("weapon"))
  #          { 若武器非剑/针则「你手里拿的不是剑，怎么施展…？」 }
  #          else { 若未准备 unarmed 为葵花魔功则「你并没有准备使用葵花魔功，如何施展…？」 }
  defp check_weapon_type(combat, character) do
    case Combat.weapon(combat) do
      nil ->
        prepared = Stats.prepared_perform(character.meta.stats, "unarmed")

        if prepared == nil or hd(String.split(prepared, "/")) != "kuihua-mogong" do
          {:error, "你并没有准备使用葵花魔功，如何施展#{@move_name}？\n"}
        else
          :ok
        end

      %{skill_type: st} when st == "sword" or st == "pin" ->
        :ok

      _ ->
        {:error, "你手里拿的不是剑，怎么施展#{@move_name}？\n"}
    end
  end

  # LPC: if ((int)me->query_skill("kuihua-mogong", 1) < 260)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "kuihua-mogong") < 260 do
      {:error, "你的葵花魔功不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("max_neili") < 3700) / if (me->query("neili") < 300)
  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 3700 -> {:error, "你的内力修为不足，难以施展#{@move_name}。\n"}
      vitals.neili < 300 -> {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  # LPC: if (weapon && me->query_skill_mapped("sword") != "kuihua-mogong")
  #          return notify_fail("你没有准备使用葵花魔功，难以施展…。\n");
  #     if (! weapon && me->query_skill_prepared("unarmed") != "kuihua-mogong")
  #          return notify_fail("你没有准备使用葵花魔功，难以施展…。\n");
  defp check_weapon_mapped(combat, character) do
    case Combat.weapon(combat) do
      nil ->
        prepared = Stats.prepared_perform(character.meta.stats, "unarmed")

        if prepared == nil or hd(String.split(prepared, "/")) != "kuihua-mogong" do
          {:error, "你没有准备使用葵花魔功，难以施展#{@move_name}。\n"}
        else
          :ok
        end

      _ ->
        if Stats.mapped(character.meta.stats, "sword") != "kuihua-mogong" do
          {:error, "你没有准备使用葵花魔功，难以施展#{@move_name}。\n"}
        else
          :ok
        end
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

  # LPC: if (target->query_temp("no_perform"))
  #          return notify_fail("对方现在已经无法控制真气，放胆攻击吧。\n");
  # 目标的 no_perform 状态取引用快照 meta 的 combat.temp（缺 meta 时按未受影响处理）
  defp check_target_no_perform(target) do
    if no_perform?(target) do
      {:error, "对方现在已经无法控制真气，放胆攻击吧。\n"}
    else
      :ok
    end
  end

  defp no_perform?(target) do
    case target do
      %{meta: %{combat: %{temp: %{no_perform: true}}}} -> true
      _ -> false
    end
  end

  # LPC: name = me->query_temp("weapon") ? "手中" + weapon->name()
  #                                  : finger_name[random(sizeof(finger_name))];
  # msg 的两段字面量被 name 拆开，E 侧用 <> name <> 保持拆分
  defp apply_effect(conn, character, target, combat) do
    fingers = ["左手中指", "左手无名指", "左手食指", "右手中指", "右手无名指", "右手食指"]
    rng = &:rand.uniform/1

    name =
      case Combat.weapon(combat) do
        nil -> Enum.at(fingers, Engine.rand(rng, 6))
        weapon -> "手中" <> Map.get(weapon, :name)
      end

    msg =
      "$N一声尖啸，身体猛然旋转不定，" <> name <>
        "顿时化成无数气流，犹如千万根银针，齐齐卷向$n！\n"

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

    # LPC: dp = target->query_skill("martial-cognize", 1) + target->query_skill("dodge");
    dp = Stats.skill(stats, "martial-cognize") + Stats.skill(stats, "dodge")

    # LPC: if (ap * 3 / 5 + random(ap) > dp)
    if div(ap * 3, 5) + Engine.rand(rng, ap) > dp do
      # LPC: damage = ap + random(ap);
      #          do_damage(me, target, REMOTE_ATTACK, damage, 90, (: final, …));
      #          me->add("neili", -200); me->start_busy(2);
      damage = ap + Engine.rand(rng, ap)
      character = apply_damage(character, damage, 90)

      # LPC: final(): target->set_temp("no_perform", 1);
      #               call_out("bian_end", 10 + random(ap / 30), me, target);
      combat = %{character.meta.combat | temp: Map.put(character.meta.combat.temp, :no_perform, true)}
      character = %{character | meta: %{character.meta | combat: combat}}
      Performs.feedback(attacker, 200, 2)

      # LPC: bian_end() 的恢复文案（call_out 定时器未建模，保留文案）：
      #   message_combatd("$N深深吸入一口气，脸色由白转红，看起来好多了。\n", target);
      #   tell_object(target, "你感到被扰乱的真气慢慢平静了下来。\n");
      _recover_msg = "$N深深吸入一口气，脸色由白转红，看起来好多了。\n"
      _calm_msg = "你感到被扰乱的真气慢慢平静了下来。\n"

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "$n只觉眼前无数寒光闪过，随即全身一阵刺痛，几股血柱自身上射出。\n$p陡然间一提真气，竟发现周身力道竟似涣散一般，全然无法控制。\n",
          bindings
        )
      )
      |> put_character(character)
    else
      # LPC: me->add("neili", -150); me->start_busy(3);
      Performs.feedback(attacker, 150, 3)

      conn
      |> Broadcast.publish(
        Messages.interpolate("$n大惊之下全然无法招架，急忙抽身急退数尺，躲开了这一招。\n", bindings)
      )
      |> put_character(character)
    end
  end

  # LPC: COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, percent, msg)
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
  # #define BIAN "「" HIG "无边无际" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # string final(object me, object target, int damage);
  # 
  # string *finger_name = ({ "左手中指", "左手无名指", "左手食指",
  #                          "右手中指", "右手无名指", "右手食指", });
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg, name;
  #         object weapon;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/pixie-jian/po"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(BIAN "只能对战斗中的对手使用。\n");
  # 
  #         if (weapon = me->query_temp("weapon"))
  #         {
  #                 if (weapon->query("skill_type") != "sword" &&
  #                     weapon->query("skill_type") != "pin")
  #                         return notify_fail("你手里拿的不是剑，怎么施"
  #                                            "展" BIAN "？\n");
  #         } else
  #         {
  #                 if (me->query_skill_prepared("unarmed") != "kuihua-mogong")
  #                         return notify_fail("你并没有准备使用葵"
  #                                            "花魔功，如何施展" BIAN "？\n");
  #         }
  # 
  #         if ((int)me->query_skill("kuihua-mogong", 1) < 260)
  #                 return notify_fail("你的葵花魔功不够娴熟，难以施展" BIAN "。\n");
  # 
  #         if ((int)me->query("max_neili") < 3700)
  #                 return notify_fail("你的内力修为不足，难以施展" BIAN "。\n");
  # 
  #         if (me->query("neili") < 300)
  #                 return notify_fail("你现在的真气不足，难以施展" BIAN "。\n");
  # 
  #         if (weapon && me->query_skill_mapped("sword") != "kuihua-mogong")
  #                 return notify_fail("你没有准备使用葵花魔功，难以施展" BIAN "。\n");
  # 
  #         if (! weapon && me->query_skill_prepared("unarmed") != "kuihua-mogong")
  #                 return notify_fail("你没有准备使用葵花魔功，难以施展" BIAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         if (target->query_temp("no_perform"))
  #                 return notify_fail("对方现在已经无法控制真气，放胆攻击吧。\n");
  # 
  #         if (me->query_temp("weapon"))
  #                 name = "手中" + weapon->name();
  #         else
  #                 name = finger_name[random(sizeof(finger_name))];
  # 
  #         msg = HIR "$N" HIR "一声尖啸，身体猛然旋转不定，" + name +
  #               HIR "顿时化成无数气流，犹如千万根银针，齐齐卷向$n" HIR "！\n" NOR;
  # 
  #         ap = me->query_skill("kuihua-mogong", 1) +
  #              me->query_skill("dodge");
  # 
  #         dp = target->query_skill("martial-cognize", 1) +
  #              target->query_skill("dodge");
  # 
  #         if (ap * 3 / 5 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap);
  #                 msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 90,
  #                                           (: final, me, target, damage :));
  #                 me->start_busy(2);
  #                 me->add("neili", -200);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "大惊之下全然无法招架，急忙"
  #                        "抽身急退数尺，躲开了这一招。\n" NOR;
  #                 me->start_busy(3);
  #                 me->add("neili", -150);
  #         }
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
  # 
  # string final(object me, object target, int ap)
  # {
  #         target->set_temp("no_perform", 1);
  #         call_out("bian_end", 10 + random(ap / 30), me, target);
  #         return HIR "$n" HIR "只觉眼前无数寒光闪过，随即全身一阵"
  #                "刺痛，几股血柱自身上射出。\n$p陡然间一提真气，"
  #                "竟发现周身力道竟似涣散一般，全然无法控制。\n" NOR;
  # }
  # 
  # void bian_end(object me, object target)
  # {
  #         if (target && target->query_temp("no_perform"))
  #         {
  #                 if (living(target))
  #                 {
  #                         message_combatd(HIC "$N" HIC "深深吸入一口"
  #                                         "气，脸色由白转红，看起来好"
  #                                         "多了。\n" NOR, target);
  # 
  #                         tell_object(target, HIY "你感到被扰乱的真气"
  #                                             "慢慢平静了下来。\n" NOR);
  #                 }
  #                 target->delete_temp("no_perform");
  #     }
  #     return;
  # }
end
