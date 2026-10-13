defmodule Kantele.Combat.Skills.Performs.JinsheZhang.Fugu do
  @moduledoc """
  perform「附骨缠身」（source jinshe-zhang/fugu.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：目标为战斗中的对手 → 主手无武器 →
  金蛇掌>=100 → 真气>=300 → 准备 strike 为金蛇掌 → 目标存活。
  （`.c` 无 `can_perform`。）
  起手广播后按 `目标 busy 或 random(基本掌法) > 目标 parry/2` 判定：
  命中则（若目标不忙乱）令目标忙乱 1、连出 3 击、攻击方扣 150 真气 / 忙乱 2，
  播报「在「附骨缠身」下，一时竟然无法还手！」；
  未命中则攻击方忙乱 2，播报「识破了这一招…摆脱了对方控制」。

  差异（TODO(migrate)）：
  - `.c` 无 `can_perform` 门槛，故不设「已知此招」检查（调用点由
    `perform_command.ex` 的 `perform_list` 放行）；
  - `.c` 的 `target->is_busy()` 与 `random(strike) vs 目标 parry` 均在目标侧结算
    （目标侧 `character` 即受击者，`Combat.busy?/1` 可直读其忙乱）；
  - 3 次 `COMBAT_D->do_attack` 折算为每击 `level` 基础判定 + 伤害；
  - `.c` 的 `me->add("neili", -150)` 只在命中支，故经 `Performs.feedback/3` 回传；
  - `.c` 用 `message_combatd` 把起手式与结算文案合成一条广播，
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

  @perform_id "jinshe-zhang/fugu"

  # LPC: 3 × COMBAT_D->do_attack(me, target, 0, 0)
  @strikes 3

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jinshe-zhang")
    # LPC: random(me->query_skill("strike"))
    ap = Stats.skill(stats, "strike")

    with {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_prepared(character),
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

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "附骨缠身只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_temp("weapon"))
  defp check_weapon(combat) do
    if Combat.occupied?(combat, :weapon) do
      {:error, "你不是空手，不能使用附骨缠身。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("jinshe-zhang", 1) < 100)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "jinshe-zhang") < 100 do
      {:error, "你的金蛇掌不够娴熟，不会使用附骨缠身。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili", 1) < 300)
  defp check_resources(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你现在内力太弱，不能使用附骨缠身。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "jinshe-zhang")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "strike")

    if prepared == nil or prepared |> String.split("/") |> hd() != "jinshe-zhang" do
      {:error, "你现在没有激发金蛇掌法，无法使用附骨缠身。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIC "$N" HIC "大喝一声，缠身而上左手一探刁住$n"
    #            HIC "手腕，右掌猛下杀手！\n"NOR; message_combatd(msg, me, target);
    #      命中/失手与攻击方消耗/忙乱在目标侧结算（需目标 busy/parry）。
    conn
    |> Broadcast.publish(
      "$N大喝一声，缠身而上左手一探刁住$n手腕，右掌猛下杀手！\n",
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
    level = max(Map.get(data, :level, 0), 1)
    strikes = Map.get(data, :strikes, @strikes)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (target->is_busy() || random(me->query_skill("strike")) > target->query_skill("parry") / 2)
    busy? = Combat.busy?(character.meta.combat)
    hit = busy? or Engine.rand(rng, ap) > div(Stats.skill(stats, "parry"), 2)

    if hit do
      # LPC: if (! target->is_busy()) target->start_busy(1);
      combat = if busy?, do: character.meta.combat, else: Combat.start_busy(character.meta.combat, 1)
      character = %{character | meta: %{character.meta | combat: combat}}

      # LPC: me->add("neili", -150); me->start_busy(2);
      Performs.feedback(attacker, 150, 2)

      # LPC 连击 3 次，每次 COMBAT_D->do_attack(me, target, 0, 0)
      dodge = Stats.skill(character.meta.stats, "dodge")

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
      |> Broadcast.publish(
        Messages.interpolate(
          "结果$n被$N的左手所制，在「附骨缠身」下，一时竟然无法还手！\n",
          bindings
        )
      )
      |> put_character(character)
    else
      # LPC: me->start_busy(2);
      Performs.feedback(attacker, 0, 2)

      conn
      |> Broadcast.publish(
        Messages.interpolate("可是$p识破了$P这一招，手肘一送，摆脱了对方控制。\n", bindings)
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // fugu.c 金蛇游身掌-附骨缠身
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         // object weapon;
  #         // int damage;
  #         string msg;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("附骨缠身只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon"))
  #                 return notify_fail("你不是空手，不能使用附骨缠身。\n");
  # 
  #         if ((int)me->query_skill("jinshe-zhang", 1) < 100)
  #                 return notify_fail("你的金蛇掌不够娴熟，不会使用附骨缠身。\n");
  # 
  #         if ((int)me->query("neili", 1) < 300)
  #                 return notify_fail("你现在内力太弱，不能使用附骨缠身。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "jinshe-zhang")
  #                 return notify_fail("你现在没有激发金蛇掌法，无法使用附骨缠身。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIC "$N" HIC "大喝一声，缠身而上左手一探刁住$n"
  #               HIC "手腕，右掌猛下杀手！\n"NOR;
  #         message_combatd(msg, me, target);
  # 
  #         if (target->is_busy() ||
  #             random(me->query_skill("strike")) > target->query_skill("parry") / 2)
  #         {
  #                 if (! target->is_busy())
  #                         target->start_busy(1);
  # 
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  # 
  #                 me->add("neili", -150);
  #                 me->start_busy(2);
  #                 msg = HIR "结果$n" HIR "被$N" HIR "的左手所制，"
  #                       "在「附骨缠身」下，一时竟然无法还手！\n" NOR;
  #         }
  #         else
  #         {
  #                 me->start_busy(2);
  #                 msg = CYN "可是$p" CYN "识破了$P"
  #                       CYN "这一招，手肘一送，摆脱了对方控制。\n"NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
