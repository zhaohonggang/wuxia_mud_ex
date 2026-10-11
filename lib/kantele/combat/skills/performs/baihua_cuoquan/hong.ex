defmodule Kantele.Combat.Skills.Performs.BaihuaCuoquan.Hong do
  @moduledoc """
  perform「战神轰天诀」（source baihua-cuoquan/hong.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
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

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "baihua-cuoquan")
    improve = 0
    n = 0
    m = 0
    damage = (-1)

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          damage: damage,
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
    with :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "baihua-cuoquan") < 250 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "zhanshen-xinjing") < 250 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "force") != "zhanshen-xinjing" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "unarmed") != "baihua-cuoquan" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 5000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 800 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    vitals = %{vitals | neili: vitals.neili - 150}
    vitals = %{vitals | neili: vitals.neili - 400}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
    combat = Combat.start_busy(combat, 4)
    combat = Combat.start_busy(combat, 5)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "这里没有可供攻击的对手。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    _stats = character.meta.stats
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 400, 5)
    result = Messages.interpolate("只见$N一拳轰至，便将$n震得心脉俱碎，仰天喷出一口鲜血，软软瘫倒。
( $n受伤过重，已经有如风中残烛，随时都可能断气。)
结果$p闪避不及，$P的拳力掌劲顿时透体而入，口中鲜血狂喷，连退数步。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
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
