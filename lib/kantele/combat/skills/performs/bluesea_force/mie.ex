defmodule Kantele.Combat.Skills.Performs.BlueseaForce.Mie do
  @moduledoc """
  perform「五阴焚灭」（source bluesea-force/perform/mie.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：目标为战斗中的对手 → 南海玄功>=150 → 真气>=300 → 目标存活。
  起手广播；attacker 侧无条件扣 60 真气并忙乱 `1+random(2)`。
  ap = 南海玄功，dp = 目标 `实战经验/10000`（目标侧计算）。
  dp>=100 时仅追加文案；否则 `random(ap) > dp` 命中则目标倒地，
  未命中则仅追加文案。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kalevala.Event

  @perform_id "bluesea-force/mie"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "bluesea-force")

    with {:ok, target} <- target(combat),
         :ok <- check_levels(stats),
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
          ap: lvl,
          rng: rng
        }
      })

      # LPC: me->add("neili", -60); me->start_busy(1 + random(2));（皆为无条件）
      vitals = character.meta.vitals
      vitals = %{vitals | neili: max(vitals.neili - 60, 0)}
      combat = Combat.start_busy(character.meta.combat, 1 + :rand.uniform(2))
      character = %{character | meta: character.meta |> Map.put(:vitals, vitals) |> Map.put(:combat, combat)}

      apply_effect(conn, character, target)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  #              return notify_fail("五阴焚灭只能在战斗中对对手使用。\n");
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "五阴焚灭只能在战斗中对对手使用。\n"}
    end
  end

  defp check_levels(stats) do
    cond do
      Stats.skill(stats, "bluesea-force") < 150 ->
        {:error, "你的南海玄功还不够娴熟，不能使用五阴焚灭！\n"}

      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 300 -> {:error, "你的真气不够！\n"}
      true -> :ok
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
    # LPC: msg = HIC "$N" HIC "暴喝一声，变掌为爪，迅捷无比的袭向$n！\n";
    conn =
      Broadcast.publish(
        conn,
        "$N暴喝一声，变掌为爪，迅捷无比的袭向$n！\n",
        n1: character.name,
        n2: target.name
      )

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
    stats = character.meta.stats
    # LPC: dp = target->query("combat_exp") / 10000;
    dp = div(stats.combat_exp, 10_000)
    bindings = [n1: attacker.name, n2: character.name]

    cond do
      # LPC: if (dp >= 100) msg += "$n知道来招不善，小心应对，没出一点差错。\n"
      dp >= 100 ->
        publish(conn, character, "$n知道来招不善，小心应对，没出一点差错。\n", bindings)

      # LPC: else if (random(ap) > dp) { ... target->die(me); return 1; }
      Engine.rand(rng, ap) > dp ->
        result =
          Messages.interpolate(
            "这一招完全超出了$n的想象，被$N结结实实的抓中了气海穴，浑身真气登时涣散！\n",
            bindings
          )

        # LPC: target->die(me) —— 模型化为气血清零 + 死亡标记
        vitals = %{character.meta.vitals | qi: 0}
        combat = %{character.meta.combat | dead: true}
        character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

        conn
        |> Broadcast.publish(result)
        |> put_character(character)

      true ->
        # LPC: msg += "$n大吃一惊，连忙胡乱抵挡，居然没有一点伤害，侥幸得脱！\n"
        publish(conn, character, "$n大吃一惊，连忙胡乱抵挡，居然没有一点伤害，侥幸得脱！\n", bindings)
    end
  end

  defp publish(conn, character, text, bindings) do
    conn
    |> Broadcast.publish(Messages.interpolate(text, bindings))
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-60"}], "assign_refs": [{"ap", "bluesea-force"}], "busy_lines": ["me->start_busy(1 + random(2));"], "level_gates": [{"bluesea-force", "150"}], "remote_damage": false, "resource_gates": [{"neili", "300"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // mie.c 五阴焚灭
  #
  # #include <ansi.h>
  #
  # inherit F_SSERVER;
  #
  # int perform(object me, object target)
  # {
  #     string msg;
  #         int ap, dp;
  #
  #     if (! target) target = offensive_target(me);
  #
  #     if (! target || ! me->is_fighting(target))
  #             return notify_fail("五阴焚灭只能在战斗中对对手使用。\n");
  #
  #     if (me->query_skill("bluesea-force", 1) < 150)
  #         return notify_fail("你的南海玄功还不够娴熟，不能使用五阴焚灭！\n");
  #
  #     if (me->query("neili") < 300)
  #         return notify_fail("你的真气不够！\n");
  #
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  #
  #         msg = HIC "$N" HIC "暴喝一声，变掌为爪，迅捷无比的袭向$n！\n";
  #
  #         ap = me->query_skill("bluesea-force");
  #         dp = target->query("combat_exp") / 10000;
  #     me->add("neili", -60);
  #     me->start_busy(1 + random(2));
  #
  #     me->want_kill(target);
  #         if (dp >= 100)
  #         {
  #                 msg += HIC "$n" HIC "知道来招不善，小心应对，没出一点差错。\n" NOR;
  #         } else
  #         if (random(ap) > dp)
  #         {
  #                 msg += HIR "这一招完全超出了$n" HIR "的想象，被$N"
  #                        HIR "结结实实的抓中了气海穴，浑身真气登时涣散！\n" NOR;
  #                 message_combatd(msg, me, target);
  #                 target->die(me);
  #                 return 1;
  #         } else
  #         {
  #                 msg += HIM "$n" HIM "大吃一惊，连忙胡乱抵挡，居"
  #                       "然没有一点伤害，侥幸得脱！\n" NOR;
  #         }
  #
  #         message_combatd(msg, me, target);
  #
  #     return 1;
  # }
end
