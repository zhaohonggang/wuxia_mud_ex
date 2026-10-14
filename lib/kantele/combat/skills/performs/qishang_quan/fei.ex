defmodule Kantele.Combat.Skills.Performs.QishangQuan.Fei do
  @moduledoc """
  perform「魂魄飞扬」（对照 `kungfu/skill/qishang-quan/fei.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 七伤拳>=160 → 内功>=160 →
  内力上限>=2200 → 真气>=350 → 准备 cuff 为七伤拳 → 目标存活。
  起手广播后由目标侧判定 `ap/2 + random(ap)` 对 `目标内功 + 目标招架`
  （`ap = 基本拳法 + 基本内功`）：命中则
  `damage = ap + random(ap/2)`、外伤 80、攻击方扣 320 真气并忙乱 2；
  未命中则攻击方扣 180 真气并忙乱 3。两种消耗都依赖命中结果，
  故经 `Performs.feedback(attacker, neili, busy)` 在目标侧回授。

  差异（TODO(migrate)）：
  - `PO` 宏展开后的 `「魂魄飞扬」` 已并入门槛字面量，E 侧直接写全串；
    `.c` 的内功/内力上限两条门槛文案结尾**没有句号**（`…无法施展" PO "\n"`），
    按逐字判据保留原样；
  - 起手与分支文案在 `.c` 里累加进同一 `msg` 后一次 `message_sort`，
    E 侧拆两处：起手在攻击方发布，分支文案在目标侧发布（判定需目标
    内功/招架）；
  - `ap` 由攻击方 `基本拳法 + 基本内功` 组成，经 event data 传入；
  - 分支文案里的 `$p`/`$P` 分别指目标与攻击方
    （`$n/$p → :n2`、`$N/$P → :n1`）；
  - `query_skill_prepared("cuff")` 按引擎约定做绝招 ID 前缀比对
    （`Stats.prepared_perform/2` 返回的是绝招 ID，不是技能名）；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧
    `combat/perform-incoming` 的死亡检查兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Vitals
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs

  @perform_id "qishang-quan/fei"
  @move_name "「魂魄飞扬」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: ap = me->query_skill("cuff") + me->query_skill("force");
    ap = Stats.skill(stats, "cuff") + Stats.skill(stats, "force")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_levels(character),
         :ok <- check_prepared(character),
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

  # LPC: if (userp(me) && ! me->query("can_perform/qishang-quan/fei"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) { me->clean_up_enemy(); target = me->select_opponent(); }
  #      if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("qishang-quan", 1) < 160)
  #      if ((int)me->query_skill("force", 1) < 160)
  #      if (me->query("max_neili") < 2200)
  #      if ((int)me->query("neili") < 350)
  # 注意：.c 的内功与内力上限两条文案结尾没有句号（逐字保留）。
  defp check_levels(character) do
    stats = character.meta.stats
    vitals = character.meta.vitals

    cond do
      Stats.skill(stats, "qishang-quan") < 160 ->
        {:error, "你的七伤拳不够娴熟，无法施展#{@move_name}。\n"}

      Stats.skill(stats, "force") < 160 ->
        {:error, "你的内功修为还不够，无法施展#{@move_name}\n"}

      vitals.max_neili < 2200 ->
        {:error, "你内力修为不足，无法施展#{@move_name}\n"}

      vitals.neili < 350 ->
        {:error, "你现在真气不够，无法施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_prepared("cuff") != "qishang-quan")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "cuff")

    if prepared != nil and hd(String.split(prepared, "/")) == "qishang-quan" do
      :ok
    else
      {:error, "你没有准备使用七伤拳，无法施展#{@move_name}。\n"}
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

  # LPC: msg = HIY "\n$N" HIY "深吸一口起，将真气运于双拳之上，施出绝招「" HIR "魂魄飞扬" HIY
  #              "」，右拳平平一拳直出，但见普通一拳之中蕴涵了无穷的力量，拳未到风先至，猛然"
  #              "间袭向$n" HIY "。\n" NOR;
  #      …命中/失手在目标侧结算（dp 需目标内功 + 招架）…
  defp apply_effect(conn, character, target) do
    conn
    |> Broadcast.publish(
      "\n$N深吸一口起，将真气运于双拳之上，施出绝招「魂魄飞扬」，右拳平平一拳直出，但见普通一拳之中蕴涵了无穷的力量，拳未到风先至，猛然间袭向$n。\n",
      n1: character.name,
      n2: target.name
    )
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
    ap = Map.get(data, :ap, 0)
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("force") + target->query_skill("parry");
    dp = Stats.skill(character.meta.stats, "force") + Stats.skill(character.meta.stats, "parry")

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = ap + random(ap / 2);
      #      me->add("neili", -320);
      #      msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80, HIR "…");
      #      me->start_busy(2);
      damage = ap + Engine.rand(rng, div(ap, 2))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 80, 100))

      Performs.feedback(attacker, 320, 2)

      conn
      |> Broadcast.publish(
        "只听“砰”地一声，$N一拳正好打中$n胸口，$n怪叫一声，吐出一口淤血！\n",
        bindings
      )
      |> put_character(%{character | meta: %{character.meta | vitals: vitals}})
    else
      # LPC: me->add("neili", -180); me->start_busy(3);
      #      msg += HIC "可是$p" HIC "奋力招架，硬生生的挡开了$P"
      #             HIC "这一招。\n"NOR;
      Performs.feedback(attacker, 180, 3)

      conn
      |> Broadcast.publish("可是$p奋力招架，硬生生的挡开了$P这一招。\n", bindings)
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // 伤字诀
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define PO "「" HIR "魂魄飞扬" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #     // object weapon;
  #     int damage;
  #     string msg;
  #   int ap, dp;
  # 
  #   if (! target)
  #   {
  #     me->clean_up_enemy();
  #     target = me->select_opponent();
  #   }
  # 
  #   if (userp(me) && ! me->query("can_perform/qishang-quan/fei"))
  #           return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail(PO "只能对战斗中的对手使用。\n");
  # 
  #     if ((int)me->query_skill("qishang-quan", 1) < 160)
  #         return notify_fail("你的七伤拳不够娴熟，无法施展" PO "。\n");
  # 
  #     if ((int)me->query_skill("force", 1) < 160)
  #         return notify_fail("你的内功修为还不够，无法施展" PO "\n");
  # 
  #         if (me->query("max_neili") < 2200)
  #                 return notify_fail("你内力修为不足，无法施展" PO "\n");
  # 
  #     if ((int)me->query("neili") < 350)
  #         return notify_fail("你现在真气不够，无法施展" PO "。\n");
  # 
  #         if (me->query_skill_prepared("cuff") != "qishang-quan")
  #                 return notify_fail("你没有准备使用七伤拳，无法施展" PO "。\n");
  # 
  #         if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIY "\n$N" HIY "深吸一口起，将真气运于双拳之上，施出绝招「" HIR "魂魄飞扬" HIY
  #               "」，右拳平平一拳直出，但见普通一拳之中蕴涵了无穷的力量，拳未到风先至，猛然"
  #               "间袭向$n" HIY "。\n" NOR;
  # 
  #         ap = me->query_skill("cuff") + me->query_skill("force");
  #         dp = target->query_skill("force") + target->query_skill("parry");
  #     if (ap / 2 + random(ap) > dp)
  #     {
  #         damage = ap + random(ap / 2);
  # 
  #                 me->add("neili", -320);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80,
  #                                    HIR "只听“砰”地一声，$N" HIR "一拳正好打中$n" HIR "胸"
  #                                            "口，$n" HIR "怪叫一声，吐出一口淤血！\n" NOR);
  #         me->start_busy(2);
  #     } else
  #     {
  #         msg += HIC "可是$p" HIC "奋力招架，硬生生的挡开了$P"
  #                        HIC "这一招。\n"NOR;
  #         me->add("neili", -180);
  #         me->start_busy(3);
  #     }
  #     message_sort(msg, me, target);
  # 
  #     return 1;
  # }
end
