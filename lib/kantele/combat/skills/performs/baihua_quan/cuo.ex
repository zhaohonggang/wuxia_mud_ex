defmodule Kantele.Combat.Skills.Performs.BaihuaQuan.Cuo do
  @moduledoc """
  perform「百花错乱」（source baihua-quan/cuo.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：unarmed/cuff/strike/claw/hand 任一激发为百花错拳 →
  未持兵器 → neili>=300 → 百花拳>=160 → 目标存活。
  命中判定 `lvl*2/3 - random(lvl)` vs `parry/2`；命中时 `apply/attack` 临时
  加成 `lvl/6`（折算入每击命中），连击数 `10 + random(5)`，前 4 击各有概率
  令目标忙乱 1 回合。攻击方扣 300 内力并忙乱 `1+random(6)`。

  差异（TODO(migrate)）：
  - LPC 的 10~14 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线）折算为
    每击 `level/10` 基础伤害 + 命中判定（`apply/attack` 加成并入）；
  - 命中文案在 .c 中被 `NOR+HIR"鲜血"NOR+HIW` 拆成三段字面量（`+` 阻止
    C 侧 join_adjacent 合并），此处按原样拆为三段，运行时再 `Enum.join` 合一；
  - `living(target)` 门槛未实现，由目标侧 `combat/perform-incoming` 兜底。
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

  @perform_id "baihua-quan/cuo"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "baihua-quan")

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
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

  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp check_gates(character) do
    with :ok <- check_mapped(character),
         :ok <- check_weapon(character),
         :ok <- check_resources(character),
         :ok <- check_levels(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "baihua-quan") < 160 -> {:error, "你的百花错拳还不够纯熟！\n"}
      true -> :ok
    end
  end

  # LPC: unarmed/cuff/strike/claw/hand 五个里「一个都没激发」才失败（&& 连接
  # 的是 != 判断，即全部不等于时才报错）。
  defp check_mapped(character) do
    stats = character.meta.stats
    prepared = ~w(unarmed cuff strike claw hand)

    if Enum.any?(prepared, fn key ->
         case Stats.prepared_perform(stats, key) do
           nil -> false
           v -> String.split(v, "/") |> hd() == "baihua-quan"
         end
       end) do
      :ok
    else
      {:error, "你现在没有准备使用百花错拳，无法施展百花错乱！\n"}
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 300 -> {:error, "你的真气不够，无法施展百花错乱。\n"}
      true -> :ok
    end
  end

  defp check_weapon(character) do
    combat = character.meta.combat

    cond do
      Combat.weapon(combat) != nil -> {:error, "百花错乱须是空手才能施展。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # 无条件攻击方效果（C：message_combatd 后 me->add("neili", -300)）
    # start_busy(1 + random(6)) 位于连击之后，由目标侧 feedback 回执。
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 300}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn = Broadcast.publish(conn, "只见$N使出百花错拳的精妙百花错乱，擒拿手中夹着鹰爪功，左手查拳，右手绵掌。攻
出去是八卦掌，收回时已是太极拳，诸家杂陈，毫无规律，只令$n眼花缭乱。\n\n", n1: character.name)

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "百花错乱只能对战斗中的对手使用。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？", n1: attacker.name, n2: character.name)
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    lvl = max(Map.get(data, :level, 0), 1)
    stats = character.meta.stats
    dp = Stats.skill(stats, "dodge")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: i = 10; if (lvl * 2 / 3 - random(lvl) > target->query_skill("parry") / 2)
    #         { ...; i += random(5); } else { ...; count = 0; }
    parry = Stats.skill(stats, "parry")
    landed = div(lvl * 2, 3) - Engine.rand(rng, lvl) > div(parry, 2)
    count = if landed, do: div(lvl, 6), else: 0
    i_count = if landed, do: 10 + Engine.rand(rng, 5), else: 10

    # LPC: while (i--) { if (! is_fighting) break;
    #                     if (i > 5 && ! target->is_busy()) target->start_busy(1);
    #                     COMBAT_D->do_attack(me, target, 0, 0); }
    # 折算：每击 level/10 基础伤害 + 命中判定（apply/attack 加成并入）
    per_hit = max(div(lvl, 10), 1)
    hit_ap = div(lvl, 2) + count

    {damage, _hits, combat} =
      Enum.reduce(i_count - 1..0, {0, 0, character.meta.combat}, fn j, {damage_acc, hit_acc, combat_acc} ->
        combat_acc =
          if j > 5 and combat_acc.busy <= 0 do
            Combat.start_busy(combat_acc, 1)
          else
            combat_acc
          end

        if hit_ap + Engine.rand(rng, lvl) > dp do
          {damage_acc + per_hit + Engine.rand(rng, per_hit), hit_acc + 1, combat_acc}
        else
          {damage_acc, hit_acc, combat_acc}
        end
      end)

    character = %{character | meta: %{character.meta | combat: combat}}

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # 攻击方：连击后 start_busy(1 + random(6))（neili -300 已在 apply_effect 扣除）
    Performs.feedback(attacker, 0, 1 + Engine.rand(rng, 6))

    # 命中/失手各一段（与 .c 一致）；命中文案在 .c 中被颜色宏拆为三段字面量，
    # 此处按原样拆分、运行时再合一。
    msg =
      if landed do
        [
          "$n只感到头晕目眩，只见$N或掌、或爪、或拳、或指铺天盖地的向自己各个部位袭来！\n只一瞬间，全身竟已多了数十出伤痕，",
          "鲜血",
          "狂泻不止！\n"
        ]
        |> Enum.join("")
      else
        "$n只见$N运拳如奔，快拳缤纷递出，连忙振作精神勉强抵挡。\n"
      end

    result = Messages.interpolate(msg, bindings)

    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-300"}], "apply_adds": ["attack"], "assign_refs": [{"count", "baihua-quan"}, {"lvl", "baihua-quan"}], "busy_lines": ["if (i > 5 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(6));"], "level_gates": [{"baihua-quan", "160"}], "prepared_gates": [{"claw", "baihua-quan"}, {"cuff", "baihua-quan"}, {"hand", "baihua-quan"}, {"strike", "baihua-quan"}, {"unarmed", "baihua-quan"}], "remote_damage": false, "resource_gates": [{"neili", "300"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
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
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("百花错乱只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "baihua-quan" &&
  #             me->query_skill_prepared("cuff") != "baihua-quan" &&
  #             me->query_skill_prepared("strike") != "baihua-quan" &&
  #             me->query_skill_prepared("claw") != "baihua-quan" &&
  #             me->query_skill_prepared("hand") != "baihua-quan")
  #                 return notify_fail("你现在没有准备使用百花错拳，无法施展百花错乱！\n");
  #  
  #         if (me->query_temp("weapon"))
  #                 return notify_fail("百花错乱须是空手才能施展。\n");
  # 
  #         if (me->query("neili") < 300)
  #                 return notify_fail("你的真气不够，无法施展百花错乱。\n");
  # 
  #         if ((lvl = me->query_skill("baihua-quan", 1)) < 160)
  #                 return notify_fail("你的百花错拳还不够纯熟！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "只见$N使出百花错拳的精妙百花错乱，擒拿手中夹着鹰爪功，左手查拳，右手绵掌。攻\n"
  #                   "出去是八卦掌，收回时已是太极拳，诸家杂陈，毫无规律，只令$n眼花缭乱。\n\n" NOR;
  #         i = 10;
  #         if (lvl * 2 / 3 - random(lvl) > (int)target->query_skill("parry") / 2)
  #         {
  #                 msg += HIW "$n只感到头晕目眩，只见$N或掌、或爪、或拳、或指铺天盖地的向自己各个部位袭来！\n"
  #                            "只一瞬间，全身竟已多了数十出伤痕，"NOR+HIR"鲜血"NOR+HIW"狂泻不止！\n"NOR;
  #                 count = me->query_skill("baihua-quan", 1) / 6;
  #                 me->add_temp("apply/attack", count);
  #                 i += random(5);
  #         } else
  #         {
  #                 msg += HIY "$n只见$N运拳如奔，快拳缤纷递出，连忙振作精神勉强抵挡。\n" NOR;
  #                 count = 0;
  #         }
  # 
  #         message_combatd(msg, me, target);
  #         me->add("neili", -300);
  # 
  #         while (i--)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (i > 5 && ! target->is_busy())
  #                         target->start_busy(1);
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  # 
  #         me->add_temp("apply/attack", -count);
  #         me->start_busy(1 + random(6));
  #         return 1;
  # }
end
