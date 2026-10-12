defmodule Kantele.Combat.Skills.Performs.DragonStrike.Hui do
  @moduledoc """
  perform「亢龙有悔」（source dragon-strike/hui.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 空手 → 内功>=360 →
  内力上限>=5000 → 降龙十八掌>=240 → 激发 strike 为降龙十八掌 → 准备降龙十八掌 →
  真气>=1000 → 目标存活。

  三掌连击（`ap = strike + str*5` 恒定），各掌目标防御不同：
  - 第一掌 `dp = dodge + dex*5`，命中 `damage = ap + random(ap/2)`、创伤 40%；
  - 第二掌 `dp = parry + int*5`，命中同上、创伤 50%；
  - 第三掌 `dp = force + con*5`，命中同上、创伤 60%；收掌后攻击方忙乱 `3+random(4)`、
    扣 `400 + random(600)` 真气。

  差异（TODO(migrate)）：
  - 起手广播与命中判定依赖目标 `dodge/parry/force` 与 `dex/int/con`，故三掌整体在
    目标侧 `resolve_incoming/4` 完成；攻击方忙乱/扣气经 `combat/perform-feedback` 回执；
  - `do_damage(..., UNARMED_ATTACK, damage, 40/50/60, ...)` 折算为
    `Vitals.damage(:qi, damage)` / `Vitals.wound(:qi, div(damage * pct, 100))`；
  - `.c` 的起手文案被 `「" + "亢龙有悔" + "」` 拆为三段字面量，此处按原样拆为三段、
    运行时再合一（第一、二掌共用的失手文案按 .c 出现两次分别写出）；
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

  @perform_id "dragon-strike/hui"
  @move_name "「亢龙有悔」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    level = Stats.skill(stats, "dragon-strike")
    # LPC: ap = me->query_skill("strike") + me->query("str") * 5;
    ap = Stats.skill(stats, "strike") + stats.str * 5

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(character),
         :ok <- check_gates(character),
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

      # 三掌的广播与伤害结算均在目标侧完成（dp 依赖目标 dodge/parry/force 与 dex/int/con）。
      assign(conn, :prompt, false)
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

  # LPC 顺序：force < 360 → max_neili < 5000 → dragon-strike < 240 →
  #           mapped("strike") != dragon-strike → prepared("strike") != dragon-strike → neili < 1000
  defp check_gates(character) do
    stats = character.meta.stats
    vitals = character.meta.vitals

    cond do
      Stats.skill(stats, "force") < 360 ->
        {:error, "你内功修为不够，难以施展#{@move_name}。\n"}

      vitals.max_neili < 5000 ->
        {:error, "你内力修为不够，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "dragon-strike") < 240 ->
        {:error, "你降龙十八掌火候不够，难以施展#{@move_name}。\n"}

      Stats.mapped(stats, "strike") != "dragon-strike" ->
        {:error, "你没有激发降龙十八掌，难以施展#{@move_name}。\n"}

      not prepared?(stats) ->
        {:error, "你没有准备降龙十八掌，难以施展#{@move_name}。\n"}

      vitals.neili < 1000 ->
        {:error, "你现在真气不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  defp prepared?(stats) do
    case Stats.prepared_perform(stats, "strike") do
      nil -> false
      value -> String.split(value, "/") |> hd() == "dragon-strike"
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
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # ===== 第一掌：dp = target->query_skill("dodge") + target->query("dex") * 5；创伤 40% =====
    msg1 =
      [
        "\n忽然间$N身形激进，左手一划，右手呼的一掌，便向$n击去，正是降龙十八掌「",
        "亢龙有悔",
        "」一招，力自掌生之际说到便到，以排山倒海之势向$n狂涌而去，当真石破天惊，威力无比。\n"
      ]
      |> Enum.join("")

    conn = Broadcast.publish(conn, Messages.interpolate(msg1, bindings))

    {conn, dmg1, wnd1} =
      if div(ap, 2) + Engine.rand(rng, ap) > Stats.skill(stats, "dodge") + stats.dex * 5 do
        damage = ap + Engine.rand(rng, max(div(ap, 2), 1))

        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate(
              "$p一楞，只见$P身形一闪，已晃至自己跟前，躲闪不及，被击个正中。\n:内伤@?",
              bindings
            )
          )

        {conn, damage, div(damage * 40, 100)}
      else
        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate(
              "$p气贯双臂，凝神应对，游刃有余，$P掌力如泥牛入海，尽数卸去。\n",
              bindings
            )
          )

        {conn, 0, 0}
      end

    # ===== 第二掌：dp = target->query_skill("parry") + target->query("int") * 5；创伤 50% =====
    msg2 =
      [
        "\n$N一掌既出，身子已然抢到离$n三四丈之外，后掌推前掌，两股掌力道合并，又是一招「",
        "亢龙有悔",
        "」攻出，掌力犹如怒潮狂涌，势不可当。霎时$n便觉气息窒滞，立足不稳。\n"
      ]
      |> Enum.join("")

    conn = Broadcast.publish(conn, Messages.interpolate(msg2, bindings))

    {conn, dmg2, wnd2} =
      if div(ap, 2) + Engine.rand(rng, ap) > Stats.skill(stats, "parry") + stats.int * 5 do
        damage = ap + Engine.rand(rng, max(div(ap, 2), 1))

        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate(
              "只听$p一声惨嚎，被$P一掌击中胸前，“喀嚓喀嚓”断了几根肋骨。\n:内伤@?",
              bindings
            )
          )

        {conn, damage, div(damage * 50, 100)}
      else
        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate(
              "$p气贯双臂，凝神应对，游刃有余，$P掌力如泥牛入海，尽数卸去。\n",
              bindings
            )
          )

        {conn, 0, 0}
      end

    # ===== 第三掌：dp = target->query_skill("force") + target->query("con") * 5；创伤 60% =====
    msg3 =
      [
        "\n紧跟着$N一声暴喝，右掌斜斜挥出，前招掌力未消，此招掌力又到，竟然又攻出一招「",
        "亢龙有悔",
        "」，掌夹风势，势如破竹，便如一堵无形气墙，向前疾冲而去。$n只觉气血翻涌，气息沉浊。\n"
      ]
      |> Enum.join("")

    conn = Broadcast.publish(conn, Messages.interpolate(msg3, bindings))

    {conn, dmg3, wnd3} =
      if div(ap, 2) + Engine.rand(rng, ap) > Stats.skill(stats, "force") + stats.con * 5 do
        damage = ap + Engine.rand(rng, max(div(ap, 2), 1))

        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate(
              "结果$p躲闪不及，$P的掌劲顿时穿胸而过，“哇”的喷出一大口鲜血。\n:内伤@?",
              bindings
            )
          )

        {conn, damage, div(damage * 60, 100)}
      else
        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate(
              "$p见这招来势凶猛，身形疾退，瞬间飘出三丈，脱出$P掌力之外。\n",
              bindings
            )
          )

        {conn, 0, 0}
      end

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, dmg1 + dmg2 + dmg3)
      |> Vitals.wound(:qi, wnd1 + wnd2 + wnd3)

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: me->start_busy(3 + random(4)); me->add("neili", -400 - random(600));
    Performs.feedback(attacker, 400 + Engine.rand(rng, 600), 3 + Engine.rand(rng, 4))

    put_character(conn, character)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define HUI "「" HIR "亢龙有悔" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/dragon-strike/hui"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(HUI "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(HUI "只能空手使用。\n");
  # 
  #         if ((int)me->query_skill("force") < 360)
  #                 return notify_fail("你内功修为不够，难以施展" HUI "。\n");
  # 
  #         if ((int)me->query("max_neili") < 5000)
  #                 return notify_fail("你内力修为不够，难以施展" HUI "。\n");
  # 
  #         if ((int)me->query_skill("dragon-strike", 1) < 240)
  #                 return notify_fail("你降龙十八掌火候不够，难以施展" HUI "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "dragon-strike")
  #                 return notify_fail("你没有激发降龙十八掌，难以施展" HUI "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "dragon-strike")
  #                 return notify_fail("你没有准备降龙十八掌，难以施展" HUI "。\n");
  # 
  #         if ((int)me->query("neili") < 1000)
  #                 return notify_fail("你现在真气不够，难以施展" HUI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         // 第一掌
  #         ap = me->query_skill("strike") + me->query("str") * 5;
  #         dp = target->query_skill("dodge") + target->query("dex") * 5;
  # 
  #         message_sort(HIW "\n忽然间$N" HIW "身形激进，左手一划，右手呼的一掌，便"
  #                      "向$n" HIW "击去，正是降龙十八掌「" NOR + HIY "亢龙有悔" NOR
  #                      + HIW "」一招，力自掌生之际说到便到，以排山倒海之势向$n" HIW
  #                      "狂涌而去，当真石破天惊，威力无比。\n" NOR, me, target);
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 2);
  #                 msg = COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 40,
  #                                           HIR "$p" HIR "一楞，只见$P" HIR "身形"
  #                                           "一闪，已晃至自己跟前，躲闪不及，被击"
  #                                           "个正中。\n:内伤@?");
  # 
  #                 message_vision(msg, me, target);
  # 
  #         } else
  #         {
  #                 msg = HIC "$p" HIC "气贯双臂，凝神应对，游刃有余，$P"
  #                       HIC "掌力如泥牛入海，尽数卸去。\n" NOR;
  #                 message_vision(msg, me, target);
  #         }
  # 
  #         // 第二掌
  #         ap = me->query_skill("strike") + me->query("str") * 5;
  #         dp = target->query_skill("parry") + target->query("int") * 5;
  # 
  #         message_sort(HIW "\n$N" HIW "一掌既出，身子已然抢到离$n" HIW "三四丈之外"
  #                      "，后掌推前掌，两股掌力道合并，又是一招「" NOR + HIY "亢龙有"
  #                      "悔" NOR + HIW "」攻出，掌力犹如怒潮狂涌，势不可当。霎时$n"
  #                      HIW "便觉气息窒滞，立足不稳。\n" NOR, me, target);
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 2);
  #                 msg = COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 50,
  #                                            HIR "只听$p" HIR "一声惨嚎，被$P" HIR
  #                                            "一掌击中胸前，“喀嚓喀嚓”断了几根肋"
  #                                            "骨。\n:内伤@?");
  # 
  #                 message_vision(msg, me, target);
  #         } else
  #         {
  #                 msg = HIC "$p" HIC "气贯双臂，凝神应对，游刃有余，$P"
  #                       HIC "掌力如泥牛入海，尽数卸去。\n" NOR;
  #                 message_vision(msg, me, target);
  #         }
  # 
  #         // 第三掌
  #         ap = me->query_skill("strike") + me->query("str") * 5;
  #         dp = target->query_skill("force") + target->query("con") * 5;
  # 
  #         message_sort(HIW "\n紧跟着$N" HIW "一声暴喝，右掌斜斜挥出，前招掌力未消"
  #                      "，此招掌力又到，竟然又攻出一招「" NOR + HIY "亢龙有悔" NOR
  #                      + HIW "」，掌夹风势，势如破竹，便如一堵无形气墙，向前疾冲而"
  #                      "去。$n" HIW "只觉气血翻涌，气息沉浊。\n" NOR, me, target);
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 2);
  #                 msg = COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60,
  #                                            HIR "结果$p" HIR "躲闪不及，$P" HIR
  #                                            "的掌劲顿时穿胸而过，“哇”的喷出一大"
  #                                            "口鲜血。\n:内伤@?");
  # 
  #                 message_vision(msg, me, target);
  #                 me->start_busy(3 + random(4));
  #                 me->add("neili", -400 - random(600));
  #                 return 1;
  #         } else
  #         {
  #                 msg = HIC "$p" HIC "见这招来势凶猛，身形疾退，瞬间飘出三"
  #                       "丈，脱出$P" HIC "掌力之外。\n" NOR;
  #                 message_vision(msg, me, target);
  #                 me->start_busy(3 + random(4));
  #                 me->add("neili", -400 - random(600));
  #                 return 1;
  #         }
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
