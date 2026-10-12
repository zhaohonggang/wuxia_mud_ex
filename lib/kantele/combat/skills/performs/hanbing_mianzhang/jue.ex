defmodule Kantele.Combat.Skills.Performs.HanbingMianzhang.Jue do
  @moduledoc """
  perform「连绵不绝」（source hanbing-mianzhang/jue.c，inherit F_SSERVER）

  门槛（按 `.c` 顺序）：已学此招 → 目标在战斗中 → 空手（主/副兵器皆无）→
  寒冰绵掌>=100 → 激发 `strike` 为寒冰绵掌 → 准备寒冰绵掌 → 真气>=250 →
  目标存活。
  起手广播后按 `ap/2 + random(ap) > 目标 parry`（`ap = strike`）判定，
  命中则本次连击获得 `ap/2` 的攻击加成；连击次数
  `attack_time = min(3 + random(ap/40), 7)`，攻击方扣 `attack_time*30` 真气、
  忙乱 `1 + random(attack_time)`。

  差异（TODO(migrate)）：
  - `attack_time` 在 `.c` 中未初始化（LPC 视为 0），此处按 `0 + 3 + random(ap/40)`
    取值并封顶 7；
  - `.c` 的 `add_temp("apply/attack", count)` / `apply/damage, count/2` 只作用于
    随后的连击、循环结束即原值抵消，故折算为连击命中判定与伤害的加成项
    （`count = ap/2` 仅用于 `do_attack` 折算，作用域与 `.c` 一致）；
  - `COMBAT_D->do_attack(me, target, 0, 0)`（完整 AP/DP/招架/伤害管线）折算为每击
    `ap/10` 基础伤害 + 命中判定 `ap/2 + count + random(ap)` vs 目标 `dodge`
    （同 `guhong_zhang/qian.ex`）；
  - `.c` 循环内的 `if (! target->is_busy() && random(3) == 1) target->start_busy(1)`
    在目标侧结算；
  - `.c` 的 `message_sort` 折算为房间广播；
  - `.c` 未列「是否已学此招」门槛（`can_perform`），本引擎以框架层
    `perform_known?/2` 统一把关（多出的文案不影响对齐）；
  - `living(target)` 门槛在攻击方无 meta 可查，此处保守恒判存活，
    由目标侧 `combat/perform-incoming` 的死亡检查兜底。
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

  @perform_id "hanbing-mianzhang/jue"
  @move_name "「连绵不绝」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    ap = Stats.skill(stats, "strike")
    lvl = Stats.skill(stats, "hanbing-mianzhang")
    # LPC: attack_time += 3 + random(ap / 40); if (attack_time > 7) attack_time = 7;
    attack_time = min(3 + Engine.rand(rng, max(div(ap, 40), 1)), 7)

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_empty_handed(character),
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
          level: lvl,
          skill: lvl,
          ap: ap,
          attack_time: attack_time,
          rng: rng
        }
      })

      apply_effect(conn, character, target, attack_time, rng)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # 框架层「是否已学此招」门槛（.c 未列 `can_perform`，见 moduledoc 差异说明）。
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
  defp check_empty_handed(character) do
    combat = character.meta.combat

    if Combat.occupied?(combat, :weapon) or Combat.occupied?(combat, :secondary_weapon) do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("hanbing-mianzhang", 1) < 100)
  defp check_level(stats) do
    if Stats.skill(stats, "hanbing-mianzhang") < 100 do
      {:error, "你寒冰绵掌不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "hanbing-mianzhang")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "strike") != "hanbing-mianzhang" do
      {:error, "你没有激发寒冰绵掌，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "hanbing-mianzhang")
  defp check_prepared(stats) do
    prepared = Stats.prepared_perform(stats, "strike")

    if is_binary(prepared) and prepared |> String.split("/") |> hd() == "hanbing-mianzhang" do
      :ok
    else
      {:error, "你没有准备寒冰绵掌，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query("neili") < 250)
  defp check_neili(character) do
    if character.meta.vitals.neili < 250 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target))
  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活，
  # 由目标侧 combat/perform-incoming 的死亡检查兜底。
  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target, attack_time, rng) do
    # LPC: msg = HIC "\n$N" HIC "双掌陡然连续拍出，掌风阴寒无比，一招"
    #            "「" HIG "连绵不绝" HIC "」，已连连罩向$n" HIC "。\n" NOR;
    #      message_sort(msg, me, target);
    conn =
      Broadcast.publish(
        conn,
        "\n$N双掌陡然连续拍出，掌风阴寒无比，一招#{@move_name}，已连连罩向$n。\n",
        n1: character.name,
        n2: target.name
      )

    # LPC: me->add("neili", -attack_time * 30);
    #      me->start_busy(1 + random(attack_time));
    vitals = character.meta.vitals
    vitals = %{vitals | neili: max(vitals.neili - attack_time * 30, 0)}
    combat = Combat.start_busy(character.meta.combat, 1 + Engine.rand(rng, attack_time))
    character = %{character | meta: %{character.meta | combat: combat, vitals: vitals}}

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

  defp do_resolve_incoming(conn, character, _attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    attack_time = max(Map.get(data, :attack_time, 1), 1)
    stats = character.meta.stats

    # LPC: dp = target->query_skill("parry");
    #      if (ap / 2 + random(ap) > dp) count = ap / 2; else count = 0;
    # count 即 `.c` 中 add_temp("apply/attack", count) 的本次连击加成。
    count =
      if div(ap, 2) + Engine.rand(rng, ap) > Stats.skill(stats, "parry") do
        div(ap, 2)
      else
        0
      end

    # LPC: for (i = 0; i < attack_time; i++) { if (! me->is_fighting(target)) break;
    #        if (! target->is_busy() && random(3) == 1) target->start_busy(1);
    #        COMBAT_D->do_attack(me, target, 0, 0); }
    # 折算：每击 ap/10 基础伤害 + 命中判定 ap/2 + count + random(ap) vs dodge。
    dodge = Stats.skill(stats, "dodge")
    per_hit = max(div(ap, 10), 1)

    {damage, combat} =
      Enum.reduce(1..attack_time, {0, character.meta.combat}, fn _, {acc, combat} ->
        combat =
          if not Combat.busy?(combat) and Engine.rand(rng, 3) == 1 do
            Combat.start_busy(combat, 1)
          else
            combat
          end

        if div(ap, 2) + count + Engine.rand(rng, ap) > dodge do
          {acc + per_hit + Engine.rand(rng, per_hit), combat}
        else
          {acc, combat}
        end
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | combat: combat, vitals: vitals}}

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define FEI "「" HIG "连绵不绝" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int ap, dp, count;
  #         int attack_time, i;
  # 
  #         if (userp(me) && ! me->query("can_perform/hanbing-mianzhang/jue"))
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
  #         if ((int)me->query_skill("hanbing-mianzhang", 1) < 100)
  #                 return notify_fail("你寒冰绵掌不够娴熟，难以施展" FEI "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "hanbing-mianzhang")
  #                 return notify_fail("你没有激发寒冰绵掌，难以施展" FEI "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "hanbing-mianzhang")
  #                 return notify_fail("你没有准备寒冰绵掌，难以施展" FEI "。\n");
  # 
  #         if ((int)me->query("neili") < 250)
  #                 return notify_fail("你现在的真气不够，难以施展" FEI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         ap = me->query_skill("strike");
  #         dp = target->query_skill("parry");
  # 
  #         msg = HIC "\n$N" HIC "双掌陡然连续拍出，掌风阴寒无比，一招"
  #               "「" HIG "连绵不绝" HIC "」，已连连罩向$n" HIC "。\n" NOR;
  #         message_sort(msg, me, target);
  # 
  #         if (ap / 2 + random(ap) > dp)
  #             count = ap / 2;
  #         else
  #             count = 0;
  # 
  #         attack_time += 3 + random(ap / 40);
  # 
  #         if (attack_time > 7)
  #                 attack_time = 7;
  # 
  #     me->add("neili", -attack_time * 30);
  #         //me->add_temp("apply/attack", 10);
  #         me->add_temp("apply/attack", count);
  #     me->add_temp("apply/damage", count / 2);
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
  #         //me->add_temp("apply/attack", -10);
  #         me->add_temp("apply/attack", -count);
  #     me->add_temp("apply/damage", -count / 2);
  # 
  #     return 1;
  # }
end
