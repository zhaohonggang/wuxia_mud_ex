defmodule Kantele.Combat.Skills.Performs.LongxiangGong.Ji do
  @moduledoc """
  perform「般若极」（source longxiang-gong/perform/ji.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 空手 →
  龙象般若功>=300 → 内力上限>=5000 → 激发 unarmed 为龙象般若功 →
  激发 force 为龙象般若功 → 准备 unarmed 为龙象般若功 → 真气>=800 → 目标存活。
  `layer = min(龙象般若功/30, 13)`；`ap = 基本拳脚 + 内功`，目标
  `dp = 招架 + 内功`。
  - `ap/2 + random(ap) > dp`：若目标在运功护体（`shield`），先卸掉其
    `apply/armor` 并清 `shield`（追加「护体真气被摧毁」文案）；伤害
    `ap/2 + random(jiali*5)`（外伤 80%），攻击方扣 600 真气、忙乱 4；
  - 否则：攻击方扣 400 真气、忙乱 4，追加「斜斜一跃避开」文案。

  差异（TODO(migrate)）：
  - 起手文案含 `chinese_number(layer)`，且护体/伤害结算依赖目标属性，
    故全部结算（含起手广播）在目标侧 `resolve_incoming/4` 完成；攻击方的
    内力/忙乱经 `combat/perform-feedback` 回执；
  - `COMBAT_D->do_damage(..., UNARMED_ATTACK, damage, 80, …)` 折算为
    `Vitals.damage(:qi, damage)` + `Vitals.wound(:qi, damage*80/100)`；
  - `me->query("jiali")` 随事件数据下发（`combat.jiali`）；
  - `target->query_temp("apply/armor")` 以 `combat.temp[:armor]` 代理，
    `delete_temp("shield")` 即从 `combat.temp` 删除 `:shield`；
  - `living(target)` 门槛由目标侧死亡检查兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs

  @perform_id "longxiang-gong/ji"
  @move_name "「般若极」"
  @cn_digits ~w(零 一 二 三 四 五 六 七 八 九 十)

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "longxiang-gong")
    # LPC: layer = me->query_skill("longxiang-gong", 1) / 30; if (layer > 13) layer = 13;
    layer = min(div(lvl, 30), 13)
    # LPC: ap = me->query_skill("unarmed") + me->query_skill("force");
    ap = Stats.skill(stats, "unarmed") + Stats.skill(stats, "force")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_max_neili(character),
         :ok <- check_mapped(character),
         :ok <- check_mapped_force(character),
         :ok <- check_prepared(character),
         :ok <- check_neili(character),
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
          layer: layer,
          jiali: combat.jiali,
          rng: rng
        }
      })

      assign(conn, :prompt, false)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/longxiang-gong/ji"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  defp check_weapon(combat) do
    if Combat.occupied?(combat, :weapon) or Combat.occupied?(combat, :secondary_weapon) do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("longxiang-gong", 1) < 300)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "longxiang-gong") < 300 do
      {:error, "你的龙象般若功修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("max_neili") < 5000)
  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 5000 do
      {:error, "你的内力修为不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("unarmed") != "longxiang-gong")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "unarmed") != "longxiang-gong" do
      {:error, "你没有激发龙象般若功为拳脚，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("force") != "longxiang-gong")
  defp check_mapped_force(character) do
    if Stats.mapped(character.meta.stats, "force") != "longxiang-gong" do
      {:error, "你没有激发龙象般若功为内功，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("unarmed") != "longxiang-gong")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "unarmed")

    if prepared == nil or prepared |> String.split("/") |> hd() != "longxiang-gong" do
      {:error, "你没有准备使用龙象般若功，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili") < 800)
  defp check_neili(character) do
    if character.meta.vitals.neili < 800 do
      {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}
    else
      :ok
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
    layer = Map.get(data, :layer, 0)
    jiali = Map.get(data, :jiali, 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: msg = HIY "$N" HIY "运转龙象般若功第" + chinese_number(layer) + "层"
    #            "功力，双拳携着『" HIR "十龙十象" HIY "』之力朝$n" HIY "崩击"
    #            "\n而出，拳锋过处，竟卷起万里尘埃，正是密宗绝学「" HIW "般若" "极" HIY "」。\n" NOR;
    opening =
      "$N运转龙象般若功第" <>
        chinese_number(layer) <>
        "层功力，双拳携着『十龙十象』之力朝$n崩击\n而出，拳锋过处，竟卷起万里尘埃，正是密宗绝学「般若极」。\n"

    # LPC: dp = target->query_skill("parry") + target->query_skill("force");
    dp = Stats.skill(stats, "parry") + Stats.skill(stats, "force")

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: if (target->query_temp("shield"))
      #      { shd = target->query_temp("apply/armor");
      #        target->add_temp("apply/armor", -shd); target->delete_temp("shield");
      #        msg += HIW "$N" HIW "罡气涌至，竟然激起层层气浪，顿时将$n" HIW "的护体真气摧毁得荡然无存！\n" NOR; }
      {conn, character, msg} =
        if Map.get(character.meta.combat.temp || %{}, :shield) do
          shd = Map.get(character.meta.combat.temp || %{}, :armor, 0)
          combat = Combat.apply_temp(character.meta.combat, %{armor: -shd})
          combat = %{combat | temp: Map.delete(combat.temp || %{}, :shield)}
          character = %{character | meta: %{character.meta | combat: combat}}

          {conn, character,
           opening <>
             "$N罡气涌至，竟然激起层层气浪，顿时将$n的护体真气摧毁得荡然无存！\n"}
        else
          {conn, character, opening}
        end

      # LPC: jia = me->query("jiali"); damage = ap / 2 + random(jia * 5);
      #      msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80, …);
      #      me->start_busy(4); me->add("neili", -600);
      damage = div(ap, 2) + Engine.rand(rng, jiali * 5)

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 80, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      Performs.feedback(attacker, 600, 4)

      conn
      |> Broadcast.publish(
        msg <> "$n不及闪避，顿被$N双拳击个正中，般若罡劲破体而入，尽伤三焦六脉。\n",
        bindings
      )
      |> put_character(character)
    else
      # LPC: me->start_busy(4); me->add("neili", -400);
      #      msg += CYN "可是$p" CYN "识破了$P" CYN "这一招，斜斜一跃避开。\n" NOR;
      Performs.feedback(attacker, 400, 4)

      conn
      |> Broadcast.publish(opening <> "可是$p识破了$P这一招，斜斜一跃避开。\n", bindings)
      |> put_character(character)
    end
  end

  # LPC: chinese_number(layer) —— 层数（3..13）。
  defp chinese_number(i) when i < 0, do: "负" <> chinese_number(-i)
  defp chinese_number(i) when i <= 10, do: Enum.at(@cn_digits, i)
  defp chinese_number(i) when i < 20, do: "十" <> Enum.at(@cn_digits, i - 10)

  defp chinese_number(i) when i < 100 do
    if rem(i, 10) == 0 do
      Enum.at(@cn_digits, div(i, 10)) <> "十"
    else
      Enum.at(@cn_digits, div(i, 10)) <> "十" <> Enum.at(@cn_digits, rem(i, 10))
    end
  end

  defp chinese_number(i), do: Integer.to_string(i)

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define JI "「" HIY "般若极" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  # //      object weapon;
  #         int ap, dp, shd, jia, layer, damage;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/longxiang-gong/ji"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(JI "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(JI "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("longxiang-gong", 1) < 300)
  #                 return notify_fail("你的龙象般若功修为不够，难以施展" JI "。\n");
  # 
  #         if (me->query("max_neili") < 5000)
  #                 return notify_fail("你的内力修为不足，难以施展" JI "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "longxiang-gong")
  #                 return notify_fail("你没有激发龙象般若功为拳脚，难以施展" JI "。\n");
  # 
  #         if (me->query_skill_mapped("force") != "longxiang-gong")
  #                 return notify_fail("你没有激发龙象般若功为内功，难以施展" JI "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "longxiang-gong")
  #                 return notify_fail("你没有准备使用龙象般若功，难以施展" JI "。\n");
  # 
  #         if (me->query("neili") < 800)
  #                 return notify_fail("你现在的真气不足，难以施展" JI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         layer = me->query_skill("longxiang-gong", 1) / 30;
  # 
  #         if (layer > 13) layer = 13;
  # 
  #         msg = HIY "$N" HIY "运转龙象般若功第" + chinese_number(layer) + "层"
  #               "功力，双拳携着『" HIR "十龙十象" HIY "』之力朝$n" HIY "崩击"
  #               "\n而出，拳锋过处，竟卷起万里尘埃，正是密宗绝学「" HIW "般若"
  #               "极" HIY "」。\n" NOR;
  # 
  #         ap = me->query_skill("unarmed") +
  #              me->query_skill("force");
  # 
  #         dp = target->query_skill("parry") +
  #              target->query_skill("force");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 if (target->query_temp("shield"))
  #         {
  #                     shd = target->query_temp("apply/armor");
  # 
  #                     target->add_temp("apply/armor", -shd);
  #                     target->delete_temp("shield");
  # 
  #                     msg += HIW "$N" HIW "罡气涌至，竟然激起层层气浪，顿时将$n"
  #                                HIW "的护体真气摧毁得荡然无存！\n" NOR;
  #         }
  #                 jia = me->query("jiali");
  #                 damage = ap / 2 + random(jia * 5);
  # 
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80,
  #                                                HIR "$n" HIR "不及闪避，顿被$N" HIR
  #                                                "双拳击个正中，般若罡劲破体而入，尽"
  #                                                "伤三焦六脉。\n" NOR);
  # 
  #                 me->start_busy(4);
  #                 me->add("neili", -600);
  #         } else
  #         {
  #                 me->start_busy(4);
  #                 me->add("neili", -400);
  #                 msg += CYN "可是$p" CYN "识破了$P"
  #                        CYN "这一招，斜斜一跃避开。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
