defmodule Kantele.Combat.Skills.Performs.NeverDefeated.Tianhua do
  @moduledoc """
  perform「天花乱坠」（对照 `kungfu/skill/never-defeated/perform/tianhua.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 手持兵刃 → **目标不忙乱** →
  不败神功>=100 → 目标存活。
  起手文案（含武器名 `weapon->name()`）在攻击方广播（无真气消耗）。
  目标侧以 `ap/2 + random(ap)`（`ap = 不败神功*3/2 + 武学修养`）对目标
  `parry + 武学修养`：命中则目标忙乱 `ap/45 + 2`；未命中则攻击方忙乱 1。

  差异（TODO(migrate)）：
  - `.c` 未列「是否已学此招」门槛（`can_perform`），本引擎以框架层
    `perform_known?/2` 统一把关（多出的文案不影响对齐）；
  - **目标忙乱门槛**（`target->is_busy()`）在攻击方不可得（`combat.enemies` 仅存
    `%{id,pid,name,room_id}` 快照），故移到目标侧 `resolve_incoming` 判定
    （同 `liuyun_zhang/die.ex`、`miaojia_jian/zhai.ex`）；
    其文案为 `target->name() + "目前正自顾不暇，放胆攻击吧！"` → E 侧
    `"$n目前正自顾不暇，放胆攻击吧！"`（`$n` 绑定目标名，`!` 为全角）；
  - `.c` 把起手与分支文案累积到 `msg` 后一次 `message_combatd`；此处按引擎惯例拆分
    （起手在攻击方 `apply_effect` 广播，分支在目标侧广播，同 `guzhuo_zhang/yu.ex`）；
  - 未命中分支的 `me->start_busy(1)` 经 `Performs.feedback/3` 回执；
  - `!living(target)` 门槛在攻击方无 meta 可查，恒判存活，由目标侧
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
  alias Kantele.Combat.Performs

  @perform_id "never-defeated/tianhua"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "never-defeated")
    wn = weapon_name(combat)

    # LPC: ap = me->query_skill("never-defeated", 1) * 3 / 2 +
    #             me->query_skill("martial-cognize", 1);
    ap = div(Stats.skill(stats, "never-defeated") * 3, 2) + Stats.skill(stats, "martial-cognize")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_level(stats),
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

      apply_effect(conn, character, target, wn)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: 本式无 can_perform 门槛，框架层统一把关（见 moduledoc 差异说明）。
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "天花乱坠只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")))
  defp check_weapon(combat) do
    if Combat.weapon(combat) do
      :ok
    else
      {:error, "你必须手持兵刃才能施展天花乱坠！\n"}
    end
  end

  # LPC: if ((int)me->query_skill("never-defeated", 1) < 100)
  defp check_level(stats) do
    if Stats.skill(stats, "never-defeated") < 100 do
      {:error, "你的不败神功不够深厚，不会使用天花乱坠。\n"}
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

  defp apply_effect(conn, character, target, wn) do
    # LPC: msg = HIC "$N" HIC "手中的" + weapon->name() + HIC
    #            "一勾一划，简单明了的压向$n" HIC "！\n" NOR;（合并为单段）
    conn =
      Broadcast.publish(
        conn,
        "$N手中的" <> wn <> "一勾一划，简单明了的压向$n！\n",
        n1: character.name,
        n2: target.name
      )

    conn
    |> assign(:prompt, false)
  end

  defp weapon_name(combat) do
    case Combat.weapon(combat) do
      nil -> nil
      weapon -> Map.get(weapon, :name)
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  # LPC: if (target->is_busy())
  #      return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
  # 目标忙乱状态只在目标侧可见，故死亡/忙乱门槛在 resolve_incoming 结算。
  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    cond do
      character.meta.combat.dead ->
        conn

      Combat.busy?(character.meta.combat) ->
        Broadcast.publish(conn, "$n目前正自顾不暇，放胆攻击吧！", n1: attacker.name, n2: character.name)

      true ->
        do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]
    ap = max(Map.get(data, :ap, 0), 1)

    # LPC: dp = target->query_skill("parry") + target->query_skill("martial-cognize", 1);
    dp = Stats.skill(stats, "parry") + Stats.skill(stats, "martial-cognize")

    # LPC: if (ap / 2 + random(ap) > dp)
    #      { msg += "结果$p被$P逼得施展不开半点招式！\n"; target->start_busy(ap / 45 + 2); }
    #      else { msg += "可是$p看破了$P的招数，镇定自若，应对自如。\n"; me->start_busy(1); }
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: target->start_busy(ap / 45 + 2);
      combat = Combat.start_busy(character.meta.combat, div(ap, 45) + 2)
      character = %{character | meta: %{character.meta | combat: combat}}

      conn
      |> Broadcast.publish("结果$p被$P逼得施展不开半点招式！\n", bindings)
      |> put_character(character)
    else
      # LPC: me->start_busy(1);
      Performs.feedback(attacker, 0, 1)

      Broadcast.publish(conn, "可是$p看破了$P的招数，镇定自若，应对自如。\n", bindings)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // tianhua.c 天花乱坠
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg;
  #         int ap, dp;
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail("天花乱坠只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")))
  #                 return notify_fail("你必须手持兵刃才能施展天花乱坠！\n");
  # 
  #     if (target->is_busy())
  #         return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
  # 
  #     if ((int)me->query_skill("never-defeated", 1) < 100)
  #         return notify_fail("你的不败神功不够深厚，不会使用天花乱坠。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIC "$N" HIC "手中的" + weapon->name() + HIC
  #               "一勾一划，简单明了的压向$n" HIC "！\n" NOR;
  # 
  #         ap = me->query_skill("never-defeated", 1) * 3 / 2 +
  #              me->query_skill("martial-cognize", 1);
  #         dp = target->query_skill("parry") +
  #              target->query_skill("martial-cognize", 1);
  # 
  #     if (ap / 2 + random(ap) > dp)
  #         {
  #         msg += HIR "结果$p" HIR "被$P" HIR "逼得施展不开半点招式！\n" NOR;
  #         target->start_busy(ap / 45 + 2);
  #     } else
  #         {
  #         msg += CYN "可是$p" CYN "看破了$P" CYN "的招数，"
  #                        "镇定自若，应对自如。\n" NOR;
  #         me->start_busy(1);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
