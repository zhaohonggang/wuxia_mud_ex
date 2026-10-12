defmodule Kantele.Combat.Skills.Performs.BiyanDao.Luo do
  @moduledoc """
  perform「瀑落九霄」（source biyan-dao/luo.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 兵器为刀 →
  碧烟刀法>=80 → 基本内功>=120 → 激发 blade 为碧烟刀法 → 真气>=80 → 目标存活。
  起手广播后连出 5 击（`COMBAT_D->do_attack`）。
  攻击方扣 80 真气（循环结束后无条件扣除）并忙乱 `1+random(3)`。

  差异（TODO(migrate)）：
  - LPC 的 5 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线）折算为
    每击 `level` 基础判定 + 伤害（与 `duanjia_jian/lian.ex` 同构）；
  - `do_attack` 第 5 参为 0（无自定义文案），命中/失手文案由引擎按
    `Kantele.Combat.Skills.BiyanDao.query_action/2` 的动作表另行生成，
    故本文件不再自行发布战斗结果文案；
  - `weapon->query("skill_type") != "blade"` 的兵器检查未持刀/非刀合并为同一文案。
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
  alias Kantele.Combat.Performs

  @perform_id "biyan-dao/luo"
  @move_name "「瀑落九霄」"

  # LPC: for (i = 0; i < 5; i++) { ... COMBAT_D->do_attack(me, target, weapon, 0); }
  @strikes 5

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "biyan-dao")

    with :ok <- check_perform_known(stats),
         {:ok, target} <- target(combat),
         {:ok, weapon} <- weapon(combat),
         :ok <- check_levels(stats),
         :ok <- check_force(stats),
         :ok <- check_mapped(stats),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          rng: rng
        }
      })

      apply_effect(conn, character, target, Map.get(weapon, :name))
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  #              return notify_fail(LUO "只能在战斗中对对手使用。\n");
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #          (string)weapon->query("skill_type") != "blade")
  #          return notify_fail("你的武器不对，难以施展" LUO "。\n");
  defp weapon(combat) do
    case Combat.weapon(combat) do
      %{skill_type: "blade"} = weapon -> {:ok, weapon}
      _ -> {:error, "你的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  defp check_levels(stats) do
    cond do
      Stats.skill(stats, "biyan-dao") < 80 ->
        {:error, "你碧烟刀法不够娴熟，难以施展#{@move_name}。\n"}

      true -> :ok
    end
  end

  defp check_force(stats) do
    cond do
      Stats.skill(stats, "force") < 120 ->
        {:error, "你内功火候不够，难以施展#{@move_name}。\n"}

      true -> :ok
    end
  end

  defp check_mapped(stats) do
    cond do
      Stats.mapped(stats, "blade") != "biyan-dao" ->
        {:error, "你没有激发碧烟刀法，难以施展#{@move_name}。\n"}

      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 80 -> {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  defp check_target_alive(target) do
    if not target.meta.combat.dead do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp apply_effect(conn, character, target, weapon_name) do
    # LPC: msg = HIW "$N" HIW "大喝一声，手中" + weapon->name() + HIW
    #              "一振，便如飞瀑一般向$n" HIW "席卷而去！\n" NOR;
    #      message_combatd(msg, me, target);
    # .c 里 Weapname 两侧各为一个独立字面量，故 Elixir 侧保持
    #      "A" <> weapon_name <> "B" 的插入形式（不合并）。
    conn =
      Broadcast.publish(
        conn,
        "$N大喝一声，手中" <>
          weapon_name <> "一振，便如飞瀑一般向$n席卷而去！\n",
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
    # .c 的 living(target) 门槛未在攻击方实现，由目标侧 death 检查兜底
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    level = max(Map.get(data, :level, 0), 1)
    dodge = Stats.skill(character.meta.stats, "dodge")

    # LPC 连击 5 次，每次 COMBAT_D->do_attack(me, target, weapon, 0)
    {combat, damage} =
      Enum.reduce(1..@strikes, {character.meta.combat, 0}, fn _,
                                                               {combat_acc, damage_acc} ->
        if div(level, 2) + Engine.rand(rng, level) > dodge do
          {combat_acc, damage_acc + level + Engine.rand(rng, level)}
        else
          {combat_acc, damage_acc}
        end
      end)

    vitals = character.meta.vitals

    vitals =
      if damage > 0 do
        vitals |> Vitals.damage(:qi, damage) |> Vitals.wound(:qi, div(damage, 3))
      else
        vitals
      end

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    # LPC: me->add("neili", -80); me->start_busy(1 + random(3));
    Performs.feedback(attacker, 80, 1 + Engine.rand(rng, 3))

    conn
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-80"}], "busy_lines": ["me->start_busy(1 + random(3));"], "level_gates": [{"biyan-dao", "80"}, {"force", "120"}], "map_gates": [{"blade", "biyan-dao"}], "remote_damage": false, "resource_gates": [{"neili", "80"}], "var_gates": [{"i", "5"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  #
  # #define LUO "「" HIW "瀑落九霄" NOR "」"
  #
  # inherit F_SSERVER;
  #
  # int perform(object me, object target)
  # {
  #         // int damage;
  #         string msg;
  #         object weapon;
  #         int i;
  #
  #         if (userp(me) && ! me->query("can_perform/biyan-dao/luo"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  #
  #         if (! target) target = offensive_target(me);
  #
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(LUO "只能在战斗中对对手使用。\n");
  #
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "blade")
  #                 return notify_fail("你的武器不对，难以施展" LUO "。\n");
  #
  #         if ((int)me->query_skill("biyan-dao", 1) < 80 )
  #                 return notify_fail("你碧烟刀法不够娴熟，难以施展" LUO "。\n");
  #
  #         if ((int)me->query_skill("force") < 120 )
  #                 return notify_fail(RED"你内功火候不够，难以施展" LUO "。\n");
  #
  #         if (me->query_skill_mapped("blade") != "biyan-dao")
  #                 return notify_fail("你没有激发碧烟刀法，难以施展" LUO "。\n");
  #
  #         if ((int)me->query("neili") < 80)
  #                 return notify_fail(HIC"你现在真气不够，难以施展" LUO "。\n");
  #
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  #
  #         msg = HIW "$N" HIW "大喝一声，手中" + weapon->name() + HIW
  #               "一振，便如飞瀑一般向$n" HIW "席卷而去！\n" NOR;
  #         message_combatd(msg, me, target);
  #
  #         for (i = 0; i < 5; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #             COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  #
  #         me->add("neili", -80);
  #         me->start_busy(1 + random(3));
  #         return 1;
  # }
end
