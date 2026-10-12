defmodule Kantele.Combat.Skills.Performs.FeihuaZhang.Fei do
  @moduledoc """
  perform「掌打飞花」（source feihua-zhang/fei.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 空手 → 飞花掌法>=40 →
  激发 `strike` 为飞花掌法 → 准备飞花掌法 → 真气>=150 → 目标存活。
  起手广播后判定 `random(ap) > dp/2`（`ap = 基本掌法`、`dp = 目标招架`）：
  命中则挂 `apply/attack` +10 并广播"阵脚大乱"，否则广播"也只得小心抵挡"。
  随后连出 `attack_time = min(3 + random(ap/40), 6)` 击，每击 1/3 概率令未忙乱的
  目标忙乱 1 回合；攻击方扣 `attack_time*20` 真气并忙乱 `1 + random(attack_time)`。

  差异（TODO(migrate)）：
  - LPC 的 `COMBAT_D->do_attack(me, target, 0, 0)` 连击（完整 AP/DP/招架/伤害管线）
    折算为每击 `level/10` 基础伤害 + 命中判定（命中文档的 `apply/attack` +10 并入
    每击命中基数，循环结束按 LPC `add_temp("apply/attack", -10)` 自然抵消）；
  - `.c` 未初始化 `attack_time`（LPC 视作 0），故为 `3 + random(ap/40)` 再压回 6；
  - 起手文案各字面量均只被空白分隔，C 侧 join_adjacent 会并为一条，故 .ex 亦为单字面量；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧 `combat/perform-incoming`
    的死亡检查兜底。
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
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "feihua-zhang/fei"
  @move_name "「掌打飞花」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    level = Stats.skill(stats, "feihua-zhang")
    # LPC: ap = me->query_skill("strike");（命中判定基数）
    ap = Stats.skill(stats, "strike")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(character),
         :ok <- check_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_prepared(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: level,
          skill: level,
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

  # LPC: if (userp(me) && ! me->query("can_perform/feihua-zhang/fei"))
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

  # LPC: if ((int)me->query_skill("feihua-zhang", 1) < 40)
  defp check_level(stats) do
    if Stats.skill(stats, "feihua-zhang") < 40 do
      {:error, "你飞花掌法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "feihua-zhang")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "strike") != "feihua-zhang" do
      {:error, "你没有激发飞花掌法，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "feihua-zhang")
  defp check_prepared(stats) do
    case Stats.prepared_perform(stats, "strike") do
      nil ->
        {:error, "你没有准备飞花掌法，难以施展#{@move_name}。\n"}

      value ->
        if String.split(value, "/") |> hd() == "feihua-zhang" do
          :ok
        else
          {:error, "你没有准备飞花掌法，难以施展#{@move_name}。\n"}
        end
    end
  end

  # LPC: if ((int)me->query("neili") < 150)
  defp check_neili(character) do
    if character.meta.vitals.neili < 150 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
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

  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活。
  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  # LPC: msg = HIC "\n$N" HIC "双掌陡然连续拍出，刚中带柔，一招" "「" HIG "掌打飞花"
  #            HIC "」，双掌带风，已将$n" HIC "笼罩在掌风之中。\n" NOR;
  #      message_sort(msg, me, target);
  # 该段各字面量均只被空白分隔，C 侧 join_adjacent 会并为一条，故 .ex 亦为单字面量。
  defp apply_effect(conn, character, target) do
    conn =
      Broadcast.publish(
        conn,
        "\n$N双掌陡然连续拍出，刚中带柔，一招「掌打飞花」，双掌带风，已将$n笼罩在掌风之中。\n",
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
    # LPC: dp = target->query_skill("parry");
    dp = Stats.skill(stats, "parry")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(ap) > dp / 2) 命中 → me->add_temp("apply/attack", 10);
    landed = Engine.rand(rng, ap) > div(dp, 2)
    apply_attack = if landed, do: 10, else: 0

    # LPC: attack_time += 3 + random(ap / 40); if (attack_time > 6) attack_time = 6;
    # `.c` 未初始化 attack_time（LPC 视作 0），故为 3 + random(ap/40) 再压回 6。
    attack_time = min(3 + Engine.rand(rng, div(ap, 40)), 6)

    # LPC: for (i = 0; i < attack_time; i++) {
    #        if (! target->is_busy() && random(3) == 1) target->start_busy(1);
    #        COMBAT_D->do_attack(me, target, 0, 0); }
    # 折算：每击 level/10 基础伤害 + 命中判定（命中文档的 apply/attack +10 并入）。
    per_hit = max(div(level, 10), 1)
    hit_ap = div(ap, 2) + apply_attack

    {combat, damage} =
      Enum.reduce(1..attack_time, {character.meta.combat, 0}, fn _,
                                                                {combat_acc, damage_acc} ->
        combat_acc =
          if not Combat.busy?(combat_acc) and Engine.rand(rng, 3) == 1 do
            Combat.start_busy(combat_acc, 1)
          else
            combat_acc
          end

        if hit_ap + Engine.rand(rng, ap) > dp do
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

    # LPC: me->add("neili", -attack_time * 20); me->start_busy(1 + random(attack_time));
    # LPC 的 add_temp("apply/attack", -10) 随之撤除（折算后不保留该临时加成）。
    Performs.feedback(attacker, attack_time * 20, 1 + Engine.rand(rng, attack_time))

    # LPC: if 命中 → HIR "结果$n" HIR "目不暇接，顿时被$N" HIR "掌" "风所困，顿时阵脚大乱。\n" NOR;
    #      else    → HIY "$n" HIY "看清$N" HIY "这几招的来路，但" "内劲所至，刚柔并济，也只得小心抵挡。\n" NOR;
    #      message_vision(msg, me, target);
    result =
      if landed do
        Messages.interpolate("结果$n目不暇接，顿时被$N掌风所困，顿时阵脚大乱。\n", bindings)
      else
        Messages.interpolate(
          "$n看清$N这几招的来路，但内劲所至，刚柔并济，也只得小心抵挡。\n",
          bindings
        )
      end

    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define FEI "「" HIG "掌打飞花" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int ap, dp;
  #         int attack_time, i;
  # 
  #         if (userp(me) && ! me->query("can_perform/feihua-zhang/fei"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(FEI "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(FEI "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("feihua-zhang", 1) < 40)
  #                 return notify_fail("你飞花掌法不够娴熟，难以施展" FEI "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "feihua-zhang")
  #                 return notify_fail("你没有激发飞花掌法，难以施展" FEI "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "feihua-zhang")
  #                 return notify_fail("你没有准备飞花掌法，难以施展" FEI "。\n");
  # 
  #         if ((int)me->query("neili") < 150)
  #                 return notify_fail("你现在的真气不够，难以施展" FEI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         ap = me->query_skill("strike");
  #         dp = target->query_skill("parry");
  # 
  #         msg = HIC "\n$N" HIC "双掌陡然连续拍出，刚中带柔，一招"
  #               "「" HIG "掌打飞花" HIC "」，双掌带风，已将$n"
  #               HIC "笼罩在掌风之中。\n" NOR;
  #         message_sort(msg, me, target);
  # 
  #     if (random(ap) > dp / 2)
  #     {
  #         msg = HIR "结果$n" HIR "目不暇接，顿时被$N" HIR "掌"
  #                       "风所困，顿时阵脚大乱。\n" NOR;
  #                 me->add_temp("apply/attack", 10);
  #         } else
  #         {
  #                 msg = HIY "$n" HIY "看清$N" HIY "这几招的来路，但"
  #                       "内劲所至，刚柔并济，也只得小心抵挡。\n" NOR;
  #         }
  #     message_vision(msg, me, target);
  # 
  #         attack_time += 3 + random(ap / 40);
  # 
  #         if (attack_time > 6)
  #                 attack_time = 6;
  # 
  #     me->add("neili", -attack_time * 20);
  # 
  #     for (i = 0; i < attack_time; i++)
  #     {
  #         if (! me->is_fighting(target))
  #             break;
  #                 if (! target->is_busy() && random(3) == 1)
  #                         target->start_busy(1);
  # 
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #     }
  #     me->start_busy(1 + random(attack_time));
  #         me->add_temp("apply/attack", -10);
  # 
  #     return 1;
  # }
end
