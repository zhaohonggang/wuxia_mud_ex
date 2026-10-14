defmodule Kantele.Combat.Skills.Performs.LonelySword.Po do
  @moduledoc """
  perform「破剑式」（source lonely-sword/po.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：目标在战斗中 → `lonely-sword`>=50 → 持剑 → 目标存活。
  （`.c` 无 `can_perform`/`query_skill_mapped` 门槛。）

  对抗：`ap = 独孤九剑 + 基本剑法/2`（学会本招则翻倍），
  目标 `dp = 目标技击类型等级*2 + ss*2`，
  其中 `ss = max(never-defeated*11/10, 独孤九剑, 辟邪剑法)`。
  - `ap/2 + random(ap) > dp`：破绽在握，`n = 3 + random(5)`；
    `ap/3 + random(ap) > dp` 时"唰唰连攻"`n` 剑，攻击方忙乱 `1 + random(n)`；
    收招后若目标持兵器、`random(ap) > dp` 且类型非 `pin` 则兵器脱手，
    否则目标"略得空隙喘息"；
  - 上述连攻条件不成立：目标"连忙抵挡"，攻击方忙乱 1、目标忙乱
    `1 + random(skill/20)`；
  - 破绽未找到：攻击方忙乱 `3 + random(2)`、目标忙乱 1。

  差异（TODO(migrate)）：
  - 起手文案含目标技击类型（`to_chinese(type)[4..<1]`），命中判定依赖目标
    `query_skill`/兵器/忙乱，故全部结算（含起手广播）在目标侧
    `resolve_incoming/4` 完成；攻击方仅下发 `ap`/`skill`/兵器名，其忙乱经
    `combat/perform-feedback` 回执补记（`.c` 无内力消耗，`neili_cost` 传 0）；
  - `.c` 的 `COMBAT_D->do_attack(me, target, weapon, 0)` 连击（完整 AP/DP/招架/
    伤害管线）折算为每击 `skill/15` 基础伤害 + 命中判定
    `skill/2 + random(skill)` vs 目标 dodge（同 dugu-jiujian/po）；
  - `me->query("can_perform/lonely-sword")` 的「按类型习得」数组未建模，
    以「已学会本招」（`perform_known?/2`）代理，故 `ap` 恒翻倍；
  - `weapon2->move(environment(me))` 的脱手折算为 `Combat.unequip(:weapon)`，
    不做跨进程物品转移；
  - `target->query_skill_prepare()` 以 `Stats.prepared/1` 的键代理；
    `target->query_temp("action_flag")` 未建模，多键时取排序首项；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧死亡检查兜底。
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

  @perform_id "lonely-sword/po"
  @cn_digits ~w(零 一 二 三 四 五 六 七 八 九 十)

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    skill = Stats.skill(stats, "lonely-sword")

    # LPC: ap = skill + me->query_skill("sword", 1) / 2;
    #      learned = me->query("can_perform/lonely-sword");
    #      if (arrayp(learned) && member_array(type, learned) != -1) ap *= 2;
    # 「按类型习得」的数组未建模，以「已学会本招」代理。
    base = skill + div(Stats.skill(stats, "sword"), 2)
    ap = if Stats.perform_known?(stats, @perform_id), do: base * 2, else: base

    with {:ok, target} <- target(combat),
         :ok <- check_levels(stats),
         {:ok, weapon} <- check_weapon(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: skill,
          skill: skill,
          ap: ap,
          weapon_name: Map.get(weapon, :name),
          rng: rng
        }
      })

      # 起手文案含目标技击类型、结算依赖目标属性，故整体在目标侧完成。
      assign(conn, :prompt, false)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "独孤九剑只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (skill < 50)
  defp check_levels(stats) do
    if Stats.skill(stats, "lonely-sword") < 50 do
      {:error, "你的独孤九剑等级不够，练好了再来！\n"}
    else
      :ok
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #          weapon->query("skill_type") != "sword")
  defp check_weapon(character) do
    case Combat.weapon(character.meta.combat) do
      %{skill_type: "sword"} = weapon -> {:ok, weapon}
      _ -> {:error, "你使用的武器不对。\n"}
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

  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活。
  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

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
    skill = max(Map.get(data, :skill, 0), 1)
    weapon_name = Map.get(data, :weapon_name, "某物")
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: weapon2 = target->query_temp("weapon"); prepare = target->query_skill_prepare();
    #      if (weapon2) type = weapon2->query("skill_type");
    #      else if (! prepare || sizeof(prepare) == 0) type = "unarmed";
    #      else if (sizeof(prepare) == 1) type = (keys(prepare))[0];
    #      else if (sizeof(prepare) == 2) type = (keys(prepare))[target->query_temp("action_flag")];
    weapon2 = Combat.weapon(character.meta.combat)
    type = target_type(character, weapon2)

    # LPC: ss = target->query_skill("never-defeated", 1) * 11 / 10;
    #      if (ss < target->query_skill("lonely-sword", 1)) ss = target->query_skill("lonely-sword", 1);
    #      if (ss < target->query_skill("pixie-jian", 1)) ss = target->query_skill("pixie-jian", 1);
    ss = div(Stats.skill(stats, "never-defeated") * 11, 10)
    ss = max(ss, Stats.skill(stats, "lonely-sword"))
    ss = max(ss, Stats.skill(stats, "pixie-jian"))

    # LPC: dp = target->query_skill(type, 1) * 2 + ss * 2;
    dp = Stats.skill(stats, type) * 2 + ss * 2

    # LPC: msg = HIC "$N" HIC "随意挥洒手中的" + weapon->name() + HIC
    #            "，招招从出其不意的方位直指$n" HIC + to_chinese(type)[4..<1] + "中的破绽。\n" NOR;
    opening =
      "$N随意挥洒手中的" <> weapon_name <> "，招招从出其不意的方位直指" <>
        type_break(type) <> "中的破绽。\n"

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: n = 3 + random(5);
      n = 3 + Engine.rand(rng, 5)

      # LPC: if (ap / 3 + random(ap) > dp)
      if div(ap, 3) + Engine.rand(rng, ap) > dp do
        # LPC: msg += HIY "$n" HIY "大吃一惊，慌乱之下破绽迭出，$N" HIY "唰唰连攻"
        #            + chinese_number(n) + "剑！\n" NOR;  message_combatd(msg, me, target);
        conn =
          Broadcast.publish(
            conn,
            opening <> "$n大吃一惊，慌乱之下破绽迭出，$N唰唰连攻" <> chinese_number(n) <> "剑！\n",
            bindings
          )

        # LPC: me->start_busy(1 + random(n));
        attacker_busy = 1 + Engine.rand(rng, n)

        # LPC: while (n-- && me->is_fighting(target)) {
        #         if (! target->is_busy() && random(2)) target->start_busy(1);
        #         COMBAT_D->do_attack(me, target, weapon, 0); }
        # 连击折算：每击 skill/15 基础伤害 + 命中判定（skill/2 + random(skill) vs 目标 dodge）。
        dodge = Stats.skill(stats, "dodge")
        per_hit = max(div(skill, 15), 1)

        {combat, damage} =
          Enum.reduce(1..n, {character.meta.combat, 0}, fn _, {combat_acc, damage_acc} ->
            combat_acc =
              if not Combat.busy?(combat_acc) and Engine.rand(rng, 2) == 1 do
                Combat.start_busy(combat_acc, 1)
              else
                combat_acc
              end

            if div(skill, 2) + Engine.rand(rng, skill) > dodge do
              {combat_acc, damage_acc + per_hit + Engine.rand(rng, per_hit)}
            else
              {combat_acc, damage_acc}
            end
          end)

        vitals =
          character.meta.vitals
          |> Vitals.damage(:qi, damage)
          |> Vitals.wound(:qi, div(damage, 3))

        character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

        # LPC: if (weapon2 && random(ap) > dp && type != "pin") { ...脱手... }
        #      else { msg = HIY "\n$n略得空隙喘息，一时间却也无力反击。\n" NOR; }
        {conn, character} =
          disarm_or_breathe(conn, character, weapon2, type, ap, dp, rng, bindings)

        Performs.feedback(attacker, 0, attacker_busy)

        put_character(conn, character)
      else
        # LPC: msg += HIY "$n" HIY "连忙抵挡，一时间不禁手忙脚乱，无暇反击。\n" NOR;
        #      me->start_busy(1); target->start_busy(1 + random(skill / 20));
        combat =
          Combat.start_busy(
            character.meta.combat,
            1 + Engine.rand(rng, max(div(skill, 20), 1))
          )

        character = %{character | meta: %{character.meta | combat: combat}}

        Performs.feedback(attacker, 0, 1)

        conn
        |> Broadcast.publish(opening <> "$n连忙抵挡，一时间不禁手忙脚乱，无暇反击。\n", bindings)
        |> put_character(character)
      end
    else
      # LPC: msg = HIC "$N" HIC "拿着手中的" + weapon->name() + HIC "，东戳西指，"
      #            "不过$n" HIC "防守的异常严密，$N" HIC "一时竟然无法找到破绽。\n" NOR;
      #      me->start_busy(3 + random(2)); target->start_busy(1);
      combat = Combat.start_busy(character.meta.combat, 1)
      character = %{character | meta: %{character.meta | combat: combat}}

      Performs.feedback(attacker, 0, 3 + Engine.rand(rng, 2))

      conn
      |> Broadcast.publish(
        "$N拿着手中的" <> weapon_name <>
          "，东戳西指，不过$n防守的异常严密，$N一时竟然无法找到破绽。\n",
        bindings
      )
      |> put_character(character)
    end
  end

  # LPC: if (weapon2 && random(ap) > dp && type != "pin")
  #      { msg = HIW "\n$n" HIW "觉得眼前眼花缭乱，手中的" + weapon2->name() + HIW
  #            "一时竟然拿捏不住，脱手而出！\n" NOR; weapon2->move(environment(me)); }
  #      else { msg = HIY "\n$n略得空隙喘息，一时间却也无力反击。\n" NOR; }
  defp disarm_or_breathe(conn, character, weapon2, type, ap, dp, rng, bindings) do
    if weapon2 != nil and Engine.rand(rng, ap) > dp and type != "pin" do
      # weapon2->move(environment(me))：脱手（不做跨进程物品转移，仅解除目标武器）。
      name = Map.get(weapon2, :name)
      combat = Combat.unequip(character.meta.combat, :weapon)
      character = %{character | meta: %{character.meta | combat: combat}}

      conn =
        Broadcast.publish(
          conn,
          "$n觉得眼前眼花缭乱，手中的" <> name <> "一时竟然拿捏不住，脱手而出！\n",
          bindings
        )

      {conn, character}
    else
      {Broadcast.publish(conn, "$n略得空隙喘息，一时间却也无力反击。\n", bindings), character}
    end
  end

  # LPC: prepare = target->query_skill_prepare();
  #      if (weapon2) type = weapon2->query("skill_type");
  #      else if (! prepare || sizeof(prepare) == 0) type = "unarmed";
  #      else if (sizeof(prepare) == 1) type = (keys(prepare))[0];
  #      else if (sizeof(prepare) == 2) type = (keys(prepare))[target->query_temp("action_flag")];
  # `query_skill_prepare()` 以 `Stats.prepared/1` 的键代理；`action_flag` 未建模，多键取排序首项。
  defp target_type(character, weapon2) do
    if weapon2 != nil do
      Map.get(weapon2, :skill_type)
    else
      case character.meta.stats |> Stats.prepared() |> Map.keys() |> Enum.sort() do
        [] -> "unarmed"
        [only] -> only
        keys -> hd(keys)
      end
    end
  end

  # LPC: to_chinese(type)[4..<1] —— 取技击类型中文名「基本」前缀之后的余部
  # （GBK 每字 2 字节，`[4..<1]` 即去前两字）。
  defp type_break(type) do
    name = to_chinese(type)
    String.slice(name, 2, max(String.length(name) - 2, 0))
  end

  defp to_chinese(type) do
    case type do
      "sword" -> "基本剑法"
      "blade" -> "基本刀法"
      "staff" -> "基本杖法"
      "whip" -> "基本鞭法"
      "club" -> "基本棍法"
      "axe" -> "基本斧法"
      "spear" -> "基本枪法"
      "fork" -> "基本叉法"
      "hammer" -> "基本锤法"
      "hook" -> "基本钩法"
      "dagger" -> "基本刺法"
      "bow" -> "基本弓术"
      "throwing" -> "基本暗器"
      "cuff" -> "基本拳法"
      "finger" -> "基本指法"
      "hand" -> "基本手法"
      "strike" -> "基本掌法"
      "claw" -> "基本爪法"
      "leg" -> "基本腿法"
      "unarmed" -> "基本拳脚"
      "parry" -> "基本招架"
      "dodge" -> "基本轻功"
      _ -> type
    end
  end

  # LPC: chinese_number(n) —— 连攻剑数（n 为 3..7）。
  defp chinese_number(i) when i < 0, do: "负" <> chinese_number(-i)
  defp chinese_number(i) when i <= 10, do: Enum.at(@cn_digits, i)
  defp chinese_number(i) when i < 20, do: "十" <> Enum.at(@cn_digits, i - 10)

  defp chinese_number(i) when i < 100 do
    if rem(i, 10) == 0 do
      Enum.at(@cn_digits, div(i, 10)) <> "十"
    else
      Enum.at(@cn_digits, div(i, 10)) <> "十" <> Enum.at(@cn_digits, rem(i, 10))
    end
  end

  defp chinese_number(i), do: Integer.to_string(i)

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // po.c 独孤九剑
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         string *learned;
  #         object weapon, weapon2;
  #         string type;
  #         mapping prepare;
  #         int n;
  #         int skill, ap, dp, ss;
  # 
  #         me->clean_up_enemy();
  #         if (! target) target = me->select_opponent();
  # 
  #         skill = me->query_skill("lonely-sword", 1);
  # 
  #         if (! me->is_fighting(target))
  #                 return notify_fail("独孤九剑只能对战斗中的对手使用。\n");
  # 
  #         if (skill < 50)
  #                 return notify_fail("你的独孤九剑等级不够，练好了再来！\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         weapon2 = target->query_temp("weapon");
  #         prepare = target->query_skill_prepare();
  #         if (weapon2) type = weapon2->query("skill_type");
  #         else if (! prepare || sizeof(prepare) == 0) type = "unarmed";
  #         else if (sizeof(prepare) == 1) type = (keys(prepare))[0];
  #         else if (sizeof(prepare) == 2)
  #                 type = (keys(prepare))[target->query_temp("action_flag")];
  # 
  #         ap = skill + me->query_skill("sword", 1) / 2;
  #         learned = me->query("can_perform/lonely-sword");
  #         if (arrayp(learned) && member_array(type, learned) != -1)
  #                 ap *= 2;
  # 
  #         ss = target->query_skill("never-defeated", 1) * 11 / 10;
  #         if (ss < target->query_skill("lonely-sword", 1))
  #                   ss = target->query_skill("lonely-sword", 1);
  #         if (ss < target->query_skill("pixie-jian", 1))
  #                   ss = target->query_skill("pixie-jian", 1);
  # 
  #         dp = target->query_skill(type, 1) * 2 + ss * 2;
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg = HIC "$N" HIC "随意挥洒手中的" + weapon->name() + HIC
  #                       "，招招从出其不意的方位直指$n" HIC +
  #                       to_chinese(type)[4..<1] + "中的破绽。\n" NOR;
  #                 n = 3 + random(5);
  #                 if (ap / 3 + random(ap) > dp)
  #                 {
  #                         msg += HIY "$n" HIY "大吃一惊，慌乱之下破绽迭出，$N" HIY "唰唰连攻" +
  #                                chinese_number(n) + "剑！\n" NOR;
  #                         message_combatd(msg, me, target);
  #                         me->start_busy(1 + random(n));
  #                         while (n-- && me->is_fighting(target))
  #                         {
  #                                 if (! target->is_busy() && random(2))
  #                                         target->start_busy(1);
  #                                 COMBAT_D->do_attack(me, target, weapon, 0);
  #                         }
  # 
  #                         if (weapon2 && random(ap) > dp && type != "pin")
  #                         {
  #                                 msg = HIW "\n$n" HIW "觉得眼前眼花缭乱，手中的" + weapon2->name() +
  #                                       HIW "一时竟然拿捏不住，脱手而出！\n" NOR;
  #                                 weapon2->move(environment(me));
  #                         } else
  #                         {
  #                                 msg = HIY "\n$n略得空隙喘息，一时间却也无力反击。\n" NOR;
  #                         }
  #                 } else
  #                 {
  #                         msg += HIY "$n" HIY "连忙抵挡，一时间不禁手忙脚乱，无暇反击。\n" NOR;
  #                         me->start_busy(1);
  #                         target->start_busy(1 + random(skill / 20));
  #                 }
  #         } else
  #         {
  #                 msg = HIC "$N" HIC "拿着手中的" + weapon->name() + HIC "，东戳西指，"
  #                       "不过$n" HIC "防守的异常严密，$N" HIC "一时竟然无法找到破绽。\n" NOR;
  #                 me->start_busy(3 + random(2));
  #                 target->start_busy(1);
  #         }
  # 
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
