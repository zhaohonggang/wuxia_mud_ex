defmodule Kantele.Combat.Skills.Performs.NeverDefeated.Po do
  @moduledoc """
  perform「破字诀」（对照 `kungfu/skill/never-defeated/perform/po.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 手持兵刃 →
  **兵器所属技能>=150** → 兵器技能已激发为不败神功 → 不败神功>=100 →
  真气>=150 → 目标存活。
  攻击方无条件扣 100 真气；起手文案（含武器名）在攻击方广播。
  目标侧以 `ap/2 + random(ap*2)`（`ap = 不败神功*3/2 + 武学修养*3/2`）对目标
  `parry + 武学修养`：
  - 命中后再判 `ap/2 + random(ap) > dp`：成立则广播「…连出 N 招！」（N = 4+random(4)）、
    攻击方忙乱 `1 + random(N)`，随后 N 次连击（每击前有 1/2 概率给目标忙乱 1）；
    若目标持兵刃且 `random(ap)/2 > dp` 且兵器非「pin」则缴械，否则广播「竭力抵挡…」；
    未成立则目标忙乱 `4 + random(不败神功/30)` 并广播「只办了个勉力遮挡…」；
  - 未命中则攻击方忙乱 `3 + random(2)` 并广播「不过…没有露出半点破绽。」。

  差异（TODO(migrate)）：
  - `.c` 未列「是否已学此招」门槛（`can_perform`），本引擎以框架层
    `perform_known?/2` 统一把关（多出的文案不影响对齐）；
  - `me->clean_up_enemy(); target = me->select_opponent();` 折算为取
    `combat.enemies` 头部（`clean_up_enemy` 清理已阵亡敌人无对应物，未建模）；
  - 门槛文案 `"你的" + to_chinese(type) + "水平有限…"` 中 `to_chinese` 是 LPC efun、
    本引擎无对应表，此处以 `weapon.skill_type` 原始 id 代入（`.c` 断出的两段字面量
    `你的` / `水平有限，无法施展破字诀！` 逐段保留）；
  - `.c` 的 `weapon2->query("type") != "pin"` 以武器快照的 `:skill_type` 代替
    （快照无 `type` 字段）；
  - `weapon2->move(environment(me))` 的脱手折算为 `Combat.unequip(:weapon)`
    （本引擎无地面掉落，同 `dugu_jiujian/po.ex`）；
  - `.c` 先 `message_combatd(msg)` 再进连击循环、循环后再换一段 `msg` 广播，
    故本式目标侧有**两次**广播；`if (! me->is_fighting(target)) return 1` 时
    第二段不广播（以 `Combat.enemy?/2` 近似）；
  - 连击 `COMBAT_D->do_attack(me,target,weapon,0)`（第 4 参为 attack_type、无独立文案）
    折算为逐击命中判定 + 累加 qi 伤害（同 `luohan_jian/wuxing.ex`）；
  - 分支内的 `me->start_busy(...)` 经 `Performs.feedback/3` 回执；
  - `!living(target)` 门槛在攻击方无 meta 可查，恒判存活，由目标侧
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

  @perform_id "never-defeated/po"
  @cn_digits ~w(零 一 二 三 四 五 六 七 八 九 十)

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "never-defeated")
    wn = weapon_name(combat)

    # LPC: ap = skill * 3 / 2 + skill2 * 3 / 2;
    #      （skill = never-defeated，skill2 = martial-cognize）
    ap =
      div(Stats.skill(stats, "never-defeated") * 3, 2) +
        div(Stats.skill(stats, "martial-cognize") * 3, 2)

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_type_skill(stats, combat),
         :ok <- check_mapped(stats, combat),
         :ok <- check_level(stats),
         :ok <- check_neili(character),
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
          wn: wn,
          rng: rng
        }
      })

      apply_effect(conn, character, target, wn)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: 本式无 can_perform 门槛，框架层统一把关（见 moduledoc 差异说明）。
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) { me->clean_up_enemy(); target = me->select_opponent(); }
  #      if (! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "破字诀只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")))
  defp check_weapon(combat) do
    if Combat.weapon(combat) do
      :ok
    else
      {:error, "你必须手持兵刃才能施展破字诀！\n"}
    end
  end

  # LPC: type = weapon->query("skill_type");
  #      if (me->query_skill(type, 1) < 150)
  #      return notify_fail("你的" + to_chinese(type) + "水平有限，无法施展破字诀！\n");
  defp check_type_skill(stats, combat) do
    type = weapon_type(combat)

    if Stats.skill(stats, type) < 150 do
      {:error, "你的" <> type <> "水平有限，无法施展破字诀！\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped(type) != "never-defeated")
  defp check_mapped(stats, combat) do
    type = weapon_type(combat)

    if Stats.mapped(stats, type) != "never-defeated" do
      {:error, "你没有激发不败神功，无法施展破字诀！\n"}
    else
      :ok
    end
  end

  # LPC: if (skill < 100)   （skill = never-defeated）
  defp check_level(stats) do
    if Stats.skill(stats, "never-defeated") < 100 do
      {:error, "你的不败神功等级不够，无法施展破字诀！\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili") < 150) return notify_fail("你现在真气不够！\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 150 do
      {:error, "你现在真气不够！\n"}
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

  defp weapon_type(combat) do
    case Combat.weapon(combat) do
      nil -> "sword"
      weapon -> Map.get(weapon, :skill_type)
    end
  end

  defp weapon_name(combat) do
    case Combat.weapon(combat) do
      nil -> nil
      weapon -> Map.get(weapon, :name)
    end
  end

  defp apply_effect(conn, character, target, wn) do
    # LPC: msg = HIC "$N" HIC "手中" + weapon->name() +
    #            HIC "一抖，犹如夜雨流星，铺天盖地的攻向$n"
    #            HIC "，没有半点规矩可循。\n" NOR;（`+` 断段）
    conn =
      Broadcast.publish(
        conn,
        "$N手中" <> wn <> "一抖，犹如夜雨流星，铺天盖地的攻向$n，没有半点规矩可循。\n",
        n1: character.name,
        n2: target.name
      )

    # LPC: me->add("neili", -100);
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 100}
    character = %{character | meta: %{character.meta | vitals: vitals}}

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
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]
    ap = max(Map.get(data, :ap, 0), 1)
    skill = max(Map.get(data, :skill, 0), 0)

    # LPC: dp = target->query_skill("parry") + target->query_skill("martial-cognize", 1);
    dp = Stats.skill(stats, "parry") + Stats.skill(stats, "martial-cognize")

    # LPC: if (ap / 2 + random(ap * 2) > dp)
    if div(ap, 2) + Engine.rand(rng, ap * 2) > dp do
      # LPC: n = 4 + random(4);
      n = 4 + Engine.rand(rng, 4)

      # LPC: if (ap / 2 + random(ap) > dp)
      if div(ap, 2) + Engine.rand(rng, ap) > dp do
        resolve_hit_hit(conn, character, attacker, data, ap, skill, dp, n, bindings, rng)
      else
        # LPC: msg += "只办了个勉力遮挡，全然无法反击。\n";
        #      target->start_busy(4 + random(skill / 30));
        combat = Combat.start_busy(character.meta.combat, 4 + Engine.rand(rng, div(skill, 30)))
        character = %{character | meta: %{character.meta | combat: combat}}

        conn
        |> Broadcast.publish("$n只办了个勉力遮挡，全然无法反击。\n", bindings)
        |> put_character(character)
      end
    else
      # LPC: msg += "不过$n一丝不苟，严守门户，没有露出半点破绽。\n";
      #      me->start_busy(3 + random(2));
      Performs.feedback(attacker, 0, 3 + Engine.rand(rng, 2))

      Broadcast.publish(conn, "不过$n一丝不苟，严守门户，没有露出半点破绽。\n", bindings)
    end
  end

  # LPC: 命中后再命中：广播「连出 N 招」→ 攻击方忙乱 → N 连击 → 缴械/格挡文案。
  defp resolve_hit_hit(conn, character, attacker, _data, ap, _skill, _dp, n, bindings, rng) do

    # LPC: msg += "$n见来招即巧又拙，不同于人间任何招式，不禁大为慌乱，一时破绽迭出，$N"
    #            + HIY "见状连出" + chinese_number(n) + "招！\n";
    #      message_combatd(msg, me, target);
    conn =
      Broadcast.publish(
        conn,
        "$n见来招即巧又拙，不同于人间任何招式，不禁大为慌乱，一时破绽迭出，$N见状连出" <>
          chinese_number(n) <> "招！\n",
        bindings
      )

    # LPC: me->start_busy(1 + random(n));
    Performs.feedback(attacker, 0, 1 + Engine.rand(rng, n))

    # LPC: while (n-- && me->is_fighting(target))
    #      { if (random(2) && ! target->is_busy()) target->start_busy(1);
    #        COMBAT_D->do_attack(me, target, weapon, 0); }
    dodge = Stats.skill(character.meta.stats, "dodge")
    per_hit = max(div(ap, 15), 1)

    {combat, damage} =
      Enum.reduce(1..n, {character.meta.combat, 0}, fn _, {combat, acc} ->
        if Combat.enemy?(combat, attacker.id) do
          combat =
            if Engine.rand(rng, 2) == 1 and not Combat.busy?(combat) do
              Combat.start_busy(combat, 1)
            else
              combat
            end

          acc =
            if div(ap, 2) + Engine.rand(rng, ap) > dodge do
              acc + per_hit + Engine.rand(rng, per_hit)
            else
              acc
            end

          {combat, acc}
        else
          {combat, acc}
        end
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    # LPC: weapon2 = target->query_temp("weapon");
    #      if (weapon2 && random(ap) / 2 > dp && weapon2->query("type") != "pin")
    #      { msg = "…脱手而出！\n"; weapon2->move(environment(me)); }
    #      else { msg = "$n竭力抵挡，一时间再也无力反击。\n"; }
    weapon2 = Combat.weapon(combat)
    p = div(Engine.rand(rng, ap), 2)

    if weapon2 && p > _dp_val(character) and Map.get(weapon2, :skill_type) != "pin" do
      # LPC: weapon2->move(environment(me)); —— 缴械折算为卸下目标主武器（无地面掉落）
      combat = Combat.unequip(combat, :weapon)
      character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

      conn
      |> Broadcast.publish(
        "$n觉得眼前眼花缭乱，手中的" <> Map.get(weapon2, :name) <> "一时竟然拿捏不住，脱手而出！\n",
        bindings
      )
      |> put_character(character)
    else
      character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

      conn
      |> Broadcast.publish("$n竭力抵挡，一时间再也无力反击。\n", bindings)
      |> put_character(character)
    end
  end

  # LPC: dp = 目标 parry + 目标 martial-cognize
  defp _dp_val(character) do
    stats = character.meta.stats
    Stats.skill(stats, "parry") + Stats.skill(stats, "martial-cognize")
  end

  # LPC: chinese_number(n) —— 连招数（4..7）。
  defp chinese_number(i) when i >= 0 and i <= 10, do: Enum.at(@cn_digits, i)
  defp chinese_number(i), do: Integer.to_string(i)

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // po.c 破字诀
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         object weapon, weapon2;
  #         int n;
  #         int skill, skill2, ap, dp;
  #         string type;
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         skill = me->query_skill("never-defeated", 1);
  # 
  #         skill2 = me->query_skill("martial-cognize", 1);
  # 
  #         if (! me->is_fighting(target))
  #                 return notify_fail("破字诀只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")))
  #                 return notify_fail("你必须手持兵刃才能施展破字诀！\n");
  # 
  #         type = weapon->query("skill_type");
  #         if (me->query_skill(type, 1) < 150)
  #                 return notify_fail("你的" + to_chinese(type) + "水平有限，无法施展破字诀！\n");
  # 
  #         if (me->query_skill_mapped(type) != "never-defeated")
  #                 return notify_fail("你没有激发不败神功，无法施展破字诀！\n");
  # 
  #         if (skill < 100)
  #                 return notify_fail("你的不败神功等级不够，无法施展破字诀！\n");
  # 
  #         if (me->query("neili") < 150)
  #                 return notify_fail("你现在真气不够！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         me->add("neili", -100);
  # 
  #         ap = skill * 3 / 2 + skill2 * 3 / 2;
  #         dp = target->query_skill("parry") +
  #              target->query_skill("martial-cognize", 1);
  # 
  #         msg = HIC "$N" HIC "手中" + weapon->name() +
  #               HIC "一抖，犹如夜雨流星，铺天盖地的攻向$n"
  #               HIC "，没有半点规矩可循。\n" NOR;
  #         if (ap / 2 + random(ap * 2) > dp)
  #         {
  #                 n = 4 + random(4);
  #                 if (ap / 2 + random(ap) > dp)
  #                 {
  #                         msg += HIY "$n" HIY "见来招即巧又拙，不同于人间"
  #                                "任何招式，不禁大为慌乱，一时破绽迭出，$N"
  #                                HIY "见状连出" + chinese_number(n) + "招！\n" NOR;
  #                         message_combatd(msg, me, target);
  #                         me->start_busy(1 + random(n));
  #                         while (n-- && me->is_fighting(target))
  #                         {
  #                                 if (random(2) && ! target->is_busy())
  #                     target->start_busy(1);
  #                                 COMBAT_D->do_attack(me, target, weapon, 0);
  #                         }
  # 
  #                         weapon2 = target->query_temp("weapon");
  #                         if (weapon2 && random(ap) / 2 > dp && weapon2->query("type") != "pin")
  #                         {
  #                                 msg = HIW "$n" HIW "觉得眼前眼花缭乱，手中的" + weapon2->name() +
  #                                       HIW "一时竟然拿捏不住，脱手而出！\n" NOR;
  #                                 weapon2->move(environment(me));
  #                         } else
  #                         {
  #                                 msg = HIY "$n竭力抵挡，一时间再也无力反击。\n" NOR;
  #                         }
  # 
  #                         if (! me->is_fighting(target))
  #                                 // Don't show the message
  #                                 return 1;
  #                 } else
  #                 {
  #                         msg += HIY "$n" HIY "只办了个勉力遮挡，全然无法反击。\n" NOR;
  #                         target->start_busy(4 + random(skill / 30));
  #                 }
  #         } else
  #         {
  #                 msg += HIC "不过$n" HIC "一丝不苟，严守门户，没有露出半点破绽。\n" NOR;
  #                 me->start_busy(3 + random(2));
  #         }
  # 
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
