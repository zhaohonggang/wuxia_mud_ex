defmodule Kantele.Combat.Skills.Performs.LiumaiShenjian.Qi do
  @moduledoc """
  perform「无形剑气」（source liumai-shenjian/qi.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 内功>=420 → 最大内力>=5000 →
  真气>=500 → 六脉神剑>=200 → 准备 finger 为六脉神剑 → 目标存活。
  起手广播为单段合并文案；命中判定 `ap*2/3 + random(ap) > dp`（ap = finger，
  dp = 目标 force）；命中伤害 `ap + random(ap/2)`，并按**目标手中兵器**分三档：
  无兵器/针类 86% 外伤、坚硬兵器（damage>180 或锤类）74%、普通兵器 55% 且兵器
  碎裂脱手；命中扣 400 真气。攻击方无条件忙乱 3。

  差异（TODO(migrate)）：
  - `do_damage(UNARMED_ATTACK, damage, percent, msg)` 折算为
    `Vitals.damage(:qi, damage)` + `Vitals.wound(:qi, div(damage*percent, 100))`；
  - 三档文案各被 `weapon->name()` 拆成 1/3/3 段，E 侧按原样用 `<>` 拆分；
  - `weapon->is_item_make()` 未建模，只取 `damage > 180 || skill_type == "hammer"`；
  - 第三档的 `weapon->move(...)` / `set("no_wield", ...)` / `set_name("碎掉的"...)` /
    `set("value", 0)` 物品变更未建模，仅以 `Combat.unequip(:weapon)` 折算脱手；
  - QI 宏展开+去色后合并为单段「无形剑气」，E 侧用 @move_name 属性插值复现；
  - `living(target)` 门槛由目标侧 combat/perform-incoming 的死亡检查兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Performs

  @perform_id "liumai-shenjian/qi"
  @move_name "「无形剑气」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "liumai-shenjian")
    ap = Stats.skill(stats, "finger")

    # LPC: damage = ap + random(ap / 2);（在攻击方掷骰，随事件传入目标侧）
    damage = ap + Engine.rand(rng, div(ap, 2))

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
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
          damage: damage,
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

  # LPC: if (userp(me) && ! me->query("can_perform/liumai-shenjian/qi"))
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

  # LPC: force < 420 / liumai-shenjian < 200
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 420 ->
        {:error, "你的内功火候不够，使不出#{@move_name}。\n"}

      Stats.skill(stats, "liumai-shenjian") < 200 ->
        {:error, "你的六脉神剑修为有限，无法使用#{@move_name}！\n"}

      true ->
        :ok
    end
  end

  # LPC: max_neili < 5000 / neili < 500
  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 5000 ->
        {:error, "你的内力修为还不足以使出如此犀利的#{@move_name}。\n"}

      vitals.neili < 500 ->
        {:error, "你的真气不够，无法使用#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_prepared("finger") != "liumai-shenjian")
  defp check_prepared(character) do
    stats = character.meta.stats

    prepared = Stats.prepared_perform(stats, "finger")

    if prepared == nil or hd(String.split(prepared, "/")) != "liumai-shenjian" do
      {:error, "你没有准备六脉神剑，无法使用#{@move_name}。\n"}
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
    # LPC: msg = HIG "$N" HIG "中指一按，一股凌厉无伦的无形剑气直奔$n"
    #               HIG "胸前射去。\n" NOR;（相邻字面量合并为单段）
    # LPC: me->start_busy(3);（无条件；命中的 -400 真气由目标侧 feedback 回执）
    combat = Combat.start_busy(character.meta.combat, 3)
    character = %{character | meta: %{character.meta | combat: combat}}

    conn =
      Broadcast.publish(
        conn,
        "$N中指一按，一股凌厉无伦的无形剑气直奔$n胸前射去。\n",
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
    damage = Map.get(data, :damage, 0)
    dp = Stats.skill(character.meta.stats, "force")

    # LPC: if (ap * 2 / 3 + random(ap) > dp)
    hit? = div(ap * 2, 3) + Engine.rand(rng, ap) > dp

    {vitals, combat, msg} =
      if hit? do
        combat = character.meta.combat
        weapon = Combat.weapon(combat)

        # LPC: if (! objectp(weapon) || weapon->query("skill_type") == "pin") 86%
        #      else if (is_item_make() || damage > 180 || skill_type == "hammer") 74%
        #      else 55% + 兵器碎裂脱手
        {percent, combat} = weapon_branch(weapon, combat)

        v =
          character.meta.vitals
          |> Vitals.damage(:qi, damage)
          |> Vitals.wound(:qi, div(damage * percent, 100))

        weapon_name = if is_map(weapon), do: Map.get(weapon, :name), else: nil
        msg = hit_message(percent, weapon_name)

        {v, combat, msg}
      else
        {character.meta.vitals, character.meta.combat, miss_message()}
      end

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    # LPC: me->add("neili", -400);（仅命中分支）
    _ = if hit?, do: Performs.feedback(attacker, 400, 0)

    conn
    |> Broadcast.publish(msg, n1: attacker.name, n2: character.name)
    |> put_character(character)
  end

  # LPC: if (! objectp(weapon) || weapon->query("skill_type") == "pin") -> 86%
  #      else if (weapon->is_item_make() || weapon->query("damage") > 180
  #               || weapon->query("skill_type") == "hammer")            -> 74%
  #      else                                                           -> 55%（兵器碎裂脱手）
  # `is_item_make()` 未建模；脱手折算为 `Combat.unequip(:weapon)`。
  defp weapon_branch(weapon, combat) do
    cond do
      not is_map(weapon) -> {86, combat}
      Map.get(weapon, :skill_type) == "pin" -> {86, combat}
      Map.get(weapon, :damage, 0) > 180 -> {74, combat}
      Map.get(weapon, :skill_type) == "hammer" -> {74, combat}
      true ->
        # LPC: weapon->move(environment(me));（兵器脱手）
        #      weapon->set("no_wield", weapon->name() + "已经碎掉了，没法装备了。\n");
        #      weapon->set_name("碎掉的" + weapon->name());
        #      weapon->set("value", 0);
        # 物品变更（move/set/set_name）未建模，脱手仅折算为 `Combat.unequip(:weapon)`；
        # 下面两个字面量仅为保留原文，不在框架内生效。
        _no_wield_msg = Map.get(weapon, :name, "") <> "已经碎掉了，没法装备了。\n"
        _renamed = "碎掉的" <> Map.get(weapon, :name, "")
        {55, Combat.unequip(combat, :weapon)}
    end
  end

  # LPC: HIR "$n" HIR "只觉得胸前一阵剧痛，鲜血" "自创口激射而出，眼前顿时一黑！\n"
  # （相邻字面量合并为单段）
  defp hit_message(86, _weapon_name) do
    "$n只觉得胸前一阵剧痛，鲜血自创口激射而出，眼前顿时一黑！\n"
  end

  # LPC: HIR "$n" HIR "横" + name + HIR "试图招架，" HIR "怎奈这股剑气如此犀利，透过"
  #      + name + HIR "直震得$n" HIR "狂吐鲜血，五脏六腑都要翻转过来！\n"
  # （name 出现两次，文案被拆成三段）
  defp hit_message(74, weapon_name) do
    "$n横" <> weapon_name <> "试图招架，怎奈这股剑气如此犀利，透过" <> weapon_name <>
      "直震得$n狂吐鲜血，五脏六腑都要翻转过来！\n"
  end

  # LPC: HIR "$n" HIR "横转" + name + HIR "，挡在胸" "前，只听啪啦一声，" + name +
  #      HIR "碎成数截，激飞上天！\n$n" HIR "连退" "几步，“哇”的吐了一口鲜血，脸色变的惨白。\n"
  # （name 出现两次，文案被拆成三段）
  defp hit_message(_percent, weapon_name) do
    "$n横转" <> weapon_name <> "，挡在胸前，只听啪啦一声，" <> weapon_name <>
      "碎成数截，激飞上天！\n$n连退几步，“哇”的吐了一口鲜血，脸色变的惨白。\n"
  end

  # LPC: CYN "可是$p" CYN "内功颇为深厚，轻轻将这道剑气化解于无形。\n" NOR
  # （相邻字面量合并为单段）
  defp miss_message do
    "可是$p内功颇为深厚，轻轻将这道剑气化解于无形。\n"
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // qi.c 无形剑气
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define QI "「" HIG "无形剑气" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         int damage;
  #         string msg;
  #         int ap, dp;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  # 
  #         if (userp(me) && ! me->query("can_perform/liumai-shenjian/qi"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(QI "只能对战斗中的对手使用。\n");
  # 
  #         if ((int)me->query_skill("force") < 420)
  #                 return notify_fail("你的内功火候不够，使不出" QI "。\n");
  # 
  #         if (me->query("max_neili") < 5000)
  #                 return notify_fail("你的内力修为还不足以使出如此犀利的" QI "。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你的真气不够，无法使用" QI "。\n");
  # 
  #         if (me->query_skill("liumai-shenjian", 1) < 200)
  #                 return notify_fail("你的六脉神剑修为有限，无法使用" QI "！\n");
  # 
  #         if (me->query_skill_prepared("finger") != "liumai-shenjian")
  #                 return notify_fail("你没有准备六脉神剑，无法使用" QI "。\n");
  # 
  #         if (! living(target))
  #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIG "$N" HIG "中指一按，一股凌厉无伦的无形剑气直奔$n" HIG "胸前射去。\n" NOR;  
  # 
  #         ap = me->query_skill("finger");
  #         dp = target->query_skill("force");
  #         weapon = target->query_temp("weapon");
  #         me->start_busy(3);
  #         if (ap * 2 / 3 + random(ap) > dp)
  #         { 
  #                 damage = ap + random(ap / 2);
  #                 me->add("neili", -400);
  #                 if (! objectp(weapon) || weapon->query("skill_type") == "pin")
  #                         msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 86,
  #                                                    HIR "$n" HIR "只觉得胸前一阵剧痛，鲜血"
  #                                                    "自创口激射而出，眼前顿时一黑！\n" NOR);
  #                 else
  #                 if (weapon->is_item_make() || weapon->query("damage") > 180 ||
  #                     weapon->query("skill_type") == "hammer")
  #                         msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 74,
  #                                                    HIR "$n" HIR "横" + weapon->name() + HIR "试图招架，"
  #                                                    HIR "怎奈这股剑气如此犀利，透过" + weapon->name() +
  #                                                    HIR "直震得$n" HIR "狂吐鲜血，五脏六腑都要翻转过来！\n" NOR);
  #                 else
  #                 {
  #                         msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 55,
  #                                                    HIR "$n" HIR "横转" + weapon->name() + HIR "，挡在胸"
  #                                                    "前，只听啪啦一声，" + weapon->name() +
  #                                                    HIR "碎成数截，激飞上天！\n$n" HIR "连退"
  #                                                    "几步，“哇”的吐了一口鲜血，脸色变的惨白。\n" NOR);
  #                         weapon->move(environment(me));
  #                         weapon->set("no_wield", weapon->name() + "已经碎掉了，没法装备了。\n");
  #                         weapon->set_name("碎掉的" + weapon->name());
  #                         weapon->set("value", 0);
  #                 }
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "内功颇为深厚，轻轻将这道剑气化解于无形。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
