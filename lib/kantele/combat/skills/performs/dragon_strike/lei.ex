defmodule Kantele.Combat.Skills.Performs.DragonStrike.Lei do
  @moduledoc """
  perform「雷霆一击」（source dragon-strike/lei.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 空手 → 内功>=250 →
  内力上限>=2500 → 降龙十八掌>=180 → 激发 strike 为降龙十八掌 → 准备降龙十八掌 →
  真气>=600 → 目标存活。
  攻击方忙乱 3，并广播起手式后以 `ap = strike + str*10`、目标 `dp = dodge + dex*10`
  判定 `ap/2 + random(ap) > dp`：命中则 `damage = ap + random(ap/2)`、按 70% 计
  qi 伤，并扣 400 真气；未命中则仅落空文案。

  差异（TODO(migrate)）：
  - `do_damage(..., UNARMED_ATTACK, damage, 70, ...)` 折算为
    `Vitals.damage(:qi, damage)` / `Vitals.wound(:qi, div(damage * 70, 100))`；
  - `.c` 的起手广播被 `LEI` 宏与 `+` 拆为两段字面量，此处按原样拆为两段、运行时再合一；
  - `me->start_busy(3)` 无条件在攻击方进程生效；命中扣 400 真气经
    `combat/perform-feedback` 回执补扣（攻击方与目标分处两进程）；
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

  @perform_id "dragon-strike/lei"
  @move_name "「雷霆一击」"

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
         :ok <- check_levels(stats),
         :ok <- check_mapped(stats),
         :ok <- check_prepared(stats),
         :ok <- check_resources(character),
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

  # LPC: if (query_skill("force",1) < 250)          ... "你内功修为不够，难以施展" LEI "。\n"
  #         (query_skill("dragon-strike",1) < 180) ... "你降龙十八掌火候不够，难以施展" LEI "。\n"
  defp check_levels(stats) do
    cond do
      Stats.skill(stats, "force") < 250 ->
        {:error, "你内功修为不够，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "dragon-strike") < 180 ->
        {:error, "你降龙十八掌火候不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "dragon-strike")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "strike") == "dragon-strike" do
      :ok
    else
      {:error, "你没有激发降龙十八掌，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "dragon-strike")
  defp check_prepared(stats) do
    case Stats.prepared_perform(stats, "strike") do
      nil ->
        {:error, "你没有准备降龙十八掌，难以施展#{@move_name}。\n"}

      value ->
        if String.split(value, "/") |> hd() == "dragon-strike" do
          :ok
        else
          {:error, "你没有准备降龙十八掌，难以施展#{@move_name}。\n"}
        end
    end
  end

  # LPC: if (query("max_neili") < 2500) ... "你内力修为不够，难以施展" LEI "。\n"
  #         (query("neili") < 600)      ... "你现在真气不够，难以施展" LEI "。\n"
  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 2500 -> {:error, "你内力修为不够，难以施展#{@move_name}。\n"}
      vitals.neili < 600 -> {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
      true -> :ok
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
    # LPC: msg = HIC "$N" HIC "默运内功，施展出" LEI + HIC "，全身急速转动起来，"
    #            "越来越快，就\n犹如一股旋风，骤然间，$N" HIC "已卷向正看"
    #            "得发呆的" HIC "$n。\n" NOR;
    #      message_combatd(msg, me, target);
    #      me->start_busy(3);
    # `LEI` 宏与 `+` 把起手广播拆为两段字面量，此处按原样拆开、运行时再合一。
    combat = Combat.start_busy(character.meta.combat, 3)
    character = %{character | meta: %{character.meta | combat: combat}}

    msg =
      [
        "$N默运内功，施展出#{@move_name}",
        "，全身急速转动起来，越来越快，就\n犹如一股旋风，骤然间，$N已卷向正看得发呆的$n。\n"
      ]
      |> Enum.join("")

    conn
    |> Broadcast.publish(msg, n1: character.name, n2: target.name)
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

    # LPC: dp = target->query_skill("dodge") + target->query("dex") * 10;
    dp = Stats.skill(stats, "dodge") + stats.dex * 10

    # LPC: if (ap / 2 + random(ap) > dp) { damage = ap + random(ap / 2); me->add("neili", -400); ... }
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      damage = ap + Engine.rand(rng, max(div(ap, 2), 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 70, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: me->add("neili", -400);
      Performs.feedback(attacker, 400, 0)

      # LPC: do_damage(..., UNARMED_ATTACK, damage, 70, HIR "$p只见一阵旋风影中陡然现出$P
      #           的双拳，根本来不及躲避，被重重击中，\n五脏六腑翻腾不休，口中鲜血如箭般喷出！\n" NOR);
      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "$p只见一阵旋风影中陡然现出$P的双拳，根本来不及躲避，被重重击中，\n五脏六腑翻腾不休，口中鲜血如箭般喷出！\n",
          bindings
        )
      )
      |> put_character(character)
    else
      # LPC: msg += HIG "可是$p" HIG "看破了$P" HIG "的企图，没有受到迷惑，闪在了一边。\n" NOR;
      conn
      |> Broadcast.publish(
        Messages.interpolate("可是$p看破了$P的企图，没有受到迷惑，闪在了一边。\n", bindings)
      )
    end
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define LEI "「" HIY "雷霆一击" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/dragon-strike/lei"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(LEI "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(LEI "只能空手使用。\n");
  # 
  #         if ((int)me->query_skill("force") < 250)
  #                 return notify_fail("你内功修为不够，难以施展" LEI "。\n");
  # 
  #         if ((int)me->query("max_neili") < 2500)
  #                 return notify_fail("你内力修为不够，难以施展" LEI "。\n");
  # 
  #         if ((int)me->query_skill("dragon-strike", 1) < 180)
  #                 return notify_fail("你降龙十八掌火候不够，难以施展" LEI "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "dragon-strike")
  #                 return notify_fail("你没有激发降龙十八掌，难以施展" LEI "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "dragon-strike")
  #                 return notify_fail("你没有准备降龙十八掌，难以施展" LEI "。\n");
  # 
  #         if ((int)me->query("neili") < 600)
  #                 return notify_fail("你现在真气不够，难以施展" LEI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIC "$N" HIC "默运内功，施展出" LEI + HIC "，全身急速转动起来，"
  #               "越来越快，就\n犹如一股旋风，骤然间，$N" HIC "已卷向正看"
  #               "得发呆的" HIC "$n。\n"NOR;  
  # 
  #         ap = me->query_skill("strike") + me->query("str") * 10;
  #         dp = target->query_skill("dodge") + target->query("dex") * 10;
  #         me->start_busy(3);
  #         if (ap / 2 + random(ap) > dp)
  #         { 
  #                 damage = ap + random(ap / 2);
  #                 me->add("neili", -400);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70,
  #                                            HIR "$p" HIR "只见一阵旋风影中陡然现出$P"
  #                                            HIR "的双拳，根本来不及躲避，被重重击中，\n五"
  #                                            "脏六腑翻腾不休，口中鲜血如箭般喷出！\n" NOR);
  #         } else
  #         {
  #                 msg += HIG "可是$p" HIG "看破了$P" HIG "的企图，没"
  #                        "有受到迷惑，闪在了一边。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
