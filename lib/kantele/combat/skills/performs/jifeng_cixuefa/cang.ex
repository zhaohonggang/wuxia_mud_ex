defmodule Kantele.Combat.Skills.Performs.JifengCixuefa.Cang do
  @moduledoc """
  perform「天蝎藏针」（source jifeng-cixuefa/cang.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 手持 dagger →
  基本内功>=120 → 基本轻功>=120 → 疾风刺穴法>=100 → 真气>=200 →
  激发 dagger 为疾风刺穴法 → 目标存活。
  起手广播（含武器名）后连出 5 击（`COMBAT_D->do_attack`）。
  攻击方扣 80 真气并忙乱 `1+random(4)`（均为无条件）。

  差异（TODO(migrate)）：
  - LPC 的 5 次 `COMBAT_D->do_attack(me, target, weapon, 0)`（完整 AP/DP/招架/伤害管线）
    折算为每击 `level` 基础判定 + 伤害（与 `huoyan_dao/yan.ex` 同构）；
  - `do_attack` 第 4 参为 0（无自定义文案），命中/失手文案由引擎动作表生成，
    故本文件不再自行发布战斗结果文案；
  - `.c` 循环内的 `if (! me->is_fighting(target)) break;` 未建模（目标侧单次结算）；
  - `.c` 起手文案把武器名 `weapon->name()` 插在中文串中间，故按约定写成
    `"A" <> weapon_name <> "B"` 两段（不得合并为单段）。
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

  @perform_id "jifeng-cixuefa/cang"
  @move_name "「天蝎藏针」"

  # LPC: for (i = 0; i < 5; i++) COMBAT_D->do_attack(me, target, weapon, 0);
  @strikes 5

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jifeng-cixuefa")

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

      apply_effect(conn, character, target, rng)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/jifeng-cixuefa/cang"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #          (string)weapon->query("skill_type") != "dagger")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon == nil or Map.get(weapon, :skill_type) != "dagger" do
      {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill("force") < 120) / if (me->query_skill("dodge") < 120)
  #      / if (skill < 100)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 120 ->
        {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "dodge") < 120 ->
        {:error, "你的轻功修为不够，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "jifeng-cixuefa") < 100 ->
        {:error, "你的疾风刺穴法修为有限，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query("neili") < 200)
  defp check_resources(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("dagger") != "jifeng-cixuefa")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "dagger") == "jifeng-cixuefa" do
      :ok
    else
      {:error, "你没有激发疾风刺穴法，难以施展#{@move_name}。\n"}
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

  defp apply_effect(conn, character, target, rng) do
    # LPC: msg = HIY "$N" HIY "一声叱喝，手中" + weapon->name() + HIY "连环五刺，招数"
    #            "层出不穷，闪电般朝$n" HIY "射去！\n" NOR;
    #      message_combatd(msg, me, target);
    #      me->add("neili", -80);
    #      5 × COMBAT_D->do_attack(me, target, weapon, 0);
    #      me->start_busy(1 + random(4));
    weapon = Combat.weapon(character.meta.combat) || %{}
    weapon_name = Map.get(weapon, :name, "")
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 80}
    combat = Combat.start_busy(character.meta.combat, 1 + Engine.rand(rng, 4))
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    conn
    |> Broadcast.publish(
      "$N一声叱喝，手中" <> weapon_name <> "连环五刺，招数层出不穷，闪电般朝$n射去！\n",
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

    # LPC 连击 5 次，每次 COMBAT_D->do_attack(me, target, weapon, 0)
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
  # #define CANG "「" HIW "天蝎藏针" NOR "」"
  # 
  # inherit F_SSERVER;
  #  
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int skill, i;
  # 
  #         if (userp(me) && ! me->query("can_perform/jifeng-cixuefa/cang"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  #  
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! me->is_fighting(target))
  #                 return notify_fail(CANG "只能对战斗中的对手使用。\n");
  # 
  #         weapon = me->query_temp("weapon");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "dagger")
  #                 return notify_fail("你所使用的武器不对，难以施展" CANG "。\n");
  # 
  #         skill = me->query_skill("jifeng-cixuefa", 1);
  # 
  #         if (me->query_skill("force") < 120)
  #                 return notify_fail("你的内功修为不够，难以施展" CANG "。\n");
  # 
  #         if (me->query_skill("dodge") < 120)
  #                 return notify_fail("你的轻功修为不够，难以施展" CANG "。\n");
  # 
  #         if (skill < 100)
  #                 return notify_fail("你的疾风刺穴法修为有限，难以施展" CANG "。\n");
  # 
  #         if (me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不足，难以施展" CANG "。\n");
  # 
  #         if (me->query_skill_mapped("dagger") != "jifeng-cixuefa")
  #                 return notify_fail("你没有激发疾风刺穴法，难以施展" CANG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "一声叱喝，手中" + weapon->name() + HIY "连环五刺，招数"
  #               "层出不穷，闪电般朝$n" HIY "射去！\n" NOR;
  #         message_combatd(msg, me, target);
  #         me->add("neili", -80);
  # 
  #         for (i = 0; i < 5; i++)
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
