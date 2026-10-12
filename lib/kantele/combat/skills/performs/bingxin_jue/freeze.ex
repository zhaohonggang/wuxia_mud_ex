defmodule Kantele.Combat.Skills.Performs.BingxinJue.Freeze do
  @moduledoc """
  exert「freeze」（source bingxin-jue/freeze.c，inherit F_CLEAN_UP）

  门槛（按 .c 顺序）：目标为战斗中的对手 → 冰心决>=150 → 真气>=1000 → 目标存活。
  前置广播；攻击方忙乱 2（先于判定）。
  ap=dp=基本内功（.c 两行均为 `me->query_skill("force")`，非目标侧数值）；
  命中判定 `ap/2 + random(ap) > random(dp)`；
  命中：目标 qi/劲 qi 各减 `ap/3 + random(ap/3)`，
  目标 neili += 该伤害（目标 neili > 伤害时）否则归零，目标忙乱 1；
  失手仅追加文案。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kalevala.Event

  @perform_id "bingxin-jue/freeze"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with {:ok, target} <- target(character.meta.combat),
         :ok <- check_gates(character, target) do
      stats = character.meta.stats
      ap = Stats.skill(stats, "force")

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: Stats.skill(stats, "bingxin-jue"),
          ap: ap,
          dp: ap,
          rng: &:rand.uniform/1
        }
      })

      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (target == me || ! target) { me->clean_up_enemy(); target = me->select_opponent(); }
  #      if (! me->is_fighting(target)) return notify_fail("你只能用寒气攻击战斗中的对手。\n");
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "你只能用寒气攻击战斗中的对手。\n"}
    end
  end

  defp check_gates(character, target) do
    with :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "bingxin-jue") < 150 ->
        {:error, "你的冰心决火候不够，无法运用寒气。\n"}

      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 1000 -> {:error, "你的内力不够!\n"}
      true -> :ok
    end
  end

  defp check_target_alive(target) do
    if not target.meta.combat.dead do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp apply_effect(conn, character) do
    # LPC: me->start_busy(2);（无条件，且在命中判定之前）
    #      前置广播与命中/失手追加文案合并为一次 message_combatd，
    #      统一由目标侧 resolve_incoming 发布。
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
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
    # LPC: dp = me->query_skill("force")（攻击方自身，非目标侧数值）
    dp = max(Map.get(data, :dp, 0), 1)

    hit = div(ap, 2) + rng.(ap) > rng.(dp)

    vitals = character.meta.vitals

    vitals =
      if hit do
        damage = div(ap, 3) + rng.(div(ap, 3))
        # LPC: target->receive_damage("qi", damage, me); target->receive_wound("qi", damage, me);
        vitals = vitals |> Vitals.damage(:qi, damage) |> Vitals.wound(:qi, damage)

        # LPC: if (target->query("neili") > damage) target->add("neili", damage);
        #      else target->set("neili", 0);
        if vitals.neili > damage,
          do: %{vitals | neili: vitals.neili + damage},
          else: %{vitals | neili: 0}
      else
        vitals
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: target->start_busy(1);（仅命中）
    combat =
      if hit, do: Combat.start_busy(character.meta.combat, 1), else: character.meta.combat

    character = %{character | meta: %{character.meta | combat: combat}}

    # LPC msg 为一次 message_combatd：前置段 + 命中/失手追加段。
    # 各段在 .c 中由颜色宏分隔，故保持为独立字面量（逗号阻断相邻合并）。
    msg =
      [
        "$N默运冰心决，一股寒气迎面扑向$n，四周登时雪花飘飘。\n",
        if hit do
          "$n忽然觉得一阵透骨寒意，霎时间浑身的血液几乎都要凝固了。\n"
        else
          "$n感到一阵寒意自心底泛起，连忙运动抵抗，堪勘无事。\n"
        end
      ]
      |> Enum.join("")

    conn
    |> Broadcast.publish(msg, n1: attacker.name, n2: character.name)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"assign_refs": [{"ap", "force"}, {"dp", "force"}], "busy_lines": ["me->start_busy(2);", "target->start_busy(1);"], "level_gates": [{"bingxin-jue", "150"}], "remote_damage": false, "resource_gates": [{"neili", "1000"}], "set_flags": [{"neili", "0"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  #
  # inherit F_CLEAN_UP;
  #
  # void remove_effect(object me, int amount);
  #
  # int exert(object me, object target)
  # {
  #         int ap;
  #         int dp;
  #         int damage;
  #         string msg;
  #
  #         if (target == me || ! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  #
  #         if (! me->is_fighting(target))
  #                 return notify_fail("你只能用寒气攻击战斗中的对手。\n");
  #
  #         if (me->query_skill("bingxin-jue", 1) < 150)
  #                 return notify_fail("你的冰心决火候不够，无法运用寒气。\n");
  #
  #         if ((int)me->query("neili") < 1000)
  #                 return notify_fail("你的内力不够!");
  #
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  #
  #         msg = HIW "$N" HIW "默运冰心决，一股寒气迎面扑向$n"
  #               HIW "，四周登时雪花飘飘。\n" NOR;
  #
  #         ap = me->query_skill("force");
  #         dp = me->query_skill("force");
  #
  #         me->start_busy(2);
  #
  #         if (ap / 2 + random(ap) > random(dp))
  #         {
  #                 damage = ap / 3 + random(ap / 3);
  #                 target->receive_damage("qi", damage, me);
  #                 target->receive_wound("qi", damage, me);
  #                 if (target->query("neili") > damage)
  #                         target->add("neili", damage);
  #                 else
  #                         target->set("neili", 0);
  #
  #                 msg += HIR "$n" HIR "忽然觉得一阵透骨寒意，霎时间"
  #                        "浑身的血液几乎都要凝固了。\n" NOR;
  #                 target->start_busy(1);
  #         } else
  #                 msg += HIY "$n" HIY "感到一阵寒意自心底泛起，连忙"
  #                        "运动抵抗，堪堪无事。\n" NOR;
  #
  #         message_combatd(msg, me, target);
  #
  #         return 1;
  # }
end
