defmodule Kantele.Combat.Skills.Performs.LunhuiJian.Hui do
  @moduledoc """
  perform「真·六道轮回」（source lunhui-jian/hui.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 手持剑（`skill_type == "sword"`）
  → 基本内功>=750 → 内力上限>=7500 → 禅宗心法>=500 → 释迦轮回剑>=500 →
  激发 sword 为释迦轮回剑 → 真气>=1000 → 目标存活。
  `ap = 基本剑法 + 禅宗心法`，目标 `dp = 招架 + 禅宗心法`，`damage = ap + random(ap)`。

  依次走过「六道」六间特殊房间，每道先出一段起手文案，再以
  `ap / 2 + random(ap) > dp` 判定命中：命中则 `do_damage(..., WEAPON_ATTACK, damage, 300, attackN)`
  （`300` 为外伤比例，即 `wound = damage * 300 / 100`），未命中则「将剑招卸于无形」。
  六道之后若攻击方 `lunhui-jian > 699`，追加「六道合一」一剑
  （`damage = lunhui-jian + random(lunhui-jian)`，外伤比例 500，附一段「卍」字符画）。

  差异（TODO(migrate)）：
  - 「六道合一」段在 `.c` 里写作 `///* … //*/`：LPC 中 `//` 令 `/*`/`*/` 失效，该段
    实为**生效代码**（与 `longxiang/powerup.c` 里真正的 `/* … */` 块注释不同），
    故本文件照常实现；但验收工具按块注释剥除，其文案会显示为 `+ EXTRA`（仅提示，不判失败）；
  - 六间特殊房间（`/d/special/liudaolunhui/*`）与「移入/移回原房间」本引擎未建模，
    故起手文案与命中结算全部在目标侧 `resolve_incoming/4` 顺序广播；`sroom` 回退、
    `tell_object(me/target, "\\n")` 一并省略（无中文文案，不影响验收）；
  - `me->add("neili", -500 - random(500))` / `me->start_busy(3 + random(3))` 为无条件收招代价，
    直接作用于攻击方 `apply_effect/2`；
  - `attack1` 的 `add_temp("apply/attack|parry|dodge", -damage)` 与 `set_temp("liudaolunhui")`
    在目标侧 `combat.temp` 落账；`attack2/4` 的 `weapon/cloth/armor->set("consistence", 0)`
    折算为 `Combat.unequip/2`；`attack4` 的 `armor/armor`（身甲）本框架无独立槽位，
    保留分支与文案；
  - `attack5` 的 `affect_by("poison", …)` 折算为 `ConditionEvent.apply_poison/2`；
  - `attack6/7` 的 `set_temp("no_exert"/"no_perform")` 本引擎未建模，保留分支与文案；
  - `if (target->query("qi") < 0) target->die(me)` 折算为 qi 清零 + `combat.dead`。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.ConditionEvent
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine

  @perform_id "lunhui-jian/hui"
  @move_name "「真·六道轮回」"

  # LPC: if (me->query_skill("lunhui-jian", 1) > 699)  → 六道合一
  @fuse_threshold 699

  # LPC: COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 300, …)（六道各一击）
  @wound_percent 300
  # LPC: COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 500, attack7)（六道合一）
  @fuse_wound_percent 500

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "lunhui-jian")
    ap = Stats.skill(stats, "sword") + Stats.skill(stats, "buddhism")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_max_neili(character),
         :ok <- check_buddhism(character),
         :ok <- check_lunhui(character),
         :ok <- check_mapped(character),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      # LPC: wn = weapon->name(); damage = ap + random(ap);
      weapon_name = weapon_name(combat)
      damage = ap + Engine.rand(rng, ap)

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
          weapon_name: weapon_name,
          rng: rng
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

  # LPC: if (userp(me) && ! me->query("can_perform/lunhui-jian/hui"))
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

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) || (string)weapon->query("skill_type") != "sword")
  defp check_weapon(combat) do
    case Combat.weapon(combat) do
      %{skill_type: "sword"} -> :ok
      _ -> {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("force") < 750)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "force") < 750 do
      {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("max_neili") < 7500)
  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 7500 do
      {:error, "你的内力修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("buddhism", 1) < 500)
  defp check_buddhism(character) do
    if Stats.skill(character.meta.stats, "buddhism") < 500 do
      {:error, "你对禅宗心法参悟不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("lunhui-jian", 1) < 500)
  defp check_lunhui(character) do
    if Stats.skill(character.meta.stats, "lunhui-jian") < 500 do
      {:error, "你释迦轮回剑火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "lunhui-jian")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "sword") != "lunhui-jian" do
      {:error, "你没有激发释迦轮回剑，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 1000)
  defp check_neili(character) do
    if character.meta.vitals.neili < 1000 do
      {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
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

  defp dead?(%{meta: %{combat: %{dead: dead}}}) when is_boolean(dead), do: dead
  defp dead?(_), do: false

  defp weapon_name(combat) do
    case Combat.weapon(combat) do
      %{name: name} -> name
      _ -> "剑"
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  # LPC: me->start_busy(3 + random(3)); me->add("neili", -500 - random(500));
  defp apply_effect(conn, character) do
    rng = &:rand.uniform/1
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 500 - Engine.rand(rng, 500)}
    combat = Combat.start_busy(character.meta.combat, 3 + Engine.rand(rng, 3))
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    conn
    |> put_character(character)
    |> assign(:prompt, false)
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
    level = Map.get(data, :level, 0)
    weapon_name = Map.get(data, :weapon_name, "剑")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("parry") + target->query_skill("buddhism", 1);
    stats = character.meta.stats
    dp = Stats.skill(stats, "parry") + Stats.skill(stats, "buddhism")

    # LPC: message_combatd(HIW "$N" HIW "面露拈花之意，祭起手中" + wn +
    #            HIW "，霎时碧波流转，华光万丈，说不尽的祥和。" "\n" NOR, me, target);
    conn =
      Broadcast.publish(
        conn,
        "$N面露拈花之意，祭起手中" <> weapon_name <> "，霎时碧波流转，华光万丈，说不尽的祥和。\n",
        bindings
      )

    # 六道轮回：人间道 / 畜生道 / 饿鬼道 / 修罗道 / 地狱道 / 天极道
    # （每道：先起手文案，再 `ap / 2 + random(ap) > dp` 判定，命中走 attackN，未命中「卸于无形」）
    blocks = [
      {"\n$N左手轻轻一拨，右手所持的" <> weapon_name <> "叮呤做响，剑姿说不出的潇洒妙曼。\n",
       &attack1/4, "可是$n收敛心神，奋力招架，将剑招卸于无形。\n"},
      {"\n却见$N面无表情，将手中" <> weapon_name <> "猛的往前一递，犹如毒蛇般噬向$n。\n",
       &attack2/4, "可是$n收敛心神，奋力招架，将剑招卸于无形。\n"},
      {"\n$N一声长叹，左手捏着剑诀，忽闻" <> weapon_name <> "上血腥之气渐浓，朝$n迎头斩落。\n",
       &attack3/4, "可是$n收敛心神，奋力招架，将剑招卸于无形。\n"},
      {"\n忽见$N身形微晃，顿时幻出十数个身影，十数柄" <> weapon_name <> "齐向$n刺去。\n",
       &attack4/4, "可是$n收敛心神，奋力招架，将剑招卸于无形。\n"},
      {"\n紧接着$N" <> weapon_name <> "一颤，有若龙吟，剑身腾起一道滔天寒流，向四周扩散开去。\n",
       &attack5/4, "可是$n收敛心神，奋力招架，将剑招卸于无形。\n"},
      {"\n$N身外化身，剑外化剑，手中" <> weapon_name <> "便似蛟龙腾空，拨云见日，天地为之失色。\n",
       &attack6/4, "可是$n收敛心神，奋力招架，将剑招卸于无形。\n"}
    ]

    {conn, character} =
      Enum.reduce(blocks, {conn, character}, fn {lead, attack_fun, miss_text}, {conn, character} ->
        dao_block(conn, character, attacker, lead, attack_fun, miss_text, ap, dp, damage, rng)
      end)

    # LPC: if (me->query_skill("lunhui-jian", 1) > 699) { … 六道合一 … }
    {conn, character} =
      if level > @fuse_threshold do
        fuse_block(conn, character, attacker, ap, dp, level, weapon_name, rng)
      else
        {conn, character}
      end

    # LPC: if (target->query("qi") < 0) target->die(me);
    character = maybe_die(character)

    put_character(conn, character)
  end

  # 六道之一：起手广播 + 命中判定（命中走 attackN 结算，未命中广播 miss_text）
  defp dao_block(conn, character, attacker, lead, attack_fun, miss_text, ap, dp, damage, rng) do
    bindings = [n1: attacker.name, n2: character.name]
    conn = Broadcast.publish(conn, lead, bindings)

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * @wound_percent, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}
      {conn, character, msg} = attack_fun.(conn, character, attacker, damage)
      {Broadcast.publish(conn, msg, bindings), character}
    else
      {Broadcast.publish(conn, miss_text, bindings), character}
    end
  end

  # LPC: if (me->query_skill("lunhui-jian", 1) > 699) { damage = lunhui-jian; damage += random(damage); … }
  defp fuse_block(conn, character, attacker, ap, dp, level, weapon_name, rng) do
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: message_vision(HUI, me, target);
    conn = Broadcast.publish(conn, "#{@move_name}", bindings)

    # LPC: message_vision(HIY "$N" HIY "集中精力，口宣佛号，手中" + wn +
    #            HIY "变换出六道剑气，又合而为一，垂直立于面前。\n" HIM "             〈卍〉\n" … NOR, me, target);
    art =
      "变换出六道剑气，又合而为一，垂直立于面前。\n" <>
        "             〈卍〉\n" <>
        "             ┇卍┇\n" <>
        "             ┋卍┋\n" <>
        "         ≮≡≡∝≡≡≯\n" <>
        "             ┡卍┥\n" <>
        "             ┡卍┥\n" <>
        "             ┡╋┥\n" <>
        "             ┇卍┇\n" <>
        "             ┡卍┥\n" <>
        "             ┇╋┇\n" <>
        "             ┇卍┇\n" <>
        "             ┇卍┇\n" <>
        "             ┇卍┇\n" <>
        "              ＼／\n"

    conn =
      Broadcast.publish(conn, "$N集中精力，口宣佛号，手中" <> weapon_name <> art, bindings)

    # LPC: damage = me->query_skill("lunhui-jian", 1); damage = damage + random(damage);
    damage = level + Engine.rand(rng, level)

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * @fuse_wound_percent, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}
      {conn, character, msg} = attack7(conn, character, attacker, damage)
      {Broadcast.publish(conn, msg, bindings), character}
    else
      {Broadcast.publish(conn, "可是$n收敛心神，奋力招架，将剑气卸于无形。\n", bindings), character}
    end
  end

  # LPC: if (target->query("qi") < 0) target->die(me);
  defp maybe_die(character) do
    if character.meta.vitals.qi < 0 do
      vitals = %{character.meta.vitals | qi: 0}
      combat = %{character.meta.combat | dead: true}
      %{character | meta: %{character.meta | vitals: vitals, combat: combat}}
    else
      character
    end
  end

  # LPC: string attack1(object me, object target, int damage)
  defp attack1(conn, character, _attacker, damage) do
    msg = "$n只觉心头一阵凄苦，竟忍不住要落下泪来，喉咙一甜，呕出一口鲜血。\n"
    combat = character.meta.combat

    # LPC: if (! target->query_temp("liudaolunhui")) { … add_temp("apply/attack|parry|dodge", -damage); set_temp("liudaolunhui", 1); }
    {character, msg} =
      if Map.get(combat.temp, :liudaolunhui) do
        {character, msg}
      else
        msg = msg <> "$p忽然察觉到全身的力气竟似一丝丝远离自己而去，无助之极。\n"

        combat =
          combat
          |> Combat.apply_temp(%{attack: -damage, parry: -damage, dodge: -damage})
          |> put_temp(:liudaolunhui, 1)

        {%{character | meta: %{character.meta | combat: combat}}, msg}
      end

    {conn, character, msg}
  end

  # LPC: string attack2(object me, object target, int damage)
  defp attack2(conn, character, _attacker, _damage) do
    msg = "忽然间$n感到胸口处一阵火热，剑气袭体，带出一蓬血雨。\n"
    combat = character.meta.combat

    # LPC: if (objectp(weapon = target->query_temp("weapon"))) { … weapon->set("consistence", 0); weapon->move(target); }
    {character, msg} =
      case Combat.weapon(combat) do
        %{name: wn} ->
          msg = msg <> "忽听「锵锵锵」几声脆响，$n的" <> wn <> "竟被$N绞成了块块碎片。\n"
          {%{character | meta: %{character.meta | combat: Combat.unequip(combat, :weapon)}}, msg}

        _ ->
          {character, msg}
      end

    {conn, character, msg}
  end

  # LPC: string attack3(object me, object target, int damage)
  defp attack3(conn, character, _attacker, _damage) do
    msg = "剑锋过处，卷起漫天血浪，$n只感头晕目眩，四肢乏力，难以再战。\n"
    combat = character.meta.combat

    # LPC: if (target->query_temp("shield")) { shd = target->query_temp("apply/armor"); add_temp("apply/armor", -shd); delete_temp("shield"); }
    {character, msg} =
      if Map.get(combat.temp, :shield) do
        shd = Map.get(combat.temp, :armor, 0)
        msg = msg <> "$N气劲涌至，宛若刀割，顿时将$n的护体真气摧毁得荡然无存。\n"

        combat =
          combat
          |> Combat.apply_temp(%{armor: -shd})
          |> delete_temp(:shield)

        {%{character | meta: %{character.meta | combat: combat}}, msg}
      else
        {character, msg}
      end

    {conn, character, msg}
  end

  # LPC: string attack4(object me, object target, int damage)
  defp attack4(conn, character, _attacker, _damage) do
    msg = "$n顿时大惊失色，瞬间已被$N连中数剑，直削得血肉模糊。\n"
    combat = character.meta.combat
    equipped = combat.equipped

    # LPC: if (objectp(cloth = target->query_temp("armor/cloth"))) { … }
    #      else if (objectp(armor = target->query_temp("armor/armor"))) { … }
    {character, msg} =
      case Map.get(equipped, :cloth) do
        nil ->
          # LPC 的 `armor/armor`（身甲）本框架无独立槽位（body 归一化为 cloth），保留分支与文案。
          case Map.get(equipped, :armor) do
            nil ->
              {character, msg}

            armor ->
              an = Map.get(armor, :name, "护甲")

              msg =
                msg <> "忽听「哧啦」一声脆响，$n身着的" <> an <> "竟被$N震裂，化成块块碎片。\n"

              combat = Combat.unequip(combat, :armor)
              {%{character | meta: %{character.meta | combat: combat}}, msg}
          end

        cloth ->
          cn = Map.get(cloth, :name, "衣服")
          msg = msg <> "忽听轰然声大作，$n身着的" <> cn <> "在$N内力激荡下，竟被震得粉碎。\n"
          combat = Combat.unequip(combat, :cloth)
          {%{character | meta: %{character.meta | combat: combat}}, msg}
      end

    {conn, character, msg}
  end

  # LPC: string attack5(object me, object target, int damage)
  defp attack5(conn, character, attacker, damage) do
    msg = "只见$n全身一阵抽搐，被剑锋所携的极寒气流包裹其中，刺痛难当。\n"

    # LPC: if (! target->query_condition("poison")) { target->affect_by("poison", (["level": damage*2, "name": "炼狱寒焰", "id": me->query("id"), "duration": damage/20])); … }
    if poison_active?(conn) do
      {conn, character, msg}
    else
      poison = %{
        "level" => damage * 2,
        "name" => "炼狱寒焰",
        "id" => attacker.id,
        "duration" => div(damage, 20),
        "remain" => div(damage, 20)
      }

      conn = ConditionEvent.apply_poison(conn, poison)
      msg = msg <> "霎时间$n忽觉一股奇寒散入七经八脉，仿佛连血液都停止了流动。\n"
      {conn, character, msg}
    end
  end

  # LPC: string attack6(object me, object target, int damage)
  defp attack6(conn, character, _attacker, _damage) do
    msg = "$N剑势迅猛之极，令$n毫无招架余地，竟镇怯当场，素手待毙。\n"
    combat = character.meta.combat

    # LPC: if (! target->query_temp("no_exert") || ! target->query_temp("no_perform")) { set_temp("no_exert", 1); set_temp("no_perform", 1); … }
    #      本引擎未建模 exert/perform 封印，保留分支与文案。
    {character, msg} =
      if Map.get(combat.temp, :no_exert) and Map.get(combat.temp, :no_perform) do
        {character, msg}
      else
        msg = msg <> "$n只感到全身真气涣散，丹元瓦解，似乎所有的武功竟都消逝殆尽。\n"

        combat =
          combat
          |> put_temp(:no_exert, 1)
          |> put_temp(:no_perform, 1)

        {%{character | meta: %{character.meta | combat: combat}}, msg}
      end

    {conn, character, msg}
  end

  # LPC: string attack7(object me, object target, int damage)
  defp attack7(conn, character, _attacker, _damage) do
    msg = "忽然间$n感到胸口一阵火热，剑气已从身体穿过，直飞空中。\n"
    combat = character.meta.combat

    # LPC: if (!target->query_temp("no_exert") || !target->query_temp("no_perform")) { set_temp("no_exert", 1); set_temp("no_perform", 1); … }
    {character, msg} =
      if Map.get(combat.temp, :no_exert) and Map.get(combat.temp, :no_perform) do
        {character, msg}
      else
        msg = msg <> "$n只感到全身真气涣散，丹元瓦解，似乎所有的武功竟都消逝殆尽。\n"

        combat =
          combat
          |> put_temp(:no_exert, 1)
          |> put_temp(:no_perform, 1)

        {%{character | meta: %{character.meta | combat: combat}}, msg}
      end

    {conn, character, msg}
  end

  defp put_temp(combat, key, value),
    do: %{combat | temp: Map.put(combat.temp || %{}, key, value)}

  defp delete_temp(combat, key),
    do: %{combat | temp: Map.delete(combat.temp || %{}, key)}

  defp poison_active?(conn) do
    case get_session(conn, "conditions") do
      %{"poison" => value} when not is_nil(value) -> true
      _ -> false
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define HUI "「" HIR "真·六道轮回" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # string attack1(object me, object target, int damage);
  # string attack2(object me, object target, int damage);
  # string attack3(object me, object target, int damage);
  # string attack4(object me, object target, int damage);
  # string attack5(object me, object target, int damage);
  # string attack6(object me, object target, int damage);
  # string attack7(object me, object target, int damage);
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string wn, msg;
  #         object sroom, room;
  #         int ap, dp, damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/lunhui-jian/hui"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(HUI "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" HUI "。\n");
  # 
  #         if ((int)me->query_skill("force") < 750)
  #                 return notify_fail("你的内功修为不够，难以施展" HUI "。\n");
  # 
  #         if ((int)me->query("max_neili") < 7500)
  #                 return notify_fail("你的内力修为不够，难以施展" HUI "。\n");
  # 
  #         if ((int)me->query_skill("buddhism", 1) < 500)
  #                 return notify_fail("你对禅宗心法参悟不够，难以施展" HUI "。\n");
  # 
  #         if ((int)me->query_skill("lunhui-jian", 1) < 500)
  #                 return notify_fail("你释迦轮回剑火候不够，难以施展" HUI "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "lunhui-jian")
  #                 return notify_fail("你没有激发释迦轮回剑，难以施展" HUI "。\n");
  # 
  #         if ((int)me->query("neili") < 1000)
  #                 return notify_fail("你现在真气不够，难以施展" HUI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         wn = weapon->name();
  # 
  #         message_combatd(HIW "$N" HIW "面露拈花之意，祭起手中" + wn +
  #                         HIW "，霎时碧波流转，华光万丈，说不尽的祥和。"
  #                         "\n" NOR, me, target);
  # 
  #         //  记录下最初的房间
  #         if (! objectp(sroom = environment(me)))
  #                 return 1;
  # 
  #         ap = me->query_skill("sword") +
  #              me->query_skill("buddhism", 1);
  # 
  #         dp = target->query_skill("parry") +
  #              target->query_skill("buddhism", 1);
  # 
  #         damage = ap + random(ap);
  # 
  #         // 六道轮回之人间道
  #         room = find_object("/d/special/liudaolunhui/rendao");
  #         if (! room) room = load_object("/d/special/liudaolunhui/rendao");
  # 
  #         me->move(room);
  #         target->move(room);
  # 
  #         message_vision(HIY "\n$N" HIY "左手轻轻一拨，右手所持的" + wn +
  #                        HIY "叮呤做响，剑姿说不出的潇洒妙曼。\n" NOR, me, target);
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 300,
  #                                            (: attack1, me, target, damage :));
  #         } else
  #         {
  #                 msg = CYN "可是$n" CYN "收敛心神，奋力招"
  #                       "架，将剑招卸于无形。\n" NOR;
  #         }
  #         message_vision(msg, me, target);
  # 
  #         // 六道轮回之畜生道
  #         room = find_object("/d/special/liudaolunhui/chushengdao");
  #         if (! room) room = load_object("/d/special/liudaolunhui/chushengdao");
  # 
  #         me->move(room);
  #         target->move(room);
  # 
  #         message_vision(HIY "\n却见$N" HIY "面无表情，将手中" + wn +
  #                        HIY "猛的往前一递，犹如毒蛇般噬向$n" HIY "。\n"
  #                        NOR, me, target);
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 300,
  #                                            (: attack2, me, target, damage :));
  #         } else
  #         {
  #                 msg = CYN "可是$n" CYN "收敛心神，奋力招"
  #                       "架，将剑招卸于无形。\n" NOR;
  #         }
  #         message_vision(msg, me, target);
  # 
  #         // 六道轮回之饿鬼道
  #         room = find_object("/d/special/liudaolunhui/eguidao");
  #         if (! room) room = load_object("/d/special/liudaolunhui/eguidao");
  # 
  #         me->move(room);
  #         target->move(room);
  # 
  #         message_vision(HIY "\n$N" HIY "一声长叹，左手捏着剑诀，忽闻" +
  #                        wn + HIY "上血腥之气渐浓，朝$n" HIY "迎头斩落。\n"
  #                        NOR, me, target);
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 300,
  #                                            (: attack3, me, target, damage :));
  #         } else
  #         {
  #                 msg = CYN "可是$n" CYN "收敛心神，奋力招"
  #                       "架，将剑招卸于无形。\n" NOR;
  #         }
  #         message_vision(msg, me, target);
  # 
  #         // 六道轮回之修罗道
  #         room = find_object("/d/special/liudaolunhui/xiuluodao");
  #         if (! room) room = load_object("/d/special/liudaolunhui/xiuluodao");
  # 
  #         me->move(room);
  #         target->move(room);
  # 
  #         message_vision(HIY "\n忽见$N" HIY "身形微晃，顿时幻出十数个身"
  #                        "影，十数柄" + wn + HIY "齐向$n" HIY "刺去。"
  #                        "\n" NOR, me, target);
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 300,
  #                                            (: attack4, me, target, damage :));
  #         } else
  #         {
  #                 msg = CYN "可是$n" CYN "收敛心神，奋力招"
  #                       "架，将剑招卸于无形。\n" NOR;
  #         }
  #         message_vision(msg, me, target);
  # 
  #         // 六道轮回之地狱道
  #         room = find_object("/d/special/liudaolunhui/diyudao");
  #         if (! room) room = load_object("/d/special/liudaolunhui/diyudao");
  # 
  #         me->move(room);
  #         target->move(room);
  # 
  #         message_vision(HIY "\n紧接着$N" HIY + wn + HIY "一颤，有若龙吟"
  #                        "，剑身腾起一道滔天寒流，向四周扩散开去。\n" NOR,
  #                        me, target);
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 300,
  #                                            (: attack5, me, target, damage :));
  #         } else
  #         {
  #                 msg = CYN "可是$n" CYN "收敛心神，奋力招"
  #                       "架，将剑招卸于无形。\n" NOR;
  #         }
  #         message_vision(msg, me, target);
  # 
  #         // 六道轮回之天极道
  #         room = find_object("/d/special/liudaolunhui/tiandao");
  #         if (! room) room = load_object("/d/special/liudaolunhui/tiandao");
  # 
  #         me->move(room);
  #         target->move(room);
  # 
  #         message_vision(HIY "\n$N" HIY "身外化身，剑外化剑，手中" + wn +
  #                        HIY "便似蛟龙腾空，拨云见日，天地为之失色。\n"
  #                        NOR, me, target);
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 300,
  #                                            (: attack6, me, target, damage :));
  #         } else
  #         {
  #                 msg = CYN "可是$n" CYN "收敛心神，奋力招"
  #                       "架，将剑招卸于无形。\n" NOR;
  #         }
  #         message_vision(msg, me, target);
  #         ///* 六道轮回之六道合一
  #         if (me->query_skill("lunhui-jian", 1) > 699)
  #         {
  #                 damage = me->query_skill("lunhui-jian", 1);
  #                 damage = damage + random(damage);
  #                 message_vision(HUI, me, target);
  #                 message_vision(HIY "$N" HIY "集中精力，口宣佛号，手中" + wn +
  #                                    HIY "变换出六道剑气，又合而为一，垂直立于面前。\n" HIM "             〈卍〉\n"
  #                                        "             ┇卍┇\n"
  #                                        "             ┋卍┋\n"
  #                                        "         ≮≡≡∝≡≡≯\n"
  #                                        "             ┡卍┥\n"
  #                                        "             ┡卍┥\n"
  #                                        "             ┡╋┥\n"
  #                                        "             ┇卍┇\n"
  #                                        "             ┡卍┥\n"
  #                                        "             ┇╋┇\n"
  #                                        "             ┇卍┇\n"
  #                                        "             ┇卍┇\n"
  #                                        "             ┇卍┇\n"
  #                                        "              ＼／\n" NOR,
  #                                me, target);
  # 
  #                 if (ap / 2 + random(ap) > dp)
  #                 {
  #                         msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 500,
  #                                                   (: attack7, me, target, damage :));
  #                 }
  #                 else
  #                 {
  #                         msg = CYN "可是$n" CYN "收敛心神，奋力招"
  #                                   "架，将剑气卸于无形。\n" NOR;
  #                 }
  #                 message_vision(msg, me, target);
  #         }
  #         //*/
  #         me->start_busy(3 + random(3));
  #         me->add("neili", -500 - random(500));
  # 
  #         // 为什么提行？为了画面更为赏心悦目而已
  #         tell_object(me, "\n");
  #         tell_object(target, "\n");
  # 
  #         // 转移回最初的房间
  #         me->move(sroom);
  #         target->move(sroom);
  # 
  #         // 不能通过断线来保命
  #         if (target->query("qi") < 0)
  #                 target->die(me);
  # 
  #         return 1;
  # }
  # 
  # string attack1(object me, object target, int damage)
  # {
  #         string msg;
  # 
  #         msg = HIR "$n" HIR "只觉心头一阵凄苦，竟忍不住要落"
  #               "下泪来，喉咙一甜，呕出一口鲜血。\n" NOR;
  # 
  #         if (! target->query_temp("liudaolunhui"))
  #         {
  #                 msg += WHT "$p忽然察觉到全身的力气竟似一丝"
  #                        "丝远离自己而去，无助之极。\n" NOR;
  # 
  #                 target->add_temp("apply/attack", -damage);
  #                 target->add_temp("apply/parry", -damage);
  #                 target->add_temp("apply/dodge", -damage);
  #                 target->set_temp("liudaolunhui", 1);
  #         }
  #         return msg;
  # }
  # 
  # string attack2(object me, object target, int damage)
  # {
  #         object weapon;
  #         string wn, msg;
  # 
  #         msg = HIR "忽然间$n" HIR "感到胸口处一阵火热，剑气"
  #               "袭体，带出一蓬血雨。\n" NOR;
  # 
  #         if (objectp(weapon = target->query_temp("weapon")))
  #         {
  #                 wn = weapon->name();
  #                 msg += WHT "忽听「锵锵锵」几声脆响，$n" WHT "的" + wn +
  #                        WHT "竟被$N" WHT "绞成了块块碎片。\n" NOR;
  # 
  #                 weapon->set("consistence", 0);
  #                 weapon->move(target);
  #         }
  #         return msg;
  # }
  # 
  # string attack3(object me, object target, int damage)
  # {
  #         int shd;
  #         string msg;
  # 
  #         msg = HIR "剑锋过处，卷起漫天血浪，$n" HIR "只感头晕目"
  #               "眩，四肢乏力，难以再战。\n" NOR;
  # 
  #         if (target->query_temp("shield"))
  #         {
  #                 shd = target->query_temp("apply/armor");
  # 
  #                 target->add_temp("apply/armor", -shd);
  #                 target->delete_temp("shield");
  # 
  #                 msg += WHT "$N" WHT "气劲涌至，宛若刀割，顿时将$n"
  #                        WHT "的护体真气摧毁得荡然无存。\n" NOR;
  #         }
  #         return msg;
  # }
  # 
  # string attack4(object me, object target, int damage)
  # {
  #         object cloth, armor;
  #         string cn, an, msg;
  # 
  #         msg = HIR "$n" HIR "顿时大惊失色，瞬间已被$N" HIR "连中"
  #               "数剑，直削得血肉模糊。\n" NOR;
  # 
  #         if (objectp(cloth = target->query_temp("armor/cloth")))
  #         {
  #                 cn = cloth->name();
  #                 msg += WHT "忽听轰然声大作，$n" WHT "身着的" + cn +
  #                        WHT "在$N" WHT "内力激荡下，竟被震得粉碎。\n"
  #                        NOR;
  # 
  #                 cloth->set("consistence", 0);
  #                 cloth->move(target);
  #         } else
  #         if (objectp(armor = target->query_temp("armor/armor")))
  #         {
  #                 an = armor->name();
  #                 msg += WHT "忽听「哧啦」一声脆响，$n" WHT "身着的" +
  #                        an + WHT "竟被$N" WHT "震裂，化成块块碎片。\n"
  #                        NOR;
  # 
  #                 armor->set("consistence", 0);
  #                 armor->move(target);
  #         }
  #         return msg;
  # }
  # 
  # string attack5(object me, object target, int damage)
  # {
  #         string msg;
  # 
  #         msg = HIR "只见$n" HIR "全身一阵抽搐，被剑锋所携的极寒气流"
  #               "包裹其中，刺痛难当。\n" NOR;
  # 
  #         if (! target->query_condition("poison"))
  #         {
  #                 target->affect_by("poison",
  #                     ([ "level"    : damage * 2,
  #                            "name"     : "炼狱寒焰",
  #                            "id"       : me->query("id"),
  #                            "duration" : damage / 20 ]));
  # 
  #                 msg += WHT "霎时间$n" WHT "忽觉一股奇寒散入七经八脉"
  #                        "，仿佛连血液都停止了流动。\n" NOR;
  #         }
  #         return msg;
  # }
  # 
  # string attack6(object me, object target, int damage)
  # {
  # 
  #         string msg;
  # 
  #         msg = HIR "$N" HIR "剑势迅猛之极，令$n" HIR "毫无招架余地，"
  #               "竟镇怯当场，素手待毙。\n" NOR;
  # 
  #         if (! target->query_temp("no_exert")
  #            || ! target->query_temp("no_perform"))
  #         {
  #                 target->set_temp("no_exert", 1);
  #                 target->set_temp("no_perform", 1);
  # 
  #                 msg += WHT "$n" WHT "只感到全身真气涣散，丹元瓦解，似"
  #                        "乎所有的武功竟都消逝殆尽。\n" NOR;
  #         }
  #         return msg;
  # }
  # 
  # string attack7(object me, object target, int damage)
  # {
  # 
  #         string msg;
  # 
  #         msg = HIR "忽然间$n" HIR "感到胸口一阵火热，剑气"
  #                   "已从身体穿过，直飞空中。\n" NOR;
  # 
  #         if (!target->query_temp("no_exert") || !target->query_temp("no_perform"))
  #         {
  #                 target->set_temp("no_exert", 1);
  #                 target->set_temp("no_perform", 1);
  # 
  #                 msg += WHT "$n" WHT "只感到全身真气涣散，丹元瓦解，似"
  #                            "乎所有的武功竟都消逝殆尽。\n" NOR;
  #         }
  #         return msg;
  # }
end
