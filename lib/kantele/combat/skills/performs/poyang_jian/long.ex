defmodule Kantele.Combat.Skills.Performs.PoyangJian.Long do
  @moduledoc """
  perform「天外玉龙」（对照 `kungfu/skill/poyang-jian/long.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 武器为 sword →
  内功>=200 → 破阳冷光剑>=180 → 轻功>=200 → 内力上限>=2700 →
  真气>=350 → 激发 sword 为破阳冷光剑 → 目标存活。
  起手前按 `combat_exp` 与「剑」类武学前 5 项等级折算 `improve`，
  `ap = 剑法 + 剑法 * improve`；随后按角色 `real_perform/poyang-jian/long`
  标志分两套起手文案与消耗（未设为 220 真气/外伤 55%/忙乱
  `2 + random(2)`，已设为 300 真气/外伤 80%/忙乱 `3 + random(4)`）。
  目标侧单次判定 `ap/2 + random(ap) > 目标招架`：命中则
  `damage = ap/2 + random(ap)`、外伤比例为命中档 `hit_point`，
  攻击方按档扣真气并忙乱；未命中则扣 150 真气并忙乱
  `1 + random(2)`。命中/未命中的消耗都依赖命中结果，
  故经 `Performs.feedback(attacker, neili, busy)` 在目标侧回授。

  差异（TODO(migrate)）：
  - `me->query("real_perform/poyang-jian/long")` 为角色自定义标志（真·绝招），
    框架未建模；以 `character.meta` 的 `:"real_perform/poyang-jian/long"` 键代理，
    缺省为 false（与 LPC 未设置时一致），两套文案与消耗分档全部保留；
  - `improve` 的「最多累加 5 个可用剑类技能」折算为 `stats.skills` 取前 5 项
    等级之和（同 `baihua_cuoquan/hong.ex` 先例）；
  - `.c` 起手与命中文案里的 `+ weapon->name() +` 为两段字面量拆段，E 侧写
    `"…" <> weapon_name <> "…"`；命中文案在目标侧发布，故武器名经 event
    data 由攻击方传入（同 `dugu_jiujian/po.ex` 先例）；
  - 起手文案以 `\n` 开头、尾段含 `\n` 再接句号（.c 原文如此，逐字保留）；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧
    `combat/perform-incoming` 的死亡检查兜底。
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

  @perform_id "poyang-jian/long"
  @move_name "「天外玉龙」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: lvls = to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3));
    #      lvls = lvls * 4 / 5;
    #      ks = keys(me->query_skills("sword")); improve = 0; n = 0;
    #      for (m = 0; m < sizeof(ks); m++)
    #      {
    #              if (SKILL_D(ks[m])->valid_enable("sword"))
    #              {
    #                      n += 1; improve += (int)me->query_skill(ks[m], 1);
    #                      if (n > 4) break;
    #              }
    #      }
    #      improve = improve * 5 / 100 / lvls;
    lvls = trunc(:math.pow(max(stats.combat_exp, 1) * 10, 1 / 3) * 4 / 5)

    skill_sum =
      stats.skills
      |> Map.values()
      |> Enum.sort(:desc)
      |> Enum.take(5)
      |> Enum.sum()

    improve = skill_sum * 5 / 100 / max(lvls, 1)

    # LPC: ap = me->query_skill("sword");
    #      ap += ap * improve;
    base_ap = Stats.skill(stats, "sword")
    ap = base_ap + trunc(base_ap * improve)

    # LPC: if (me->query("real_perform/poyang-jian/long")) { 文案A; neili = 300;
    #      hit_point = 80; time = 3 + random(4); }
    #      else { 文案B; neili = 220; hit_point = 55; time = 2 + random(2); }
    # real_perform 为角色自定义标志（真·绝招），以 meta 同名键代理，缺省 false。
    real_perform = Map.get(character.meta, :"real_perform/poyang-jian/long") == true

    {opener, neili, hit_point, time} =
      if real_perform do
        {"\n但见$N手中" <>
           weapon_name(combat) <>
           "自半空中横过，剑身似曲似直，便如一件活物一般，正是破阳冷光剑的精髓「天外玉龙」，一柄死剑被$N使得如灵蛇，如神龙，猛然剑刺向$n\n。",
         300, 80, 3 + Engine.rand(rng, 4)}
      else
        {"\n只见$N手中" <>
           weapon_name(combat) <>
           "横扫而出，施出绝招「天外玉龙」，剑势纵横，犹如一条长龙蜿蜒而出，刺向$n\n。",
         220, 55, 2 + Engine.rand(rng, 2)}
      end

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
          ap: ap,
          neili: neili,
          hit_point: hit_point,
          time: time,
          weapon_name: weapon_name(combat),
          rng: rng
        }
      })

      apply_effect(conn, character, target, opener)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/poyang-jian/long"))
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
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon"))
  #       || (string)weapon->query("skill_type") != "sword")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon != nil and Map.get(weapon, :skill_type) == "sword" do
      :ok
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill("force") < 200)
  #      if (me->query_skill("poyang-jian", 1) < 180)
  #      if ((int)me->query_skill("dodge") < 200)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 200 ->
        {:error, "你的内功的修为不够，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "poyang-jian") < 180 ->
        {:error, "你的破阳冷光剑修为不够，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "dodge") < 200 ->
        {:error, "你的轻功火候不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if ((int)me->query("max_neili") < 2700)
  #      if (me->query("neili") < 350)
  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 2700 ->
        {:error, "你的内力修为不足，难以施展#{@move_name}。\n"}

      vitals.neili < 350 ->
        {:error, "你的真气不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "poyang-jian")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "sword") == "poyang-jian" do
      :ok
    else
      {:error, "你没有激发破阳冷光剑，难以施展#{@move_name}。\n"}
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

  defp weapon_name(combat) do
    case Combat.weapon(combat) do
      nil -> ""
      weapon -> Map.get(weapon, :name)
    end
  end

  # LPC: message_sort(msg, me, target);
  #      …分支与消耗都在目标侧结算…
  defp apply_effect(conn, character, target, opener) do
    Broadcast.publish(
      conn,
      opener,
      n1: character.name,
      n2: target.name
    )
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    # .c 的 !living(target) 在攻击方无 meta 可查，由此处死亡检查兜底。
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    neili = Map.get(data, :neili, 0)
    hit_point = Map.get(data, :hit_point, 0)
    time = Map.get(data, :time, 1)
    # 武器名经 event data 由攻击方传入（门槛已保证持械，此处仅防御性缺省）
    weapon_name = Map.get(data, :weapon_name, "")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("parry");
    dp = Stats.skill(character.meta.stats, "parry")

    # LPC: if (ap / 2 + random(ap) > dp)
    #      { damage = ap / 2 + random(ap);
    #        me->add("neili", -neili);
    #        me->start_busy(time);
    #        msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, hit_point,
    #                                  HIR "$n" HIR "见此招来势凶猛， 阻挡不"
    #                                  "及， 顿时被" + weapon->name() + HIR
    #                                  "所伤，苦不堪言。\n" NOR); }
    #      else
    #      { me->add("neili", -150);
    #        me->start_busy(1 + random(2));
    #        msg = CYN "可却见" CYN "$n" CYN "猛的拔地而起，避开了"
    #              CYN "$N" CYN "来势凶猛的一招。\n" NOR; }
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      damage = div(ap, 2) + Engine.rand(rng, ap)

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * hit_point, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: me->add("neili", -neili);  me->start_busy(time);
      Performs.feedback(attacker, neili, time)

      conn
      |> Broadcast.publish(
        "$n见此招来势凶猛， 阻挡不及， 顿时被" <>
          weapon_name <> "所伤，苦不堪言。\n",
        bindings
      )
      |> put_character(character)
    else
      # LPC: me->add("neili", -150);  me->start_busy(1 + random(2));
      Performs.feedback(attacker, 150, 1 + Engine.rand(rng, 2))

      conn
      |> Broadcast.publish(
        "可却见$n猛的拔地而起，避开了$N来势凶猛的一招。\n",
        bindings
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define LONG "「" HIC "天外玉龙" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  #         int neili, hit_point, time;
  # 
  #         float improve;
  #         int lvls, m, n;
  #         string martial;
  #         string *ks;
  #         martial = "sword";
  # 
  #         if (userp(me) && ! me->query("can_perform/poyang-jian/long"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(LONG "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" LONG "。\n");
  # 
  #         if (me->query_skill("force") < 200)
  #                 return notify_fail("你的内功的修为不够，难以施展" LONG "。\n");
  # 
  #         if (me->query_skill("poyang-jian", 1) < 180)
  #                 return notify_fail("你的破阳冷光剑修为不够，难以施展" LONG "。\n");
  # 
  #         if ((int)me->query_skill("dodge") < 200)
  #                 return notify_fail("你的轻功火候不够，难以施展" LONG "。\n");
  # 
  #         if ((int)me->query("max_neili") < 2700)
  #                 return notify_fail("你的内力修为不足，难以施展" LONG "。\n");
  # 
  #         if (me->query("neili") < 350)
  #                 return notify_fail("你的真气不够，难以施展" LONG "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "poyang-jian")
  #                 return notify_fail("你没有激发破阳冷光剑，难以施展" LONG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         lvls = to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3));
  #         lvls = lvls * 4 / 5;
  #         ks = keys(me->query_skills(martial));
  #         improve = 0;
  #         n = 0;
  #         //最多给予5个技能的加成
  #         for (m = 0; m < sizeof(ks); m++)
  #         {
  #             if (SKILL_D(ks[m])->valid_enable(martial))
  #             {
  #                 n += 1;
  #                 improve += (int)me->query_skill(ks[m], 1);
  #                 if (n > 4 )
  #                     break;
  #             }
  #         }
  # 
  #         improve = improve * 5 / 100 / lvls;
  # 
  #         if (! me->query("real_perform/poyang-jian/long"))
  #         {
  #                 msg = HIY "\n只见$N" HIY "手中" + weapon->name() + HIY
  #                       "横扫而出，施出绝招「" HIC "天外玉龙" HIY "」，"
  #                       "剑势纵横，犹如一条长龙蜿蜒而出，刺向$n\n" HIY "。" NOR;
  # 
  #                 neili = 220;
  #                 hit_point = 55;
  #                 time = 2 + random(2);
  #         }
  # 
  #         else
  #         {
  #                 msg = HIW "\n但见$N" HIW "手中" + weapon->name() + HIW
  #                       "自半空中横过，剑身似曲似直，便如一件活物一般，正"
  #                       "是破阳冷光剑的精髓「" HIY "天外玉龙" HIW "」，一"
  #                       "柄死剑被$N" HIW "使得如灵蛇，如神龙，猛然剑刺向$n\n"
  #                       HIW "。" NOR;
  # 
  #                 neili = 300;
  #                 hit_point = 80;
  #                 time = 3 + random(4);
  #         }
  #         message_sort(msg, me, target);
  # 
  #         ap = me->query_skill("sword");
  # 
  #         dp = target->query_skill("parry");
  # 
  #         ap += ap * improve;
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap / 2 + random(ap);
  #                 me->add("neili", -neili);
  #                 me->start_busy(time);
  #                 msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, hit_point,
  #                                            HIR "$n" HIR "见此招来势凶猛， 阻挡不"
  #                                            "及， 顿时被" + weapon->name() + HIR
  #                                            "所伤，苦不堪言。\n" NOR);
  #         } else
  #         {
  #                 me->add("neili", -150);
  #                 me->start_busy(1 + random(2));
  #                 msg = CYN "可却见" CYN "$n" CYN "猛的拔地而起，避开了"
  #                       CYN "$N" CYN "来势凶猛的一招。\n" NOR;
  #         }
  #         message_vision(msg, me, target);
  # 
  #         return 1;
  # }
end
