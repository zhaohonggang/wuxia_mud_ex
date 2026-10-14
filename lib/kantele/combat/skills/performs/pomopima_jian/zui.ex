defmodule Kantele.Combat.Skills.Performs.PomopimaJian.Zui do
  @moduledoc """
  perform「醉里乾坤」（对照 `kungfu/skill/pomopima-jian/zui.c`）

  门槛（按 .c 顺序）：战斗中的对手 → 已学此招 → 武器为 sword →
  内功>=150 → 泼墨披麻剑>=120 → 真气>=250 → 激发 sword 为泼墨披麻剑 →
  目标存活。
  起手广播（带武器名）后由目标侧单次判定
  `ap/2 + random(ap) > 目标招架`：命中则
  `damage = ap/2 + random(ap/2)`、外伤比例 70、攻击方扣真气 200 并
  `start_busy(2)`；未命中则扣真气 100 并 `start_busy(3)`。
  两种消耗都依赖命中结果，故经 `Performs.feedback(attacker, neili, busy)`
  在目标侧回授。

  差异（TODO(migrate)）：
  - `.c` 起手文案与分支文案累加进同一 `msg` 后一次 `message_combatd`；
    E 侧拆两处——起手在攻击方广播，命中/未命中文案在目标侧广播
    （`dp` 需目标属性）；
  - `.c` 起手文案中 `+ weapon->name() +` 前后有色码 `NOR`/`HIR`，剥色后即为
    `"…手中" + wn + "连划…"` 的拆段，E 侧写 `"…手中" <> weapon_name <> "连划…"`
    （不得合并成单段，否则与 C 侧两段字面量不一致）；
  - `.c` 未命中文案里的 `$p`/`$P` 分别是目标与攻击方（`Messages.interpolate`
    中 `$n/$p → :n2`、`$N/$P → :n1`）；
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

  @perform_id "pomopima-jian/zui"
  @move_name "「醉里乾坤」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: ap = me->query_skill("sword");
    ap = Stats.skill(stats, "sword")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          ap: ap,
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

  # LPC: if (userp(me) && ! me->query("can_perform/pomopima-jian/zui"))
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
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #           (string)weapon->query("skill_type") != "sword")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon != nil and Map.get(weapon, :skill_type) == "sword" do
      :ok
    else
      {:error, "你使用的武器无法施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill("force") < 150)
  #      if (me->query_skill("pomopima-jian", 1) < 120)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功的修为不够，无法施展#{@move_name}。\n"}

      Stats.skill(stats, "pomopima-jian") < 120 ->
        {:error, "你的泼墨披麻剑修为不够，无法施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query("neili") < 250)
  #      if (me->query_skill_mapped("sword") != "pomopima-jian")
  defp check_resources(character) do
    stats = character.meta.stats

    cond do
      character.meta.vitals.neili < 250 ->
        {:error, "你的真气不够，无法施展#{@move_name}。\n"}

      Stats.mapped(stats, "sword") != "pomopima-jian" ->
        {:error, "你没有激发泼墨披麻剑，无法使用#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (! living(target))
  #      return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
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

  # LPC: msg = HIR "$N" HIR "一声长吟，手中" + weapon->name() + NOR + HIR
  #            "连划三个圆圈，幻作三个光圈，便如是有形之物，缓缓向$n" HIR
  #            "身前移去！\n" NOR;
  #      …分支与消耗都在目标侧结算…
  defp apply_effect(conn, character, target) do
    Broadcast.publish(
      conn,
      "$N一声长吟，手中" <>
        weapon_name(character.meta.combat) <>
        "连划三个圆圈，幻作三个光圈，便如是有形之物，缓缓向$n身前移去！\n",
      n1: character.name,
      n2: target.name
    )
  end

  defp weapon_name(combat) do
    case Combat.weapon(combat) do
      nil -> ""
      weapon -> Map.get(weapon, :name)
    end
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
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("parry");
    dp = Stats.skill(character.meta.stats, "parry")

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = ap / 2 + random(ap / 2);
      #      me->add("neili", -200);
      #      me->start_busy(2);
      #      msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 70,
      #                                HIR "$n" HIR "只觉剑气满室，寒风袭体，"
      #                                "微微一楞，已连中三剑，鲜血飞溅！\n" NOR );
      damage = div(ap, 2) + Engine.rand(rng, div(ap, 2))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 70, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      Performs.feedback(attacker, 200, 2)

      conn
      |> Broadcast.publish(
        "$n只觉剑气满室，寒风袭体，微微一楞，已连中三剑，鲜血飞溅！\n",
        bindings
      )
      |> put_character(character)
    else
      # LPC: me->add("neili", -100);
      #      me->start_busy(3);
      #      msg += CYN "可是$p" CYN "见来势迅猛，飞身一跃，"
      #             "闪开了$P" CYN "这凌厉的几剑。\n" NOR;
      Performs.feedback(attacker, 100, 3)

      conn
      |> Broadcast.publish("可是$p见来势迅猛，飞身一跃，闪开了$P这凌厉的几剑。\n", bindings)
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZUI "「" HIR "醉里乾坤" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  #  
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/pomopima-jian/zui"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZUI "只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #               (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器无法施展" ZUI "。\n");
  # 
  #         if (me->query_skill("force") < 150)
  #                 return notify_fail("你的内功的修为不够，无法施展" ZUI "。\n");
  # 
  #         if (me->query_skill("pomopima-jian", 1) < 120)
  #                 return notify_fail("你的泼墨披麻剑修为不够，无法施展" ZUI "。\n");
  # 
  #         if (me->query("neili") < 250)
  #                 return notify_fail("你的真气不够，无法施展" ZUI "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "pomopima-jian") 
  #                 return notify_fail("你没有激发泼墨披麻剑，无法使用" ZUI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "$N" HIR "一声长吟，手中" + weapon->name() + NOR + HIR
  #               "连划三个圆圈，幻作三个光圈，便如是有形之物，缓缓向$n" HIR
  #               "身前移去！\n" NOR;
  # 
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("parry");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap / 2 + random(ap / 2);
  #                 me->add("neili", -200);
  #                 me->start_busy(2);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 70,
  #                                            HIR "$n" HIR "只觉剑气满室，寒风袭体，"
  #                                            "微微一楞，已连中三剑，鲜血飞溅！\n" NOR );
  #         } else
  #         {
  #                 me->add("neili", -100);
  #                 me->start_busy(3);
  #                 msg += CYN "可是$p" CYN "见来势迅猛，飞身一跃，"
  #                        "闪开了$P" CYN "这凌厉的几剑。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
