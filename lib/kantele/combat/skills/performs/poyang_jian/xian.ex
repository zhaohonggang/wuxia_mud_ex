defmodule Kantele.Combat.Skills.Performs.PoyangJian.Xian do
  @moduledoc """
  perform「神光再现」（对照 `kungfu/skill/poyang-jian/xian.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 武器为 sword →
  **目标未忙乱** → 破阳冷光剑>=120 → 激发 sword 为破阳冷光剑 →
  内功>=200 → 真气>=150 → 目标存活。
  起手广播（带武器名）后无条件扣 120 真气（`me->add("neili", -120)`
  在分支之外，直接在 apply_effect 结算）；随后由目标侧判定
  `level/2 + random(level) > 目标轻功`：命中则攻击方忙乱 1、
  目标忙乱 `level/26 + 2`；未命中则攻击方忙乱 2。

  差异（TODO(migrate)）：
  - 目标忙乱门槛（`target->is_busy()`）与目标侧忙乱设置都在目标侧结算
    （目标 ref 无 combat，攻击方不可查），命中后的目标忙乱经
    `Combat.start_busy/2` 施加，攻击方忙乱经
    `Performs.feedback(attacker, 0, busy)` 回授；
  - `.c` 起手与分支文案分两次发布（`message_sort` + `message_vision`）；
    E 侧同样拆两处——起手在攻击方发布，命中/未命中文案在目标侧发布
    （判定需目标轻功）；
  - `.c` 起手文案里的 `+ weapon->name() +` 为两段字面量拆段，E 侧写
    `"…手中" <> weapon_name <> "光芒瀑涨…"`（不合并成单段）；
  - `.c` 起手文案以 `\n` 开头、尾段含 `\n` 再接句号（.c 原文如此，逐字保留）；
  - 目标忙乱文案以目标名字开头（`target->name() + "目前正自顾不暇…"`），
    目标侧以自身名字前缀拼接；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧
    `combat/perform-incoming` 的死亡检查兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs

  @perform_id "poyang-jian/xian"
  @move_name "「神光再现」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: level = me->query_skill("poyang-jian", 1);
    #      （命中判定与目标忙乱都要用，经 event data 传给目标侧）
    level = Stats.skill(stats, "poyang-jian")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: level,
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

  # LPC: if (userp(me) && ! me->query("can_perform/poyang-jian/xian"))
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

  # LPC: level = me->query_skill("poyang-jian", 1);
  #      if (level < 120)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "poyang-jian") < 120 do
      {:error, "你破阳冷光剑不够娴熟，难以施展#{@move_name}。\n"}
    else
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

  # LPC: if ((int)me->query_skill("force") < 200)
  #      if (me->query("neili") < 150)
  defp check_resources(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 200 ->
        {:error, "你的内功火候不足，难以施展#{@move_name}。\n"}

      character.meta.vitals.neili < 150 ->
        {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
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

  # LPC: msg = HIG "\n$N" HIG "长啸一声，使出破阳冷光剑绝招「" HIY "神光再"
  #            "现" HIG "」，手中" + weapon->name() + HIG "光芒瀑涨，刺眼"
  #            "眩目，犹如神光降世，刹那间只觉得天地为之失辉，光芒已"
  #            "盖向$n\n" HIG "。" NOR;
  #      message_sort(msg, me, target);
  #      me->add("neili", -120);
  #      …分支在目标侧结算…
  defp apply_effect(conn, character, target) do
    conn =
      Broadcast.publish(
        conn,
        "\n$N长啸一声，使出破阳冷光剑绝招「神光再现」，手中" <>
          weapon_name(character.meta.combat) <>
          "光芒瀑涨，刺眼眩目，犹如神光降世，刹那间只觉得天地为之失辉，光芒已盖向$n\n。",
        n1: character.name,
        n2: target.name
      )

    # LPC: me->add("neili", -120);
    vitals = %{character.meta.vitals | neili: max(character.meta.vitals.neili - 120, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  # LPC: if (target->is_busy())
  #      return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 目标忙乱状态只在目标侧可见，故与死亡检查一并在此结算。
  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    cond do
      character.meta.combat.dead ->
        conn

      Combat.busy?(character.meta.combat) ->
        Broadcast.publish(
          conn,
          "#{character.name}目前正自顾不暇，放胆攻击吧。\n",
          n1: attacker.name,
          n2: character.name
        )

      true ->
        do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: level = me->query_skill("poyang-jian", 1);
    #      if (level / 2 + random(level) > target->query_skill("dodge", 1))
    level = Map.get(data, :level, 0)
    dp = Stats.skill(character.meta.stats, "dodge")

    if div(level, 2) + Engine.rand(rng, level) > dp do
      # LPC: msg = HIR "$n" HIR "被耀眼的光芒所惑，心中惊"
      #            "疑不定，一时间不知如何应对！\n" NOR;
      #      target->start_busy(level / 26 + 2);
      #      me->start_busy(1);
      combat = Combat.start_busy(character.meta.combat, div(level, 26) + 2)
      character = %{character | meta: %{character.meta | combat: combat}}

      Performs.feedback(attacker, 0, 1)

      conn
      |> Broadcast.publish(
        "$n被耀眼的光芒所惑，心中惊疑不定，一时间不知如何应对！\n",
        bindings
      )
      |> put_character(character)
    else
      # LPC: msg = CYN "可是$n" CYN "看破了$N"
      #             CYN "的企图，一丝不乱，应对自若。\n" NOR;
      #      me->start_busy(2);
      Performs.feedback(attacker, 0, 2)

      conn
      |> Broadcast.publish("可是$n看破了$N的企图，一丝不乱，应对自若。\n", bindings)
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define XIAN "「" HIY "神光再现" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         object weapon;
  #         int level;
  # 
  #         if (userp(me) && ! me->query("can_perform/poyang-jian/xian"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(XIAN "只能对战斗中的对手使用。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" XIAN "。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #         level = me->query_skill("poyang-jian", 1);
  # 
  #         if (level < 120)
  #         return notify_fail("你破阳冷光剑不够娴熟，难以施展" XIAN "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "poyang-jian")
  #                 return notify_fail("你没有激发破阳冷光剑，难以施展" XIAN "。\n");
  # 
  #     if ((int)me->query_skill("force") < 200)
  #         return notify_fail("你的内功火候不足，难以施展" XIAN "。\n");
  # 
  #         if (me->query("neili") < 150)
  #                 return notify_fail("你现在的真气不够，难以施展" XIAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  # 
  #     msg = HIG "\n$N" HIG "长啸一声，使出破阳冷光剑绝招「" HIY "神光再"
  #               "现" HIG "」，手中" + weapon->name() + HIG "光芒瀑涨，刺眼"
  #               "眩目，犹如神光降世，刹那间只觉得天地为之失辉，光芒已盖"
  #               "向$n\n" HIG "。" NOR;
  #         message_sort(msg, me, target);
  # 
  #         me->add("neili", -120);
  #         if (level / 2 + random(level) > target->query_skill("dodge", 1))
  #         {
  #         msg = HIR "$n" HIR "被耀眼的光芒所惑，心中惊"
  #                       "疑不定，一时间不知如何应对！\n" NOR;
  #                 target->start_busy(level / 26 + 2);
  #                 me->start_busy(1);
  #     } else
  #         {
  #         msg = CYN "可是$n" CYN "看破了$N"
  #                       CYN "的企图，一丝不乱，应对自若。\n" NOR;
  #                 me->start_busy(2);
  #     }
  #     message_vision(msg, me, target);
  # 
  #     return 1;
  # }
end
