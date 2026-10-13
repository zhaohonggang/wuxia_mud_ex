defmodule Kantele.Combat.Skills.Performs.LanhuaShou.Fei do
  @moduledoc """
  perform「影落飞花」（source lanhua-shou/fei.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 未持兵器 → 兰花拂穴手>=140 →
  激发 hand 为兰花拂穴手 → 准备兰花拂穴手 → 真气>=300 → 目标存活。
  前置广播后攻击方扣 150 真气；命中判定 `random(自身招架+手法)` > 目标招架，
  命中则 apply/attack 的 lvl/5 加成折入每击伤害；连续 `do_attack` 6 击，
  收招忙乱 `random(3)`。

  差异（TODO(migrate)）：
  - LPC 的 6 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线）折算为每击
    `level/15`（命中分支另加 lvl/5）基础伤害 + 命中判定 `level/2 + random(level)`
    vs 目标 `dodge`（同 chongyang-shenzhang/lian）；
  - `.c` 的 `me->set_temp("action_flag", af)` 只是把出招位标记为 hand，折算后
    不再需要；命中分支 `add_temp("apply/attack", count)` … `add_temp(-count)`
    的临时加成折入每击伤害，不落攻击方 temp（避免残留 buff）；
  - 命中判定 `random(parry+hand) > 目标 parry` 需读目标招架，在目标侧结算；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧 perform-incoming 的
    死亡检查兜底。
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

  @perform_id "lanhua-shou/fei"
  @move_name "「影落飞花」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "lanhua-shou")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(character),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_prepared(character),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          # LPC: random(me->query_skill("parry") + me->query_skill("hand"))
          parry_sum: Stats.skill(stats, "parry") + Stats.skill(stats, "hand"),
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

  # LPC: if (objectp(me->query_temp("weapon")))
  defp check_weapon(character) do
    if Combat.weapon(character.meta.combat) != nil do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: if ((lvl = me->query_skill("lanhua-shou", 1)) < 140)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "lanhua-shou") < 140 do
      {:error, "你兰花拂穴手不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("hand") != "lanhua-shou")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "hand") == "lanhua-shou" do
      :ok
    else
      {:error, "你没有激发兰花拂穴手，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (! mapp(p = me->query_skill_prepare()) || p["hand"] != "lanhua-shou")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "hand")

    if prepared == nil or hd(String.split(prepared, "/")) != "lanhua-shou" do
      {:error, "你没有准备兰花拂穴手，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 300)
  defp check_resources(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你现在真气不足，难以施展#{@move_name}。\n"}
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
    # LPC: msg = HIC "$N" HIC "微一凝神，…直逼$n" HIC "全身各大要穴。\n" NOR;
    #      message_combatd(msg, me, target);  me->add("neili", -150);
    # 命中分支文案与连击伤害在目标侧结算。
    vitals = character.meta.vitals
    vitals = %{vitals | neili: max(vitals.neili - 150, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn =
      Broadcast.publish(
        conn,
        "$N微一凝神，双手作兰花状疾拂而出，一环环的劲气登时直逼$n全身各大要穴。\n",
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
    level = max(Map.get(data, :level, 0), 1)
    parry_sum = max(Map.get(data, :parry_sum, 0), 1)
    stats = character.meta.stats
    dp = Stats.skill(stats, "parry")
    dodge = Stats.skill(stats, "dodge")

    # LPC: if (random(me->query_skill("parry") + me->query_skill("hand")) >
    #            target->query_skill("parry")) 命中 → count = lvl / 5 加成
    hit? = Engine.rand(rng, parry_sum) > dp
    count = if hit?, do: div(level, 5), else: 0
    per_hit = max(div(level, 15), 1) + count

    # LPC: for (i = 0; i < 6; i++) { if (! me->is_fighting(target)) break;
    #         me->set_temp("action_flag", af); COMBAT_D->do_attack(me, target, 0, 0); }
    damage =
      Enum.reduce(1..6, 0, fn _, damage_acc ->
        if div(level, 2) + Engine.rand(rng, level) > dodge do
          damage_acc + per_hit + Engine.rand(rng, per_hit)
        else
          damage_acc
        end
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: me->start_busy(random(3))（收招后，位于连击之后）
    Performs.feedback(attacker, 0, Engine.rand(rng, 3))

    msg =
      if hit? do
        "$n顿时觉得眼花缭乱，全然分辨不清真伪，只得拼命运动抵挡。\n"
      else
        "可是$n凝神顿气，奋力抵挡，丝毫不受手影的干扰，。\n"
      end

    conn
    |> Broadcast.publish(msg, n1: attacker.name, n2: character.name)
    |> put_character(character)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define FEI "「" HIC "影落飞花" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         mapping p;
  #         int i, af, lvl, count;
  # 
  #         if (userp(me) && ! me->query("can_perform/lanhua-shou/fei"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(FEI "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(me->query_temp("weapon")))
  #                 return notify_fail(FEI "只能空手施展。\n");
  # 
  #         if ((lvl = (int)me->query_skill("lanhua-shou", 1)) < 140)
  #                 return notify_fail("你兰花拂穴手不够娴熟，难以施展" FEI "。\n");
  # 
  #         if (me->query_skill_mapped("hand") != "lanhua-shou")
  #                 return notify_fail("你没有激发兰花拂穴手，难以施展" FEI "。\n");
  # 
  #         if (! mapp(p = me->query_skill_prepare())
  #            || p["hand"] != "lanhua-shou")
  #                 return notify_fail("你没有准备兰花拂穴手，难以施展" FEI "。\n");
  # 
  #         if ((int)me->query("neili") < 300)
  #                 return notify_fail("你现在真气不足，难以施展" FEI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIC "$N" HIC "微一凝神，双手作兰花状疾拂而出，一环环的劲气登时直逼$n"
  #               HIC "全身各大要穴。\n" NOR;
  #         me->add("neili", -150);
  # 
  #         if (random(me->query_skill("parry") + me->query_skill("hand")) >
  #             target->query_skill("parry"))
  #         {
  #                 msg += HIR "$n" HIR "顿时觉得眼花缭乱，全然分辨"
  #                        "不清真伪，只得拼命运动抵挡。\n" NOR;
  #                 count = lvl / 5;
  #                 me->add_temp("apply/attack", count);
  #         } else
  #         {
  #                 msg += HIY "可是$n" HIY "凝神顿气，奋力抵挡，丝"
  #                        "毫不受手影的干扰，。\n" NOR;
  #                 count = 0;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         af = member_array("hand", keys(p));
  # 
  #         for (i = 0; i < 6; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  # 
  #                 me->set_temp("action_flag", af);
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  #         me->start_busy(random(3));
  #         me->add_temp("apply/attack", -count);
  #         return 1;
  # }
end
