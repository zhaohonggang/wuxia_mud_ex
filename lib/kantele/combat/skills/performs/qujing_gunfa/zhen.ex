defmodule Kantele.Combat.Skills.Performs.QujingGunfa.Zhen do
  @moduledoc """
  perform「震雷乾坤」（对照 `kungfu/skill/qujing-gunfa/zhen.c`）

  门槛：棍类武器、neili>=300、max_neili>=4000、qujing-gunfa>=200、force>=350、
  激发 club 为 qujing-gunfa 且 force ∈ {hunyuan-yiqi,yijinjing,luohan-fumogong}、
  目标存活且战斗中。

  攻击方发 `perform-incoming`；先以 `ap/2 + random(ap*2)`（ap=club）对目标
  `dp=parry` 判定「气势压制」：命中则临时加成 attack/damage 各 `ap/5`，随后
  连出 10 击 `do_attack`；未命中则无加成。
  攻击方扣 200 内力并忙乱 `1+random(9)`（由目标侧 `combat/perform-feedback` 回执）。

  差异（TODO(migrate)）：
  - LPC 的 10 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线）折算为
    每击 `level/10` 基础伤害 + 与「气势压制」同构的命中判定
    （`ap/2 + random(ap)` vs `parry`，压制成功时另加 `ap/5`）；
  - `living(target)` 门槛未实现，由目标侧 `combat/perform-incoming` 兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "qujing-gunfa/zhen"
  @move_name "「震雷乾坤」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "qujing-gunfa")
    ap = Stats.skill(stats, "club")

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
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

  defp check_gates(character) do
    with :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_resources(character),
         :ok <- check_weapon(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "qujing-gunfa") < 200 -> {:error, "你取经棍法不够娴熟，难以施展#{@move_name}。\n"}
      Stats.skill(stats, "force") < 350 -> {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      not (Stats.mapped(stats, "force") in ["hunyuan-yiqi", "yijinjing", "luohan-fumogong"]) ->
        {:error, "你现在没有激发少林内功为内功，难以施展#{@move_name}。\n"}

      Stats.mapped(stats, "club") != "qujing-gunfa" ->
        {:error, "你没有激发取经棍法，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 4000 -> {:error, "你的内力修为太弱，难以施展#{@move_name}。\n"}
      vitals.neili < 300 -> {:error, "你现在的真气太弱，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp check_weapon(character) do
    weapon = Combat.weapon(character.meta.combat)

    cond do
      weapon == nil or weapon.skill_type != "club" -> {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character, target) do
    # 前置广播：本招无条件攻击方消耗/忙乱，由目标侧结算后经 perform-feedback 回执
    weapon_name = Combat.weapon(character.meta.combat).name

    conn =
      Broadcast.publish(
        conn,
        "$N将手中" <>
          weapon_name <>
          "缓缓压向$n，棍体隐隐带着风雷之劲，正是取经棍法杀着「震雷乾坤」！\n电光火石间，棍端竟全被紫电所笼罩，" <>
          weapon_name <>
          "幻作千百根相似，奔雷掣电般向$n席卷而去。",
        n1: character.name,
        n2: target.name
      )

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「震雷乾坤」只能对战斗中的对手使用。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？", n1: attacker.name, n2: character.name)
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    level = max(Map.get(data, :level, 0), 1)
    stats = character.meta.stats
    parry = Stats.skill(stats, "parry")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (ap/2 + random(ap*2) > dp) 气势压制成功 → count = ap/5 临时加成
    suppressed = div(ap, 2) + Engine.rand(rng, ap * 2) > parry

    # LPC: for (i = 0; i < 10; i++) COMBAT_D->do_attack(me, target, weapon, 0);
    # 折算：每击 level/10 基础伤害 + 命中判定（压制成功时命中加成 ap/5）
    per_hit = max(div(level, 10), 1)
    count = if suppressed, do: div(ap, 5), else: 0
    hit_ap = div(ap, 2) + count

    {damage, _hits} =
      Enum.reduce(1..10, {0, 0}, fn _, {damage_acc, hit_acc} ->
        if hit_ap + Engine.rand(rng, ap) > parry do
          {damage_acc + per_hit + Engine.rand(rng, per_hit), hit_acc + 1}
        else
          {damage_acc, hit_acc}
        end
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # 攻击方：add("neili", -200) + start_busy(1 + random(9))
    Performs.feedback(attacker, 200, 1 + Engine.rand(rng, 9))

    # 压制成功/失败各一句（与 .c 一致）；命中与否仅影响伤害，不影响该段文案
    msg =
      if suppressed do
        "$n被$N气势所撼，完全不知该如何招架，竟而呆立当场！\n"
      else
        "$n见$N气势如虹，心下凛然，急忙凝神聚气，小心应付！\n"
      end

    result = Messages.interpolate(msg, bindings)

    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}], "apply_adds": ["attack", "damage"], "assign_refs": [{"ap", "club"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(1 + random(9));"], "level_gates": [{"force", "350"}, {"qujing-gunfa", "200"}], "map_gates": [{"club", "qujing-gunfa"}, {"force", "hunyuan-yiqi"}, {"force", "luohan-fumogong"}, {"force", "yijinjing"}], "remote_damage": false, "resource_gates": [{"max_neili", "4000"}, {"max_neili", "4500"}, {"neili", "300"}], "var_gates": [{"i", "10"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHEN "「" HIR "震雷乾坤" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int i, ap, dp, count;
  # 
  #         if (userp(me) && ! me->query("can_perform/qujing-gunfa/zhen"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHEN "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "club")
  #                 return notify_fail("你使用的武器不对，难以施展" ZHEN "。\n");
  #                 
  #         if ((me->query_skill_mapped("force") != "hunyuan-yiqi") && (me->query_skill_mapped("force") != "yijinjing") && (me->query_skill_mapped("force") != "luohan-fumogong")) 
  #                 return notify_fail("你现在没有激发少林内功为内功，难以施展" ZHEN "。\n"); 
  # 
  #         if (me->query_skill_mapped("club") != "qujing-gunfa")
  #                 return notify_fail("你没有激发取经棍法，难以施展" ZHEN "。\n");
  # 
  #         if(me->query_skill("qujing-gunfa", 1) < 200 )
  #                 return notify_fail("你取经棍法不够娴熟，难以施展" ZHEN "。\n");
  # 
  #         if( (int)me->query_skill("force") < 350 )
  #                 return notify_fail("你的内功修为不够，难以施展" ZHEN "。\n");
  # 
  #         //if( (int)me->query("max_neili") < 4500 )
  #         if( (int)me->query("max_neili") < 4000 )
  #                 return notify_fail("你的内力修为太弱，难以施展" ZHEN "。\n");
  # 
  #         if( (int)me->query("neili") < 300 )
  #                 return notify_fail("你现在的真气太弱，难以施展" ZHEN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "将手中" + weapon->name() + HIW "缓缓压向$n"
  #               HIW "，棍体隐隐带着风雷之劲，正是取经棍法杀着「" HIR "震"
  #               "雷乾坤" HIW "」！\n电光火石间，棍端竟全被紫电所笼罩，" +
  #               weapon->name() + HIW "幻作千百根相似，奔雷掣电般向$n" HIW
  #               "席卷而去。\n" NOR;
  # 
  #         ap = me->query_skill("club");
  #         dp = target->query_skill("parry");
  # 
  #         if (ap / 2 + random(ap * 2) > dp)
  #         {
  #                 msg += HIR "$n" HIR "被$N" HIR "气势所撼，完全不知该如"
  #                        "何招架，竟而呆立当场！\n" NOR;
  #                 count = ap / 5;
  #                 me->add_temp("apply/attack", count);
  #                 me->add_temp("apply/damage", count);
  #         } else
  #         {
  #                 msg += HIC "$n" HIC "见$N" HIC "气势如虹，心下凛然，急"
  #                        "忙凝神聚气，小心应付！\n" NOR;
  #                 count = 0;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         me->add("neili", -200);
  # 
  #         for (i = 0; i < 10; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  # 
  #         me->add_temp("apply/attack", -count);
  #         me->add_temp("apply/damage", -count);
  #         me->start_busy(1 + random(9));
  #         return 1;
  # }
end
