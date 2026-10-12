defmodule Kantele.Combat.Skills.Performs.DabeiZhang.Bei do
  @moduledoc """
  perform「万里鲸涛大悲神诀」（source dabei-zhang/bei.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 未持兵器 → 内功>=300 →
  内力上限>=3500 → 大悲神掌>=220 → 激发 strike 为大悲神掌 → 准备大悲神掌 →
  真气>=500 → 目标存活。
  前置广播后以 `ap = strike + int*10`、目标 `dp = 目标内功 + 目标int*10` 判定
  `ap/2 + random(ap) > dp`：命中则主招 `damage = ap + random(ap/2)`、按 200% 计
  qi 伤；随后连出 4 击（每击 1/3 概率令未忙乱的目标忙乱 1 回合）。攻击方扣 300
  真气并忙乱 `4 + random(3)`。

  差异（TODO(migrate)）：
  - LPC 的 4 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线）折算为每击
    `ap/10` 基础伤害 + 命中判定 `ap/2 + random(ap)` vs 目标 `dodge`；
  - `.c` 的 `me->query_temp("secondary_weapon")` 副兵器检查未单独建模，统一按
    `Combat.weapon/1` 判空手（同 chilian-shenzhang/lian）；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧 `combat/perform-incoming`
    的死亡检查兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "dabei-zhang/bei"
  @move_name "「万里鲸涛大悲神诀」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "dabei-zhang")
    # LPC: ap = me->query_skill("strike") + me->query("int") * 10;
    ap = Stats.skill(stats, "strike") + stats.int * 10

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(character),
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

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  defp check_weapon(character) do
    if Combat.weapon(character.meta.combat) != nil do
      {:error, "#{@move_name}只能空手使用。\n"}
    else
      :ok
    end
  end

  # LPC 顺序：force < 300 → max_neili < 3500 → dabei-zhang < 220
  defp check_levels(character) do
    stats = character.meta.stats
    vitals = character.meta.vitals

    cond do
      Stats.skill(stats, "force") < 300 ->
        {:error, "你内功修为不够，难以施展#{@move_name}。\n"}

      vitals.max_neili < 3500 ->
        {:error, "你内力修为不够，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "dabei-zhang") < 220 ->
        {:error, "你大悲神掌火候不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "dabei-zhang")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "strike") == "dabei-zhang" do
      :ok
    else
      {:error, "你没有激发大悲神掌，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "dabei-zhang")
  defp check_prepared(character) do
    case Stats.prepared_perform(character.meta.stats, "strike") do
      nil ->
        {:error, "你没有准备大悲神掌，难以施展#{@move_name}。\n"}

      value ->
        if String.split(value, "/") |> hd() == "dabei-zhang" do
          :ok
        else
          {:error, "你没有准备大悲神掌，难以施展#{@move_name}。\n"}
        end
    end
  end

  defp check_resources(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活，
  # 由目标侧 combat/perform-incoming 的死亡检查兜底。
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIW "$N" HIW "凄然一声长啸，施出「" HIG "万里鲸涛大悲神诀"
    #            HIW "」，双掌翻滚出漫天掌影，尽数拍向$n" HIW "。\n" NOR;
    #      message_combatd(msg, me, target);
    # 命中/伤害/连击在目标侧结算（dp 需目标内功与资质）。
    conn
    |> Broadcast.publish(
      "$N凄然一声长啸，施出「万里鲸涛大悲神诀」，双掌翻滚出漫天掌影，尽数拍向$n。\n",
      n1: character.name,
      n2: target.name
    )
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

    # LPC: dp = target->query_skill("force") + target->query("int") * 10;
    dp = Stats.skill(stats, "force") + stats.int * 10

    # LPC: if (ap / 2 + random(ap) > dp)
    landed = div(ap, 2) + Engine.rand(rng, ap) > dp

    # LPC: for (i = 0; i < 4; i++) { if (! me->is_fighting(target)) break;
    #        if (random(3) == 1 && ! target->is_busy()) target->start_busy(1);
    #        COMBAT_D->do_attack(me, target, 0, 0); }
    # 折算：每击 ap/10 基础伤害 + 命中判定 ap/2 + random(ap) vs 目标 dodge。
    dodge = Stats.skill(stats, "dodge")
    per_hit = max(div(ap, 10), 1)

    {loop_damage, combat} =
      Enum.reduce(1..4, {0, character.meta.combat}, fn _, {acc, combat_acc} ->
        combat_acc =
          if Engine.rand(rng, 3) == 1 and not Combat.busy?(combat_acc) do
            Combat.start_busy(combat_acc, 1)
          else
            combat_acc
          end

        if div(ap, 2) + Engine.rand(rng, ap) > dodge do
          {acc + per_hit + Engine.rand(rng, per_hit), combat_acc}
        else
          {acc, combat_acc}
        end
      end)

    # LPC 主招：damage = ap + random(ap / 2); do_damage(..., UNARMED_ATTACK, damage, 200, ...)
    vitals = character.meta.vitals

    vitals =
      if landed do
        main = ap + Engine.rand(rng, max(div(ap, 2), 1))

        vitals
        |> Vitals.damage(:qi, main)
        |> Vitals.wound(:qi, div(main * 200, 100))
      else
        vitals
      end

    # LPC 连击：COMBAT_D->do_attack 的伤害按 1/3 计创伤
    vitals =
      if loop_damage > 0 do
        vitals
        |> Vitals.damage(:qi, loop_damage)
        |> Vitals.wound(:qi, div(loop_damage, 3))
      else
        vitals
      end

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    # LPC: me->add("neili", -300); me->start_busy(4 + random(3));
    Performs.feedback(attacker, 300, 4 + Engine.rand(rng, 3))

    msg =
      if landed,
        do: "$n勘破不透掌中虚实，$N双掌正中$p前胸，“喀嚓喀嚓”接连断了数根肋骨。\n",
        else: "$n见$N这掌来势非凡，不敢轻易招架，当即飞身纵跃闪开。\n"

    conn
    |> Broadcast.publish(Messages.interpolate(msg, bindings))
    |> put_character(character)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define BEI "「" HIW "万里鲸涛大悲神诀" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         int i, ap, dp;
  #         // object weapon;
  # 
  #         if (userp(me) && ! me->query("can_perform/dabei-zhang/bei"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(BEI "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(BEI "只能空手使用。\n");
  # 
  #         if ((int)me->query_skill("force") < 300)
  #                 return notify_fail("你内功修为不够，难以施展" BEI "。\n");
  # 
  #         if ((int)me->query("max_neili") < 3500)
  #                 return notify_fail("你内力修为不够，难以施展" BEI "。\n");
  # 
  #         if ((int)me->query_skill("dabei-zhang", 1) < 220)
  #                 return notify_fail("你大悲神掌火候不够，难以施展" BEI "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "dabei-zhang")
  #                 return notify_fail("你没有激发大悲神掌，难以施展" BEI "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "dabei-zhang")
  #                 return notify_fail("你没有准备大悲神掌，难以施展" BEI "。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你现在真气不够，难以施展" BEI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "凄然一声长啸，施出「" HIG "万里鲸涛大悲神诀"
  #               HIW "」，双掌翻滚出漫天掌影，尽数拍向$n" HIW "。\n" NOR;
  # 
  #         ap = me->query_skill("strike") + me->query("int") * 10;
  #         dp = target->query_skill("force") + target->query("int") * 10;
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 2);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 200,
  #                                            HIR "$n" HIR "勘破不透掌中虚实，$N" HIR
  #                                            "双掌正中$p" HIR "前胸，“喀嚓喀嚓”接"
  #                                            "连断了数根肋骨。\n" NOR);
  #             message_combatd(msg, me, target);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "见$N" CYN "这掌来势非凡，不敢"
  #                        "轻易招架，当即飞身纵跃闪开。\n" NOR;
  #             message_combatd(msg, me, target);
  #         }
  # 
  #         for (i = 0; i < 4; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (random(3) == 1 && ! target->is_busy())
  #                         target->start_busy(1);
  #             COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  #         me->add("neili", -300);
  #         me->start_busy(4 + random(3));
  #         return 1;
  # }
end
