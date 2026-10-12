defmodule Kantele.Combat.Skills.Performs.BaihuaCuoquan.Hong do
  @moduledoc """
  perform「战神轰天诀」（对照 `kungfu/skill/baihua-cuoquan/hong.c`）

  门槛：空手、baihua-cuoquan>=250、zhanshen-xinjing>=250、max_neili>=5000、
  neili>=800、激发 unarmed 为 baihua-cuoquan 且 force 为 zhanshen-xinjing、
  准备 unarmed 为 baihua-cuoquan、目标存活且战斗中。

  攻击方发 `perform-incoming`；先按拳法/内功（含多技能加成 `improve`）算 ap：
  - 命中且 `max_neili > 2*目标 max_neili`：直接重创致死（`damage = -1` → `target->die`）；
  - 命中否则：`damage = ap*2/3 + random(ap)`；
  - 未命中：无伤害。
  攻击方消耗/忙乱随分支不同（命中重创 100/忙2；命中普通 400/忙4；未命中 150/忙5）。
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

  @perform_id "baihua-cuoquan/hong"
  @move_name "「战神轰天诀」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "baihua-cuoquan")

    # ap = (unarmed + force) * (1 + improve)
    # improve ≈ 取战斗经验等级 lvls，累加前 5 项拳法类技能等级再折算
    lvls = trunc(:math.pow(max(stats.combat_exp, 1) * 10, 1 / 3) * 4 / 5)
    skill_sum =
      stats.skills
      |> Map.values()
      |> Enum.sort(:desc)
      |> Enum.take(5)
      |> Enum.sum()

    improve = skill_sum * 4 / (100 * max(lvls, 1))
    base = Stats.skill(stats, "unarmed") + Stats.skill(stats, "force")
    ap = trunc(base * (1 + improve))
    damage = div(ap * 2, 3) + Engine.rand(rng, ap)

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
          damage: damage,
          attacker_max_neili: character.meta.vitals.max_neili,
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

  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对
  defp check_gates(character) do
    with :ok <- check_weapon(character),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_mapped(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "baihua-cuoquan") < 250 -> {:error, "你的百花错拳不够娴熟，难以施展#{@move_name}。\n"}
      Stats.skill(stats, "zhanshen-xinjing") < 250 -> {:error, "你的战神心经修为不够，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "unarmed") != "baihua-cuoquan" ->
        {:error, "你没有激发百花错拳，难以施展#{@move_name}。\n"}

      Stats.mapped(stats, "force") != "zhanshen-xinjing" ->
        {:error, "你没有激发战神心经，难以施展#{@move_name}。\n"}

      Stats.prepared_perform(stats, "unarmed") == nil or String.split(Stats.prepared_perform(stats, "unarmed"), "/") |> hd() != "baihua-cuoquan" ->
        {:error, "你没有准备百花错拳，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 5000 -> {:error, "你的内力修为不足，难以施展#{@move_name}。\n"}
      vitals.neili < 800 -> {:error, "你的真气不够，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp check_weapon(character) do
    combat = character.meta.combat

    cond do
      Combat.weapon(combat) != nil -> {:error, "#{@move_name}只能空手施展。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # 前置广播：本招无无条件消耗/Busy（消耗与忙乱随命中分支不同，由反馈回传攻击方）
    conn = Broadcast.publish(conn, "$N一声怒嚎，将战神心经提运极至，双拳顿时携着雷霆万钧之势猛贯向$n。", n1: character.name)

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「战神轰天诀」只能对战斗中的对手使用。\n"}
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
    ap = Map.get(data, :ap, 0)
    damage = Map.get(data, :damage, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    attacker_max_neili = Map.get(data, :attacker_max_neili, 0)
    stats = character.meta.stats
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "parry")
    hit = div(ap * 3, 5) + Engine.rand(rng, ap) > dp

    bindings = [n1: attacker.name, n2: character.name]

    if hit do
      # 命中且修为碾压：直接重创致死（LPC damage = -1 → target->die）
      if attacker_max_neili > character.meta.vitals.max_neili * 2 do
        vitals = character.meta.vitals
        vitals = %{vitals | qi: 0}
        character = %{character | meta: %{character.meta | vitals: vitals}}
        Performs.feedback(attacker, 100, 2)

        msg =
          "只见$N一拳轰至，便将$n震得心脉俱碎，仰天喷出一口鲜血，软软瘫倒。\n" <>
            "( $n受伤过重，已经有如风中残烛，随时都可能断气。)\n"

        result = Messages.interpolate(msg, bindings)

        conn
        |> Broadcast.publish(result)
        |> put_character(character)
      else
        vitals = character.meta.vitals
        vitals = Vitals.damage(vitals, :qi, damage)
        character = %{character | meta: %{character.meta | vitals: vitals}}
        Performs.feedback(attacker, 400, 4)

        msg = "结果$p闪避不及，$P的拳力掌劲顿时透体而入，口中鲜血狂喷，连退数步。"
        result = Messages.interpolate(msg, bindings)

        conn
        |> Broadcast.publish(result)
        |> put_character(character)
      end
    else
      Performs.feedback(attacker, 150, 5)
      msg = "可是$p识破了$P这一招，斜斜一跃避开。"
      result = Messages.interpolate(msg, bindings)

      conn
      |> Broadcast.publish(result)
      |> put_character(character)
    end
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-150"}, {"neili", "-400"}], "assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(4);", "me->start_busy(5);"], "level_gates": [{"baihua-cuoquan", "250"}, {"zhanshen-xinjing", "250"}], "map_gates": [{"force", "zhanshen-xinjing"}, {"unarmed", "baihua-cuoquan"}], "prepared_gates": [{"unarmed", "baihua-cuoquan"}], "remote_damage": true, "resource_gates": [{"max_neili", "5000"}, {"neili", "800"}], "var_gates": [{"damage", "0"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define HONG "「" HIY "战神轰天诀" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  # //      object weapon;
  #         int ap, dp, damage;
  #         string msg;
  # 
  #         float improve;
  #         int lvls, m, n;
  #         string martial;
  #         string *ks;
  #         martial = "unarmed";
  # 
  #         if (userp(me) && ! me->query("can_perform/baihua-cuoquan/hong"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(HONG "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(HONG "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("baihua-cuoquan", 1) < 250)
  #                 return notify_fail("你的百花错拳不够娴熟，难以施展" HONG "。\n");
  # 
  #         if ((int)me->query_skill("zhanshen-xinjing", 1) < 250)
  #                 return notify_fail("你的战神心经修为不够，难以施展" HONG "。\n");
  # 
  #         if (me->query("max_neili") < 5000)
  #                 return notify_fail("你的内力修为不足，难以施展" HONG "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "baihua-cuoquan")
  #                 return notify_fail("你没有激发百花错拳，难以施展" HONG "。\n");
  # 
  #         if (me->query_skill_mapped("force") != "zhanshen-xinjing")
  #                 return notify_fail("你没有激发战神心经，难以施展" HONG "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "baihua-cuoquan")
  #                 return notify_fail("你没有准备百花错拳，难以施展" HONG "。\n");
  # 
  #         if (me->query("neili") < 800)
  #                 return notify_fail("你的真气不够，难以施展" HONG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "一声怒嚎，将战神心经提运极至，双拳顿时携着"
  #               "雷霆万钧之势猛贯向$n" HIW "。\n" NOR;
  # 
  #         lvls = to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3));
  #         lvls = lvls * 4 / 5;
  #         ks = keys(me->query_skills(martial));
  #         improve = 0;
  #         n = 0;
  #         //最多给予5个技能的加成
  #         for (m = 0; m < sizeof(ks); m++)
  #         {
  #             if (SKILL_D(ks[m])->valid_enable(martial))
  #             {
  #                 n += 1;
  #                 improve += (int)me->query_skill(ks[m], 1);
  #                 if (n > 4 )
  #                     break;
  #             }
  #         }
  # 
  #         improve = improve * 4 / 100 / lvls;
  # 
  #         ap = me->query_skill("unarmed") +
  #              me->query_skill("force");
  #         ap += ap * improve;
  # 
  #         dp = target->query_skill("parry") +
  #              target->query_skill("dodge");
  # 
  #         if (ap * 3 / 5 + random(ap) > dp)
  #         {
  #                 damage = 0;
  #                 if (me->query("max_neili") > target->query("max_neili") * 2)
  #                 {
  #                     me->start_busy(2);
  #                         me->add("neili", -100);
  #                         msg += HIR "只见$N" HIR "一拳轰至，便将$n" HIR "震得"
  #                                "心脉俱碎，仰天喷出一口鲜血，软软瘫倒。\n" NOR
  #                                "( $n" RED "受伤过重，已经有如风中残烛，随时都"
  #                                "可能断气。" NOR ")\n";
  #                         damage = -1;
  #                 } else
  #                 {
  #                     me->start_busy(4);
  #                     me->add("neili", -400);
  #                     damage = ap * 2 / 3 + random(ap);
  #                     msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 150,
  #                                                HIR "结果$p" HIR "闪避不及，$P" HIR "的"
  #                                                    "拳力掌劲顿时透体而入，口中鲜血狂喷，连"
  #                                                    "退数步。\n" NOR);
  #                 }
  #         } else
  #         {
  #                 me->start_busy(5);
  #                 me->add("neili", -150);
  #                 msg += CYN "可是$p" CYN "识破了$P"
  #                        CYN "这一招，斜斜一跃避开。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         if (damage < 0)
  #                 target->die(me);
  # 
  #         return 1;
  # }
end
