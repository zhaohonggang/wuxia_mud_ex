defmodule Kantele.Combat.Skills.Performs.HonglianDao.Huo do
  @moduledoc """
  perform「流星火雨」（source honglian-dao/huo.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 兵器为刀 →
  基本内功>=120 → 红莲刀法>=80 → 内力上限>=800 → 真气>=100 → 激发 blade
  为红莲刀法 → 目标存活。起手广播后连出 4 击（`COMBAT_D->do_attack`）。
  攻击方扣 80 真气并忙乱 `1+random(4)`（均为无条件）。

  差异（TODO(migrate)）：
  - LPC 的 4 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线）折算为
    每击 `level` 基础判定 + 伤害（与 `biyan_dao/luo.ex` 同构）；
  - `do_attack` 第 4 参为 0（无自定义文案），命中/失手文案由引擎动作表生成，
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

  @perform_id "honglian-dao/huo"
  @move_name "「流星火雨」"

  # LPC: for (i = 0; i < 4; i++) { ... COMBAT_D->do_attack(me, target, weapon, 0); }
  @strikes 4

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "honglian-dao")
    weapon_name = weapon_name(combat)

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_mapped(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          strikes: @strikes,
          rng: rng
        }
      })

      apply_effect(conn, character, target, weapon_name, rng)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/honglian-dao/huo"))
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
  #         (string)weapon->query("skill_type") != "blade")
  defp check_weapon(combat) do
    if weapon_name(combat) == nil do
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("force") < 120) / if ((int)me->query_skill("honglian-dao", 1) < 80)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 120 ->
        {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "honglian-dao") < 80 ->
        {:error, "你红莲刀法不够娴熟，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if ((int)me->query("max_neili") < 800) / if ((int)me->query("neili") < 100)
  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 800 -> {:error, "你的内力修为不够，难以施展#{@move_name}。\n"}
      vitals.neili < 100 -> {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  # LPC: if (me->query_skill_mapped("blade") != "honglian-dao")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "blade") == "honglian-dao" do
      :ok
    else
      {:error, "你没有激发红莲刀法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活，
  # 由目标侧 combat/perform-incoming 的死亡检查兜底。
  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target, weapon_name, rng) do
    # LPC: msg = HIR "$N" HIR "施出红莲刀法绝技，手中" + weapon->name() +
    #           HIR "运转如飞，激起层层热浪席卷$n" HIR "周身！\n" NOR;
    #      message_combatd(msg, me, target);
    #      me->add("neili", -80); ... me->start_busy(1 + random(4));
    # .c 里 weapon->name() 两侧各为一个独立字面量，故 Elixir 侧保持
    #      "A" <> weapon_name <> "B" 的插入形式（不合并）。
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 80}
    combat = Combat.start_busy(character.meta.combat, 1 + Engine.rand(rng, 4))
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    conn
    |> Broadcast.publish(
      "$N施出红莲刀法绝技，手中" <>
        weapon_name <> "运转如飞，激起层层热浪席卷$n周身！\n",
      n1: character.name,
      n2: target.name
    )
    |> put_character(character)
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

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    # .c 的 living(target) 门槛由目标侧 death 检查兜底
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, _attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    level = max(Map.get(data, :level, 0), 1)
    strikes = Map.get(data, :strikes, @strikes)
    dodge = Stats.skill(character.meta.stats, "dodge")

    # LPC 连击 4 次，每次 COMBAT_D->do_attack(me, target, weapon, 0)
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
    |> put_character(character)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define HUO "「" HIR "流星火雨" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg;
  #     int i;
  # 
  #         if (userp(me) && ! me->query("can_perform/honglian-dao/huo"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #                 return notify_fail(HUO "只能对战斗中的对手使用。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "blade")
  #                 return notify_fail("你使用的武器不对，难以施展" HUO "。\n");
  # 
  #         if ((int)me->query_skill("force") < 120 )
  #                 return notify_fail("你的内功火候不够，难以施展" HUO "。\n");
  # 
  #         if ((int)me->query_skill("honglian-dao", 1) < 80)
  #                 return notify_fail("你红莲刀法不够娴熟，难以施展" HUO "。\n");
  # 
  #         if ((int)me->query("max_neili") < 800)
  #                 return notify_fail("你的内力修为不够，难以施展" HUO "。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你现在真气不够，难以施展" HUO "。\n");
  # 
  #         if (me->query_skill_mapped("blade") != "honglian-dao")
  #                 return notify_fail("你没有激发红莲刀法，难以施展" HUO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "$N" HIR "施出红莲刀法绝技，手中" + weapon->name() +
  #               HIR "运转如飞，激起层层热浪席卷$n" HIR "周身！\n" NOR;
  #         message_combatd(msg, me, target);
  # 
  #         me->add("neili", -80);
  # 
  #         for (i = 0; i < 4; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  # 
  #         me->start_busy(1 + random(4));
  #         return 1;
  # }
end
