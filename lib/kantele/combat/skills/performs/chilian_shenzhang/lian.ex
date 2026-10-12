defmodule Kantele.Combat.Skills.Performs.ChilianShenzhang.Lian do
  @moduledoc """
  perform「赤心连环决」（source chilian-shenzhang/lian.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 未持兵器 → 赤练神掌>=100 →
  准备 strike 招式 → 内功>=100 → 真气>=200 → 目标存活。
  前置广播后判定 `random(strike) > parry/2`：命中则挂 `apply/attack` +70，
  连出 attack_time 击，结束后撤除；攻击方扣 `attack_time*20` 真气并忙乱
  `1+random(attack_time)`。

  差异（TODO(migrate)）：
  - LPC 的 attack_time 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线）
    折算为每击 `level/10` 基础伤害 + 命中判定（命中文档的 `apply/attack` +70
    并入每击命中基数）；
  - `.c` 的 `int attack_time;` **未初始化**即 `attack_time += 4 + random(ap/40)`，
    属未定义行为；这里按初值 0 处理，即 `attack_time = 4 + random(ap/40)`，
    再按 `.c` 的 `if (attack_time > 8) attack_time = 8` 截顶；
  - `me->query_temp("secondary_weapon")` 副兵器检查未实现；
  - `.c` 首句用 `message_sort`、次句用 `message_vision`，本引擎统一走
    `Broadcast.publish`。
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
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "chilian-shenzhang/lian"
  @move_name "「赤心连环决」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "chilian-shenzhang")
    # LPC: ap = me->query_skill("strike")
    ap = Stats.skill(stats, "strike")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(character),
         :ok <- check_levels(character),
         :ok <- check_prepared(character),
         :ok <- check_force(character),
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

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  defp check_weapon(character) do
    if Combat.weapon(character.meta.combat) != nil do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    if Stats.skill(stats, "chilian-shenzhang") < 100 do
      {:error, "你赤练神掌不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "chilian-shenzhang")
  defp check_prepared(character) do
    stats = character.meta.stats

    case Stats.prepared_perform(stats, "strike") do
      nil -> {:error, "你没有准备赤练神掌，难以施展#{@move_name}。\n"}
      value ->
        if String.split(value, "/") |> hd() == "chilian-shenzhang" do
          :ok
        else
          {:error, "你没有准备赤练神掌，难以施展#{@move_name}。\n"}
        end
    end
  end

  defp check_force(character) do
    stats = character.meta.stats

    if Stats.skill(stats, "force") < 100 do
      {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    if vitals.neili < 200 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
    else
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

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIC "$N" HIC "暗运内功，但见$N" HIC "双掌微微呈显"
    #              "赤色，陡然连续反转，使出一招「" HIM "赤心连环决" HIC
    #              "」，掌风凌厉，将$n" HIC "笼罩在双掌之中。\n" NOR;
    #      message_sort(msg, me, target);
    # 连击次数/伤害/neili/busy 在目标侧结算（分支判定需要目标 parry）。
    conn =
      Broadcast.publish(
        conn,
        "$N暗运内功，但见$N双掌微微呈显赤色，陡然连续反转，使出一招「赤心连环决」，掌风凌厉，将$n笼罩在双掌之中。\n",
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
    ap = max(Map.get(data, :ap, 0), 1)
    level = max(Map.get(data, :level, 0), 1)
    stats = character.meta.stats
    # LPC: dp = target->query_skill("parry")
    dp = Stats.skill(stats, "parry")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(ap) > dp / 2) 命中 → me->add_temp("apply/attack", 70)
    landed = Engine.rand(rng, ap) > div(dp, 2)
    apply_attack = if landed, do: 70, else: 0

    # LPC: attack_time += 4 + random(ap / 40); if (attack_time > 8) attack_time = 8;
    # 原 .c 未初始化 attack_time，按初值 0 处理。
    attack_time = min(4 + Engine.rand(rng, max(div(ap, 40), 1)), 8)

    # LPC: for (i = 0; i < attack_time; i++) COMBAT_D->do_attack(me, target, 0, 0);
    # 折算：每击 level/10 基础伤害 + 命中判定（命中文档的 apply/attack +70 并入）
    per_hit = max(div(level, 10), 1)
    hit_ap = div(ap, 2) + apply_attack

    {damage, _hits} =
      Enum.reduce(1..attack_time, {0, 0}, fn _, {damage_acc, hit_acc} ->
        if hit_ap + Engine.rand(rng, ap) > dp do
          {damage_acc + per_hit + Engine.rand(rng, per_hit), hit_acc + 1}
        else
          {damage_acc, hit_acc}
        end
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # 攻击方：add("neili", -attack_time * 20) + start_busy(1 + random(attack_time))
    # LPC 的 add_temp("apply/attack", -70) 随之撤除（折算后不保留该临时加成）。
    Performs.feedback(attacker, attack_time * 20, 1 + Engine.rand(rng, attack_time))

    # 命中/失手各一句（与 .c 一致）
    msg =
      if landed,
        do: "$n心中一惊，却被$N掌风所困，顿时阵脚大乱。\n",
        else: "$n看清$N这几招的来路，但内劲所至，掌风犀利，也只得小心抵挡。\n"

    conn
    |> Broadcast.publish(Messages.interpolate(msg, bindings))
    |> put_character(character)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define LIAN "「" HIM "赤心连环决" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int ap, dp;
  #         int attack_time, i;
  # 
  #         if (! me->query("can_perform/chiilian-shenzhang/lian"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(LIAN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(LIAN "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("chilian-shenzhang", 1) < 100)
  #                 return notify_fail("你赤练神掌不够娴熟，难以施展" LIAN "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "chilian-shenzhang")
  #                 return notify_fail("你没有准备赤练神掌，难以施展" LIAN "。\n");
  # 
  #         if (me->query_skill("force") < 100)
  #                 return notify_fail("你的内功修为不够，难以施展" LIAN "。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不够，难以施展" LIAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         ap = me->query_skill("strike");
  #         dp = target->query_skill("parry");
  # 
  #         msg = HIC "$N" HIC "暗运内功，但见$N" HIC "双掌微微呈显"
  #               "赤色，陡然连续反转，使出一招「" HIM "赤心连环决" HIC
  #               "」，掌风凌厉，将$n" HIC "笼罩在双掌之中。\n" NOR;
  # 
  #         message_sort(msg, me, target);
  # 
  #     if (random(ap) > dp / 2)
  #     {
  #         msg = HIR "$n" HIR "心中一惊，却被$N" HIR "掌"
  #                       "风所困，顿时阵脚大乱。\n" NOR;
  #                 me->add_temp("apply/attack", 70);
  #         } else
  #         {
  #                 msg = HIY "$n" HIY "看清$N" HIY "这几招的来路，但"
  #                       "内劲所至，掌风犀利，也只得小心抵挡。\n" NOR;
  #         }
  #     message_vision(msg, me, target);
  # 
  #         attack_time += 4 + random(ap / 40);
  # 
  #         if (attack_time > 8)
  #                 attack_time = 8;
  # 
  #     me->add("neili", -attack_time * 20);
  # 
  #     for (i = 0; i < attack_time; i++)
  #     {
  #         if (! me->is_fighting(target))
  #             break;
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #     }
  #         me->add_temp("apply/attack", -70);
  #     me->start_busy(1 + random(attack_time));
  # 
  #     return 1;
  # }
end
