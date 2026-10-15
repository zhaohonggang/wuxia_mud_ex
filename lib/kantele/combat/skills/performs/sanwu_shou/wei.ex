defmodule Kantele.Combat.Skills.Performs.SanwuShou.Wei do
  @moduledoc """
  无所不为「wei」（对照 `kungfu/skill/sanwu-shou/wei.c`）

  三无三不手牵制攻击：需持鞭、三无三不手>=70、真气>=100、激发 whip 为三无三不手、
  目标未忙乱且存活。攻击方恒扣 80 真气、忙乱 1；命中判定
  `random(自身combat_exp) > 目标combat_exp/2`：命中令目标忙乱
  `三无三不手/20 + 2` 轮。

  差异（TODO(migrate)）：
  - `.c` 的 `target->is_busy()` 与 `living(target)` 门槛由目标侧
    `combat/perform-incoming` 的 `cond` 兜底（攻击方拿不到目标 meta）；
  - 引子两处插入兵器名，按 `.c` 的 `+` 分段以 `<>` 拼接（变量两侧不会合并）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  @perform_id "sanwu-shou/wei"
  @move_name "「无所不为」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_level(stats),
         :ok <- check_neili(character),
         :ok <- check_mapped(stats) do
      apply_perform(conn, character, target, weapon, stats)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/sanwu-shou/wei"))
  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #           weapon->query("skill_type") != "whip")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "whip" do
      {:ok, weapon}
    else
      # LPC: notify_fail("你的武器不对，无法施展" WEI "\n") —— 句末无句号
      {:error, "你的武器不对，无法施展#{@move_name}\n"}
    end
  end

  # LPC: if (me->query_skill("sanwu-shou", 1) < 70)
  defp check_level(stats) do
    if Stats.skill(stats, "sanwu-shou") < 70 do
      {:error, "你的三无三不手级别不够，无法施展#{@move_name}！\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili") < 100)
  defp check_neili(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你现在真气不够，无法施展#{@move_name}！\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("whip") != "sanwu-shou")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "whip") == "sanwu-shou" do
      :ok
    else
      {:error, "你没有激发三无三不手，无法施展 #{@move_name}！\n"}
    end
  end

  defp apply_perform(conn, character, target, weapon, stats) do
    weapon_name = Map.get(weapon, :name, "")

    # LPC: me->start_busy(1); … me->add("neili", -80);
    #      两处均为无条件效果，直接在攻击方侧落账。
    vitals = %{character.meta.vitals | neili: max(character.meta.vitals.neili - 80, 0)}
    combat = Combat.start_busy(character.meta.combat, 1)
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    # LPC: msg = HIY "\n$N暴喝一声，潜运体内真气，施出绝招「" HIG "无所不为" HIY
    #           "」将" + weapon->name() + HIY "挥舞得呼呼直响，忽左忽右，将$n"
    #           HIY "笼罩在" + weapon->name() + "的攻势之下。" NOR;
    #      me->start_busy(1);
    conn =
      Broadcast.publish(
        conn,
        "\n$N暴喝一声，潜运体内真气，施出绝招「无所不为」将" <>
          weapon_name <>
          "挥舞得呼呼直响，忽左忽右，将$n笼罩在" <> weapon_name <> "的攻势之下。",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        combat_exp: stats.combat_exp || 0,
        level: Stats.skill(stats, "sanwu-shou"),
        rng: &:rand.uniform/1
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    cond do
      character.meta.combat.dead ->
        # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
        Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？\n",
          n1: attacker.name,
          n2: character.name
        )

      character.meta.combat.busy > 0 ->
        # LPC: if (target->is_busy())
        #          return notify_fail(target->name() + "目前正自顾不暇，放" "胆攻击吧。\n");
        Broadcast.publish(conn, "$n目前正自顾不暇，放胆攻击吧。",
          n1: attacker.name,
          n2: character.name
        )

      true ->
        do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(me->query("combat_exp")) > (int)target->query("combat_exp") / 2)
    my_exp = max(Map.get(data, :combat_exp, 0), 1)
    ob_exp = div(stats.combat_exp || 0, 2)
    level = Map.get(data, :level, 0)

    if Engine.rand(rng, my_exp) > ob_exp do
      # LPC: target->start_busy((int)me->query_skill("sanwu-shou") / 20 + 2);
      combat = Combat.start_busy(character.meta.combat, div(level, 20) + 2)
      character = %{character | meta: %{character.meta | combat: combat}}

      # LPC: msg = HIR "$n" HIR "只觉风声萧萧，眼前万千鞭影，顿感"
      #           "手脚无措，惊慌不已。\n" NOR;
      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate(
            "$n只觉风声萧萧，眼前万千鞭影，顿感手脚无措，惊慌不已。\n",
            bindings
          )
        )

      put_character(conn, character)
    else
      # LPC: msg = CYN "可是$p" CYN "看破了$P" CYN "的企图，斜跳躲闪开来。\n" NOR;
      Broadcast.publish(
        conn,
        Messages.interpolate(
          "可是$p看破了$P的企图，斜跳躲闪开来。\n",
          bindings
        )
      )
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "sanwu-shou/wei",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define WEI "「" HIG "无所不为" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/sanwu-shou/wei"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(WEI "只能对战斗中的对手使用。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放"
  #                                    "胆攻击吧。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             weapon->query("skill_type") != "whip")
  #                 return notify_fail("你的武器不对，无法施展" WEI "\n");
  # 
  #         if (me->query_skill("sanwu-shou", 1) < 70)
  #                 return notify_fail("你的三无三不手级别不够，无法施展" WEI "！\n");
  # 
  #         if (me->query("neili") < 100)
  #                 return notify_fail("你现在真气不够，无法施展" WEI "！\n");
  # 
  #         if (me->query_skill_mapped("whip") != "sanwu-shou")
  #                 return notify_fail("你没有激发三无三不手，无法施展 " WEI "！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "\n$N暴喝一声，潜运体内真气，施出绝招「" HIG "无所不为" HIY
  #               "」将" + weapon->name() + HIY "挥舞得呼呼直响，忽左忽右，将$n"
  #               HIY "笼罩在" + weapon->name() + "的攻势之下。" NOR;
  #         me->start_busy(1);
  # 
  #         message_sort(msg, me, target);
  # 
  #         if (random(me->query("combat_exp")) > (int)target->query("combat_exp") / 2)
  #         {
  #                 msg = HIR "$n" HIR "只觉风声萧萧，眼前万千鞭影，顿感"
  #                       "手脚无措，惊慌不已。\n" NOR;
  #                 target->start_busy((int)me->query_skill("sanwu-shou") / 20 + 2);
  #         } else
  #         {
  #                 msg = CYN "可是$p" CYN "看破了$P"
  #                       CYN "的企图，斜跳躲闪开来。\n" NOR;
  #         }
  #         me->add("neili", -80);
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
