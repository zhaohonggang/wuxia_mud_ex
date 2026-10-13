defmodule Kantele.Combat.Skills.Performs.HuoyanDao.Yan do
  @moduledoc """
  perform「天寰神炎」（source huoyan-dao/yan.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 空手 →
  基本内功>=200 → 火焰刀>=150 → 真气>=600 且 内力上限>=2000 →
  激发 strike 为火焰刀 → 准备 strike 为火焰刀 →
  副手（hand）未背密宗大手印 → 目标存活。
  起手广播后连出 5 击（`COMBAT_D->do_attack`）。
  攻击方扣 500 真气并忙乱 `3+random(2)`（均为无条件）。

  差异（TODO(migrate)）：
  - LPC 的 5 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线）折算为
    每击 `level` 基础判定 + 伤害（与 `honglian_dao/huo.ex` 同构）；
  - `.c` 在每击前 `add_temp("apply/attack", 10)`、末了 `-50`（净零）的
    攻击加成已折入上述每击 `level` 模型；
  - `do_attack` 第 4 参为 0（无自定义文案），命中/失手文案由引擎动作表生成，
    故本文件不再自行发布战斗结果文案；
  - `.c` 循环内的 `if (! me->is_fighting(target)) break;` 未建模（目标侧单次结算）。
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

  @perform_id "huoyan-dao/yan"
  @move_name "「天寰神炎」"

  # LPC: 5 × COMBAT_D->do_attack(me, target, weapon, 0)
  @strikes 5

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "huoyan-dao")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_mapped(character),
         :ok <- check_prepared(character),
         :ok <- check_hand(character),
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

  # LPC: if (userp(me) && ! me->query("can_perform/huoyan-dao/yan"))
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
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  defp check_weapon(combat) do
    if Combat.occupied?(combat, :weapon) or Combat.occupied?(combat, :secondary_weapon) do
      {:error, "你必须空手才能施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill("force") < 200) / if (me->query_skill("huoyan-dao", 1) < 150)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 200 ->
        {:error, "你的内功的修为不够，无法施展#{@move_name}。\n"}

      Stats.skill(stats, "huoyan-dao") < 150 ->
        {:error, "你的火焰刀修为不够，无法施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query("neili") < 600 || me->query("max_neili") < 2000)
  defp check_resources(character) do
    vitals = character.meta.vitals

    if vitals.neili < 600 or vitals.max_neili < 2000 do
      {:error, "你的真气不够，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "huoyan-dao")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "strike") == "huoyan-dao" do
      :ok
    else
      {:error, "你没有激发火焰刀，无法施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "huoyan-dao")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "strike")

    if prepared == nil or prepared |> String.split("/") |> hd() != "huoyan-dao" do
      {:error, "你没有准备火焰刀，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("hand") == "dashou-yin")
  defp check_hand(character) do
    hand = Stats.prepared_perform(character.meta.stats, "hand")

    if hand != nil and hand |> String.split("/") |> hd() == "dashou-yin" do
      {:error, "施展#{@move_name}时火焰刀不宜和密宗大手印互背！\n"}
    else
      :ok
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
    # LPC: msg = HIR "$N" HIR "一声怒嚎，狂催真气注入单掌，掌缘顿时腾起一道烈炎，接二连三朝$n"
    #            HIR "劈去。\n" NOR; message_combatd(msg, me, target);
    #      me->add("neili", -500);
    #      5 × { me->add_temp("apply/attack", 10); COMBAT_D->do_attack(me, target, weapon, 0); }
    #      me->add_temp("apply/attack", -50);
    #      me->start_busy(3 + random(2));
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 500}
    combat = Combat.start_busy(character.meta.combat, 3 + Engine.rand(rng, 2))
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    conn
    |> Broadcast.publish(
      "$N一声怒嚎，狂催真气注入单掌，掌缘顿时腾起一道烈炎，接二连三朝$n劈去。\n",
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
  # #define YAN "「" HIR "天寰神炎" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/huoyan-dao/yan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(YAN "只能在战斗中对对手使用。\n");
  # 
  #         if (me->query_temp("weapon") ||
  #             me->query_temp("secondary_weapon"))
  #                 return notify_fail("你必须空手才能施展" YAN "。\n");
  # 
  #         if (me->query_skill("force") < 200)
  #                 return notify_fail("你的内功的修为不够，无法施展" YAN "。\n");
  # 
  #         if (me->query_skill("huoyan-dao", 1) < 150)
  #                 return notify_fail("你的火焰刀修为不够，无法施展" YAN "。\n");
  # 
  #         if (me->query("neili") < 600 || me->query("max_neili") < 2000)
  #                 return notify_fail("你的真气不够，无法施展" YAN "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "huoyan-dao")
  #                 return notify_fail("你没有激发火焰刀，无法施展" YAN "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "huoyan-dao")
  #                 return notify_fail("你没有准备火焰刀，无法施展" YAN "。\n");
  # 
  #         if (me->query_skill_prepared("hand") == "dashou-yin")
  #                 return notify_fail("施展" YAN "时火焰刀不宜和密宗大手印互背！\n");
  # 
  #         if (! living(target))
  #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIR "$N" HIR "一声怒嚎，狂催真气注入单掌，掌缘顿时腾起一道烈炎，接二连三朝$n"
  #               HIR "劈去。\n" NOR;
  #         message_combatd(msg, me, target);
  # 
  #     me->add("neili", -500);
  # 
  #         me->add_temp("apply/attack", 10);
  #           COMBAT_D->do_attack(me, target, weapon, 0);
  # 
  #         me->add_temp("apply/attack", 10);
  #     COMBAT_D->do_attack(me, target, weapon, 0);
  # 
  #         me->add_temp("apply/attack", 10);
  #     COMBAT_D->do_attack(me, target, weapon, 0);
  # 
  #         me->add_temp("apply/attack", 10);
  #     COMBAT_D->do_attack(me, target, weapon, 0);
  # 
  #         me->add_temp("apply/attack", 10);
  #     COMBAT_D->do_attack(me, target, weapon, 0);
  # 
  #         // 消除攻击修正
  #         me->add_temp("apply/attack", -50);
  # 
  #     me->start_busy(3 + random(2));
  # 
  #     return 1;
  # }
end
