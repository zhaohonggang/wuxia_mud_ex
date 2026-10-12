defmodule Kantele.Combat.Skills.Performs.DragonStrike.Xiang do
  @moduledoc """
  perform「龙翔九天」（source dragon-strike/xiang.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：目标在战斗中 → 空手 → 内力上限>=2000 → 真气>=500 →
  体力>=800 → 降龙十八掌>=150 → 内功>=300 → 准备降龙十八掌 → 目标存活。
  起手广播后以 `ap = strike + str*10`、目标 `dp = parry + dex*6` 判定
  `ap/2 + random(ap) > dp`：命中则 `count = ap/9`、连击 6 次
  （每击 40% 概率令未忙乱的目标忙乱 1 回合）；攻击方扣 300 真气、100 体力
  并忙乱 `1 + random(5)`。

  差异（TODO(migrate)）：
  - LPC 的 6 次 `COMBAT_D->do_attack(me, target, 0, 0)`（完整 AP/DP/招架/伤害管线）
    折算为每击 `level/15` 基础伤害 + 命中判定 `level/2 + count`（`count = ap/9`）
    vs 目标 dodge（同 duanjia-jian/lian）；
  - `me->add_temp("apply/attack", ±count)` 的临时命中加成并入连击命中判定；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧 `combat/perform-incoming`
    的死亡检查兜底。
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

  @perform_id "dragon-strike/xiang"
  @move_name "「龙翔九天」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    level = Stats.skill(stats, "dragon-strike")
    # LPC: ap = me->query_skill("strike") + me->query("str") * 10;
    ap = Stats.skill(stats, "strike") + stats.str * 10

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(character),
         :ok <- check_resources(character),
         :ok <- check_levels(stats),
         :ok <- check_prepared(stats),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: level,
          skill: level,
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
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
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

  # LPC: if (query("max_neili") < 2000) ... "你的内力修为还不够，无法施展「龙翔九天」。\n"
  #         (query("neili") < 500)     ... "你的真气不够！\n"
  #         (query("qi") < 800)        ... "你的体力现在不够！\n"
  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 2000 -> {:error, "你的内力修为还不够，无法施展#{@move_name}。\n"}
      vitals.neili < 500 -> {:error, "你的真气不够！\n"}
      vitals.qi < 800 -> {:error, "你的体力现在不够！\n"}
      true -> :ok
    end
  end

  # LPC: if (query_skill("dragon-strike",1) < 150) ... "你的降龙十八掌火候不够，无法使用「龙翔九天」！\n"
  #         (query_skill("force") < 300)           ... "你的内功修为不够，无法使用「龙翔九天」！\n"
  defp check_levels(stats) do
    cond do
      Stats.skill(stats, "dragon-strike") < 150 ->
        {:error, "你的降龙十八掌火候不够，无法使用#{@move_name}！\n"}

      Stats.skill(stats, "force") < 300 ->
        {:error, "你的内功修为不够，无法使用#{@move_name}！\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "dragon-strike")
  defp check_prepared(stats) do
    case Stats.prepared_perform(stats, "strike") do
      nil ->
        {:error, "你现在没有准备使用降龙十八掌，无法使用#{@move_name}！\n"}

      value ->
        if String.split(value, "/") |> hd() == "dragon-strike" do
          :ok
        else
          {:error, "你现在没有准备使用降龙十八掌，无法使用#{@move_name}！\n"}
        end
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

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIY "$N" HIY "深吸一口气，跨前一步，双掌猛然翻滚，缤纷而出，"
    #            "宛如一条神龙攀蜒于九天之上！\n\n" NOR;
    #      message_vision(msg, me, target);
    #      me->add("neili", -300); me->add("qi", -100);
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 300, qi: vitals.qi - 100}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn
    |> Broadcast.publish(
      "$N深吸一口气，跨前一步，双掌猛然翻滚，缤纷而出，宛如一条神龙攀蜒于九天之上！\n\n",
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
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    level = max(Map.get(data, :level, 0), 1)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("parry") + target->query("dex") * 6;
    dp = Stats.skill(stats, "parry") + stats.dex * 6

    # LPC: if (ap / 2 + random(ap) > dp) { count = ap / 9; ... } else { count = 0; ... }
    landed = div(ap, 2) + Engine.rand(rng, ap) > dp
    count = if landed, do: div(ap, 9), else: 0

    # LPC: for (i = 0; i < 6; i++) { if (! me->is_fighting(target)) break;
    #        if (random(5) < 2 && ! target->is_busy()) target->start_busy(1);
    #        COMBAT_D->do_attack(me, target, 0, 0); }
    # 折算：每击 level/15 基础伤害 + 命中判定（apply/attack 的 count 加成并入）。
    dodge = Stats.skill(stats, "dodge")
    per_hit = max(div(level, 15), 1)
    hit_ap = div(level, 2) + count

    {damage, combat} =
      Enum.reduce(1..6, {0, character.meta.combat}, fn _, {damage_acc, combat_acc} ->
        # if (random(5) < 2 && ! target->is_busy()) target->start_busy(1);
        combat_acc =
          if Engine.rand(rng, 5) < 2 and combat_acc.busy == 0 do
            Combat.start_busy(combat_acc, 1)
          else
            combat_acc
          end

        if hit_ap + Engine.rand(rng, level) > dodge do
          {damage_acc + per_hit + Engine.rand(rng, per_hit), combat_acc}
        else
          {damage_acc, combat_acc}
        end
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    # LPC: me->start_busy(1 + random(5));
    Performs.feedback(attacker, 0, 1 + Engine.rand(rng, 5))

    msg =
      if landed do
        "$n面对$P这排山倒海攻势，完全无法抵挡，唯有退后。\n"
      else
        "$n凝神应战，竭尽所能化解$P这几掌。\n"
      end

    conn
    |> Broadcast.publish(Messages.interpolate(msg, bindings))
    |> put_character(character)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // xiang.c 龙翔九天
  # 
  # #include <ansi.h>
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
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("「龙翔九天」只能在战斗中对对手使用。\n");
  #  
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail("「龙翔九天」只能空手使用。\n");
  #                 
  #         if (me->query("max_neili") < 2000)
  #                 return notify_fail("你的内力修为还不够，无法施展「龙翔九天」。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你的真气不够！\n");
  # 
  #         if ((int)me->query("qi") < 800)
  #                 return notify_fail("你的体力现在不够！\n");
  # 
  #         if ((int)me->query_skill("dragon-strike", 1) < 150)
  #                 return notify_fail("你的降龙十八掌火候不够，无法使用「龙翔九天」！\n");
  # 
  #         if ((int)me->query_skill("force") < 300)
  #                 return notify_fail("你的内功修为不够，无法使用「龙翔九天」！\n");
  # 
  #         if (me->query_skill_prepared("strike") != "dragon-strike")
  #                 return notify_fail("你现在没有准备使用降龙十八掌，无法使用「龙翔九天」！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "深吸一口气，跨前一步，双掌猛然翻滚，"
  #               "缤纷而出，宛如一条神龙攀蜒于九天之上！\n\n" NOR;
  #         ap = me->query_skill("strike") + me->query("str") * 10;
  #         dp = target->query_skill("parry") + target->query("dex") * 6;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 count = ap / 9;
  #                 msg += HIR "$n" HIR "面对$P" HIR "这排山倒海攻势，完全"
  #                        "无法抵挡，唯有退后。\n" NOR;
  #         } else
  #         {
  #                 msg += HIC "$n" HIC "凝神应战，竭尽所能化解$P" HIC
  #                        "这几掌。\n" NOR;
  #                 count = 0;
  #         }
  # 
  #         message_vision(msg, me, target);
  #         me->add_temp("apply/attack", count);
  # 
  #         me->add("neili", -300);
  #         me->add("qi", -100);    // Why I don't use receive_damage ?
  #                                 // Becuase now I was use it as a cost
  #         for (i = 0; i < 6; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (random(5) < 2 && ! target->is_busy())
  #                         target->start_busy(1);
  # 
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  # 
  #         me->start_busy(1 + random(5));
  #         me->add_temp("apply/attack", -count);
  # 
  #         return 1;
  # }
end
