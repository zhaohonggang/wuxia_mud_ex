defmodule Kantele.Combat.Skills.Performs.LianhuanMizongtui.Lian do
  @moduledoc """
  perform「夺命连环」（source lianhuan-mizongtui/lian.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 连环迷踪腿>=120 →
  双手均未持武器 → 内力上限>=1800 → 内功>=150 → 轻功>=150 →
  准备 unarmed 为连环迷踪腿 → 真气>=200 → 目标存活。
  前置广播后攻击方扣 150 真气；命中判定 `random(轻功+拳脚)` > 目标 `parry`，
  命中则 apply/attack 的 lvl/5 加成折入每击伤害；连续 `do_attack` 5 击，
  收招忙乱 `random(5)`。

  差异（TODO(migrate)）：
  - LPC 的 5 次 `COMBAT_D->do_attack` 折算为每击 `level/15`（+命中分支 lvl/5）
    基础伤害 + 命中判定 `level/2 + random(level)` vs 目标 `dodge`
    （同 chongyang-shenzhang/lian、lanhua-shou/fei）；
  - 命中分支 `add_temp("apply/attack", count)` … `add_temp(-count)` 的临时
    加成折入每击伤害，不落攻击方 temp（避免残留 buff）；
  - 命中判定 `random(dodge+unarmed) > 目标 parry` 需读目标招架，在目标侧结算。
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

  @perform_id "lianhuan-mizongtui/lian"
  @move_name "「夺命连环」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "lianhuan-mizongtui")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_levels(character),
         :ok <- check_weapon(combat),
         :ok <- check_max_neili(character),
         :ok <- check_force(character),
         :ok <- check_dodge(character),
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
          # LPC: random(me->query_skill("dodge") + me->query_skill("unarmed"))
          attack_sum: Stats.skill(stats, "dodge") + Stats.skill(stats, "unarmed"),
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

  # LPC: if ((lvl = me->query_skill("lianhuan-mizongtui", 1)) < 120)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "lianhuan-mizongtui") < 120 do
      {:error, "你的连环迷踪腿不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  defp check_weapon(combat) do
    if Combat.weapon(combat) != nil or
         Map.get(combat.equipped, :secondary_weapon) != nil do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("max_neili") < 1800)
  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 1800 do
      {:error, "你的内力的修为不够，现在无法使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("force") < 150)
  defp check_force(character) do
    if Stats.skill(character.meta.stats, "force") < 150 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("dodge") < 150)
  defp check_dodge(character) do
    if Stats.skill(character.meta.stats, "dodge") < 150 do
      {:error, "你的轻功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("unarmed") != "lianhuan-mizongtui")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "unarmed")

    if prepared == nil or hd(String.split(prepared, "/")) != "lianhuan-mizongtui" do
      {:error, "你现在没有准备使用连环迷踪腿，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili", 1) < 200)
  defp check_resources(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在真气太弱，难以施展#{@move_name}。\n"}
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
    # LPC: msg = HIW "陡见$N" HIW "全身飞速旋转，双腿忽前忽后，接连贯出数腿，
    #               流星般疾射$n" HIW "胸口。\n" NOR;
    #      me->add("neili", -150);
    # 命中分支文案与连击伤害在目标侧结算。
    vitals = character.meta.vitals
    vitals = %{vitals | neili: max(vitals.neili - 150, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn =
      Broadcast.publish(
        conn,
        "陡见$N全身飞速旋转，双腿忽前忽后，接连贯出数腿，流星般疾射$n胸口。\n",
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
    attack_sum = max(Map.get(data, :attack_sum, 0), 1)
    stats = character.meta.stats
    dp = Stats.skill(stats, "parry")
    dodge = Stats.skill(stats, "dodge")

    # LPC: if (random(me->query_skill("dodge") + me->query_skill("unarmed")) >
    #            target->query_skill("parry")) 命中 → count = lvl / 5 加成
    hit? = Engine.rand(rng, attack_sum) > dp
    count = if hit?, do: div(level, 5), else: 0
    per_hit = max(div(level, 15), 1) + count

    # LPC: for (i = 0; i < 5; i++) { if (! me->is_fighting(target)) break;
    #         COMBAT_D->do_attack(me, target, 0, 0); }
    damage =
      Enum.reduce(1..5, 0, fn _, damage_acc ->
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

    # LPC: me->start_busy(random(5))（收招后，位于连击之后）
    Performs.feedback(attacker, 0, Engine.rand(rng, 5))

    msg =
      if hit? do
        "$n顿时觉得眼花缭乱，无数条腿向自己奔来，只得拼命运动抵挡。\n"
      else
        "可是$n凝神顿气，奋力抵挡，丝毫不受腿影的干扰，。\n"
      end

    conn
    |> Broadcast.publish(msg, n1: attacker.name, n2: character.name)
    |> put_character(character)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define LIAN "「" HIW "夺命连环" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int count;
  #         int lvl;
  #         int i;
  # 
  #         if (userp(me) && ! me->query("can_perform/lianhuan-mizongtui/lian"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(LIAN "只能对战斗中的对手使用。\n");
  # 
  #         if ((lvl = (int)me->query_skill("lianhuan-mizongtui", 1)) < 120)
  #                 return notify_fail("你的连环迷踪腿不够娴熟，难以施展" LIAN "。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(LIAN "只能空手施展。\n");
  #                 
  #         if (me->query("max_neili") < 1800)
  #                 return notify_fail("你的内力的修为不够，现在无法使用" LIAN "。\n");
  # 
  #         if ((int)me->query_skill("force") < 150)
  #                 return notify_fail("你的内功火候不够，难以施展" LIAN "。\n");
  # 
  #         if ((int)me->query_skill("dodge") < 150)
  #                 return notify_fail("你的轻功火候不够，难以施展" LIAN "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "lianhuan-mizongtui")
  #                 return notify_fail("你现在没有准备使用连环迷踪腿，难以施展" LIAN "。\n");
  # 
  #         if ((int)me->query("neili", 1) < 200)
  #                 return notify_fail("你现在真气太弱，难以施展" LIAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "陡见$N" HIW "全身飞速旋转，双腿忽前忽后，接连贯出数腿，流星般疾射$n"
  #               HIW "胸口。\n" NOR;
  # 
  #         me->add("neili", -150);
  # 
  #         if (random(me->query_skill("dodge") + me->query_skill("unarmed")) >
  #             target->query_skill("parry"))
  #         {
  #                 msg += HIR "$n" HIR "顿时觉得眼花缭乱，无数条腿"
  #                        "向自己奔来，只得拼命运动抵挡。\n" NOR;
  #                 count = lvl / 5;
  #                 me->add_temp("apply/attack", count);
  #         } else
  #         {
  #                 msg += HIC "可是$n" HIC "凝神顿气，奋力抵挡，丝"
  #                        "毫不受腿影的干扰，。\n" NOR;
  #                 count = 0;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         for (i = 0; i < 5; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  #         me->start_busy(random(5));
  #         me->add_temp("apply/attack", -count);
  #         return 1;
  # }
end
