defmodule Kantele.Combat.Skills.Performs.JiashaFumogong.Zhe do
  @moduledoc """
  perform「避云遮日」（source jiasha-fumogong/zhe.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 空手 →
  内力上限>=2000 → 袈裟伏魔功>=140 → 激发 unarmed 为袈裟伏魔功 →
  准备 unarmed 为袈裟伏魔功 → 真气>=400 → 目标存活。
  命中判定 `ap/2 + random(ap)` vs 目标 `parry + con*20`
  （`ap = 基本拳脚 + con*20`）：命中取 `count = ap/4`，失手取 `count = ap/9`；
  随后连出 9 击（`COMBAT_D->do_attack`）。
  攻击方无条件扣 300 真气并忙乱 `1+random(5)`。
  命中且攻击方 `max_neili > 目标 max_neili * 2` 且攻击方 `neili > 500` 时，
  追加「击飞」文案、额外扣 500 真气、忙乱 3，并把目标 `eff_qi`/`eff_jing` 归零。

  差异（TODO(migrate)）：
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - 9 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线）折算为每击 `count`
    基础判定 + 伤害（与 `honglian_dao/huo.ex` 同构）；`.c` 的
    `add_temp("apply/attack", count)` / 收招 `-count` 即该折算的数值来源；
  - 「击飞」分支需要目标的 `max_neili`，故在目标侧判定；其攻击方扣内/忙乱经
    `Performs.feedback/3` 回传（无条件那 300 真气与忙乱已在攻击方侧扣除）；
  - LPC `set("eff_qi", 0)`/`set("eff_jing", 0)` 在本引擎折合
    `vitals.max_qi/qi` 与 `max_jing/jing` 同时归零（`Vitals.wound` 的钳制下限为 1，
    故直接改字段）；`Vitals.regenerate` 会随时间把 `max_*` 拉回 `base_*`；
  - `.c` 用 `message_sort(msg, me, target)` 把起手式与结算文案合成一条广播，
    此处按本仓库约定拆为「攻击方发起手式 / 目标侧发结算文案」两条。
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
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "jiasha-fumogong/zhe"
  @move_name "「避云遮日」"

  # LPC: for (i = 0; i < 9; i++) { ... COMBAT_D->do_attack(me, target, 0, 0); }
  @strikes 9

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    vitals = character.meta.vitals
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jiasha-fumogong")
    # LPC: ap = me->query_skill("unarmed") + me->query("con") * 20;
    ap = Stats.skill(stats, "unarmed") + (stats.con || 0) * 20

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_max_neili(character),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
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
          strikes: @strikes,
          attacker_max_neili: vitals.max_neili,
          attacker_neili: vitals.neili,
          rng: rng
        }
      })

      apply_effect(conn, character, target, rng)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/jiasha-fumogong/zhe"))
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

  # LPC: if (me->query_skill("jiasha-fumogong", 1) < 140)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "jiasha-fumogong") < 140 do
      {:error, "你的袈裟伏魔功还不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("unarmed") != "jiasha-fumogong")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "unarmed") == "jiasha-fumogong" do
      :ok
    else
      {:error, "你现在没有激发袈裟伏魔功为拳脚，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill_prepared("unarmed") != "jiasha-fumogong")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "unarmed")

    if prepared == nil or prepared |> String.split("/") |> hd() != "jiasha-fumogong" do
      {:error, "你现在没有准备使用袈裟伏魔功，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("max_neili") < 2000)
  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 2000 do
      {:error, "你的内力的修为不够，现在无法使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 400)
  defp check_neili(character) do
    if character.meta.vitals.neili < 400 do
      {:error, "你的真气不够，无法运用#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活，
  # 由目标侧 combat/perform-incoming 的死亡检查兜底。
  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target, rng) do
    # LPC: msg = HIG "$N" HIG "大喝一声，施出绝招「" HIR "避云遮日" HIG "」，顿时真气迸发，"
    #            "衣衫鼓动，双手猛然如闪电般地拍向$n" HIG "。\n" NOR;
    #      message_sort(msg, me, target);
    #      me->add("neili", -300);
    #      9 × COMBAT_D->do_attack(me, target, 0, 0);
    #      me->start_busy(1 + random(5));
    # 「击飞」分支（额外 -500 真气/忙乱 3/目标 eff_qi,eff_jing 归零）在目标侧结算。
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 300}
    combat = Combat.start_busy(character.meta.combat, 1 + Engine.rand(rng, 5))
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    conn
    |> Broadcast.publish(
      "$N大喝一声，施出绝招#{@move_name}，顿时真气迸发，衣衫鼓动，双手猛然如闪电般地拍向$n。\n",
      n1: character.name,
      n2: target.name
    )
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    # .c 的 living(target) 门槛由目标侧 death 检查兜底
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    strikes = Map.get(data, :strikes, @strikes)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("parry") + target->query("con") * 20;
    dp = Stats.skill(stats, "parry") + (stats.con || 0) * 20

    # LPC: if (ap / 2 + random(ap) > dp) { count = ap / 4; ... } else { count = ap / 9; }
    {conn, character, level} =
      if div(ap, 2) + Engine.rand(rng, ap) > dp do
        if crush?(character, data) do
          # LPC: msg += HIR "$n" HIR "全身一颤，立足不稳，被$N" HIR "这招击得飞起，重重的跌落在地上。\n" NOR;
          #      me->add("neili", -500); me->start_busy(3);
          #      target->set("eff_qi", 0); target->set("eff_jing", 0);
          vitals = %{character.meta.vitals | qi: 0, max_qi: 0, jing: 0, max_jing: 0}
          character = %{character | meta: %{character.meta | vitals: vitals}}

          Performs.feedback(attacker, 500, 3)

          conn =
            Broadcast.publish(
              conn,
              Messages.interpolate(
                "$n全身一颤，立足不稳，被$N这招击得飞起，重重的跌落在地上。\n",
                bindings
              )
            )

          {conn, character, div(ap, 4)}
        else
          {conn, character, div(ap, 4)}
        end
      else
        {conn, character, div(ap, 9)}
      end

    level = max(level, 1)
    dodge = Stats.skill(character.meta.stats, "dodge")

    # LPC 连击 9 次，每次 COMBAT_D->do_attack(me, target, 0, 0)
    damage =
      Enum.reduce(1..strikes, 0, fn _, acc ->
        if div(level, 2) + Engine.rand(rng, level) > dodge do
          acc + level + Engine.rand(rng, level)
        else
          acc
        end
      end)

    vitals =
      if damage > 0 do
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage, 3))
      else
        character.meta.vitals
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn
    |> put_character(character)
  end

  # LPC: if ( me->query("max_neili") > target->query("max_neili") * 2
  #           && me->query("neili") > 500 )
  defp crush?(character, data) do
    Map.get(data, :attacker_max_neili, 0) > character.meta.vitals.max_neili * 2 and
      Map.get(data, :attacker_neili, 0) > 500
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define JIU "「" HIR "避云遮日" NOR "」"
  # 
  # inherit F_SSERVER;
  #  
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int ap, dp;
  #         int count;
  #         int i;
  #  
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (userp(me) && ! me->query("can_perform/jiasha-fumogong/zhe"))
  #                return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(JIU "只能对战斗中的对手使用。\n");
  #  
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(JIU "只能空手施展。\n");
  #                 
  #         if (me->query("max_neili") < 2000)
  #                 return notify_fail("你的内力的修为不够，现在无法使用" JIU "。\n");
  # 
  #         if (me->query_skill("jiasha-fumogong", 1) < 140)
  #                 return notify_fail("你的袈裟伏魔功还不够娴熟，难以施展" JIU "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "jiasha-fumogong")
  #                 return notify_fail("你现在没有激发袈裟伏魔功为拳脚，难以施展" JIU "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "jiasha-fumogong")
  #                 return notify_fail("你现在没有准备使用袈裟伏魔功，难以施展" JIU "。\n");
  # 
  #         if ((int)me->query("neili") < 400)
  #                 return notify_fail("你的真气不够，无法运用" JIU "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIG "$N" HIG "大喝一声，施出绝招「" HIR "避云遮日" HIG "」，顿时真气迸发，衣衫鼓动，双手"
  #               "猛然如闪电般地拍向$n" HIG "。\n" NOR;
  # 
  #         ap = me->query_skill("unarmed") + me->query("con") * 20;
  #         dp = target->query_skill("parry") + target->query("con") * 20;
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 count = ap / 4;
  #                 if ( me->query("max_neili") > target->query("max_neili") * 2
  #                      && me->query("neili") > 500 )
  #                 {
  #                 msg += HIR "$n" HIR "全身一颤，立足不稳，被$N"
  #                        HIR "这招击得飞起，重重的跌落在地上。\n" NOR;
  # 
  #                 me->add("neili", -500);
  #                 me->start_busy(3);
  # 
  #               //  message_combatd(msg, me, target);
  # 
  #                 target->set("eff_qi", 0);
  #                 target->set("eff_jing", 0);
  #                 //target->unconcious(me);
  #                 }
  #         } else
  #         {
  #                 count = ap / 9;
  # 
  #         }
  # 
  #         message_sort(msg, me, target);
  #         me->add_temp("apply/attack", count);
  # 
  #         me->add("neili", -300);
  # 
  #         for (i = 0; i < 9; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #               //  if (random(5) < 2 && ! target->is_busy())
  #                //         target->start_busy(1);
  # 
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  # 
  #         me->start_busy(1 + random(5));
  # 
  #         me->add_temp("apply/attack", -count);
  # 
  #         return 1;
  # }
end
