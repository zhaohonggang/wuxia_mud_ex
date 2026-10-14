defmodule Kantele.Combat.Skills.Performs.MiaojiaJian.Zhai do
  @moduledoc """
  perform「云边摘月」（对照 `kungfu/skill/miaojia-jian/zhai.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 手持 sword 类武器 →
  **目标不忙乱** → 苗家剑法>=100 → 内功>=120 → 内力上限>=800 → 真气>=100 →
  激发 `sword` 为苗家剑法 → 目标存活。
  起手文案在攻击方广播；命中判定 `random(苗家剑法) > 目标 parry/2` 在目标侧结算：
  命中则目标忙乱 `苗家剑法/18 + 2`；未命中则攻击方忙乱 2；两种情况攻击方均扣 30 真气。

  差异（TODO(migrate)）：
  - **目标忙乱门槛**（`target->is_busy()`）在攻击方不可得（`combat.enemies` 仅存
    `%{id,pid,name,room_id}` 快照），故移到目标侧 `resolve_incoming` 判定
    （同 `liuyun_zhang/die.ex`）；`.c` 中该门槛先于攻击方熟练度门槛，此处次序相反；
  - `me->add("neili", -30)` 在 `.c` 里位于目标忙乱门槛之后、命中分支之外（无条件），
    因门槛移到目标侧，该消耗一并随门槛在目标侧结算，经 `Performs.feedback/3` 回执
    （命中 `busy: 0` 不改忙乱，未命中 `busy: 2`）；
  - `.c` 把起手与分支文案累积到 `msg` 后一次 `message_combatd`；此处按引擎惯例拆分
    （起手在攻击方广播，分支在目标侧广播，同 `guzhuo_zhang/yu.ex`）；
  - `!living(target)` 门槛在攻击方恒判存活（无 meta 可查），其文案放在攻击方
    `check_target_alive/1`，由目标侧死亡检查兜底（`resolve_incoming` 的 dead 分支不重复文案）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs

  @perform_id "miaojia-jian/zhai"
  @move_name "「云边摘月」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    # LPC: if ((level = me->query_skill("miaojia-jian", 1)) < 100)
    lvl = Stats.skill(stats, "miaojia-jian")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(stats),
         :ok <- check_max_neili(character),
         :ok <- check_neili(character),
         :ok <- check_mapped(stats),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
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

  # LPC: if (userp(me) && ! me->query("can_perform/miaojia-jian/zhai"))
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

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #          (string)weapon->query("skill_type") != "sword")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      :ok
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((level = me->query_skill("miaojia-jian", 1)) < 100)
  #      if ((int)me->query_skill("force") < 120)
  defp check_levels(stats) do
    cond do
      Stats.skill(stats, "miaojia-jian") < 100 ->
        {:error, "你苗家剑法不够娴熟，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "force") < 120 ->
        {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if ((int)me->query("max_neili") < 800)
  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 800 do
      {:error, "你的内力修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 100)
  defp check_neili(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "miaojia-jian")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") != "miaojia-jian" do
      {:error, "你没有激发苗家剑法，难以施展#{@move_name}。\n"}
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

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIW "$N" HIW "一声清哮，剑势舒张，吞吐不定，瞬间向$n" HIW "连刺"
    #            "数剑，企图扰乱$n" HIW "的攻势。\n" NOR;（合并为单段）
    Broadcast.publish(
      conn,
      "$N一声清哮，剑势舒张，吞吐不定，瞬间向$n连刺数剑，企图扰乱$n的攻势。\n",
      n1: character.name,
      n2: target.name
    )
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  # LPC: if (target->is_busy()) return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 目标忙乱状态只在目标侧可见，故死亡/忙乱门槛在 resolve_incoming 结算（同 liuyun_zhang/die.ex）。
  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    cond do
      character.meta.combat.dead ->
        conn

      Combat.busy?(character.meta.combat) ->
        Broadcast.publish(conn, "$n目前正自顾不暇，放胆攻击吧。\n",
          n1: attacker.name,
          n2: character.name
        )

      true ->
        do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]
    level = max(Map.get(data, :level, 0), 0)

    # LPC: me->add("neili", -30);
    #      if (random(level) > (int)target->query_skill("parry", 1) / 2)
    #      { msg += "结果$p只见$P剑招精妙…攻势登时一紧！\n"; target->start_busy(level / 18 + 2); }
    #      else { msg += "可是$p看破了$P剑势的来路…丝毫不为所动。\n"; me->start_busy(2); }
    if Engine.rand(rng, level) > div(Stats.skill(stats, "parry"), 2) do
      # LPC: target->start_busy(level / 18 + 2);
      combat = Combat.start_busy(character.meta.combat, div(level, 18) + 2)
      character = %{character | meta: %{character.meta | combat: combat}}
      Performs.feedback(attacker, 30, 0)

      conn
      |> Broadcast.publish("结果$p只见$P剑招精妙，全然辨不清招中虚实，攻势登时一紧！\n", bindings)
      |> put_character(character)
    else
      # LPC: me->start_busy(2);
      Performs.feedback(attacker, 30, 2)

      Broadcast.publish(conn, "可是$p看破了$P剑势的来路，径自出招，丝毫不为所动。\n", bindings)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHAI "「" HIW "云边摘月" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     int level;
  #     string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/miaojia-jian/zhai"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHAI "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" ZHAI "。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #         if ((level = me->query_skill("miaojia-jian", 1)) < 100)
  #                 return notify_fail("你苗家剑法不够娴熟，难以施展" ZHAI "。\n");
  # 
  #         if ((int)me->query_skill("force") < 120)
  #                 return notify_fail("你的内功火候不够，难以施展" ZHAI "。\n");
  # 
  #         if ((int)me->query("max_neili") < 800)
  #                 return notify_fail("你的内力修为不够，难以施展" ZHAI "。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你现在真气不够，难以施展" ZHAI "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "miaojia-jian")
  #                 return notify_fail("你没有激发苗家剑法，难以施展" ZHAI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIW "$N" HIW "一声清哮，剑势舒张，吞吐不定，瞬间向$n" HIW "连刺"
  #               "数剑，企图扰乱$n" HIW "的攻势。\n" NOR;
  # 
  #         me->add("neili", -30);
  #         if (random(level) > (int)target->query_skill("parry", 1) / 2)
  #         {
  #         msg += HIR "结果$p" HIR "只见$P" HIR "剑招精妙，全然"
  #                        "辨不清招中虚实，攻势登时一紧！\n" NOR;
  #                 target->start_busy(level / 18 + 2);
  #     } else
  #         {
  #         msg += CYN "可是$p" CYN "看破了$P" CYN "剑势的来路，"
  #                        "径自出招，丝毫不为所动。\n" NOR;
  #         me->start_busy(2);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
