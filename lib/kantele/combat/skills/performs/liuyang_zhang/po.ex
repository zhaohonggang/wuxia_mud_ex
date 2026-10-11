defmodule Kantele.Combat.Skills.Performs.LiuyangZhang.Po do
  @moduledoc """
  perform「破神诀」（source liuyang-zhang/po.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "liuyang-zhang/po"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "liuyang-zhang")
    improve = 0
    n = 0
    m = 0
    ap = (Stats.skill(stats, "force") + Stats.skill(stats, "strike"))
    damage = (ap + Engine.rand(rng, div(ap, 2)))

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
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
      Stats.skill(stats, "bahuang-gong") < 220 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "liuyang-zhang") < 220 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "force") != "bahuang-gong" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      Stats.mapped(stats, "strike") != "liuyang-zhang" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 3500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 800 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 380}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

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
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 380, 1)
    result = Messages.interpolate("$N将八荒六合唯我独尊功提运至极限，全身真气迸发，呼的一掌向$n头顶猛然贯落。
顿时只听“噗”的一声，$N一掌将$n头骨拍得粉碎，脑浆四溅，当即瘫了下去。
( $n受伤过重，已经有如风中残烛，随时都可能断气。)
$n慌忙抵挡，可已然不及，$N掌劲如洪水般涌入体内，接连震断数根肋骨。
:内伤@?", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-380"}], "assign_refs": [{"ap", "force"}, {"dp", "force"}], "busy_lines": ["me->start_busy(1 + random(3));", "me->start_busy(1 + random(4));"], "level_gates": [{"bahuang-gong", "220"}, {"liuyang-zhang", "220"}], "map_gates": [{"force", "bahuang-gong"}, {"strike", "liuyang-zhang"}], "prepared_gates": [{"strike", "liuyang-zhang"}], "remote_damage": true, "resource_gates": [{"max_neili", "3500"}, {"neili", "800"}], "var_gates": [{"damage", "0"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define PO "「" HIR "破神诀" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  # //        object weapon;
  #         int damage;
  #         string msg;
  #         int ap, dp;
  #         //me = this_player();
  # 
  #         float improve;
  #         int lvl, m, n;
  #         string martial;
  #         string *ks;
  #         martial = "strike";
  #         me = this_player();
  # 
  #         if (userp(me) && ! me->query("can_perform/liuyang-zhang/po"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(PO "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(PO "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("bahuang-gong", 1) < 220)
  #                 return notify_fail("你八荒六合唯我独尊功火候不够，难以施展" PO "。\n");
  # 
  #         if ((int)me->query_skill("liuyang-zhang", 1) < 220)
  #                 return notify_fail("你的天山六阳掌不够娴熟，难以施展" PO "。\n");
  # 
  #         if (me->query("max_neili") < 3500)
  #                 return notify_fail("你的内力修为不足，难以施展" PO "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "liuyang-zhang")
  #                 return notify_fail("你没有激发天山六阳掌，难以施展" PO "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "liuyang-zhang")
  #                 return notify_fail("你没有准备天山六阳掌，难以施展" PO "。\n");
  # 
  #         if (me->query_skill_mapped("force") != "bahuang-gong")
  #                 return notify_fail("你没有激发八荒六合唯我独尊功，难以施展" PO "。\n");
  # 
  #         if (me->query("neili") < 800)
  #                 return notify_fail("你现在真气不足，难以施展" PO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "$N" HIR "将八荒六合唯我独尊功提运至极限，全身真气迸发，呼的一掌"
  #               "向$n" HIR "头顶猛然贯落。\n" NOR;
  # 
  #         lvl = to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3));
  #         lvl = lvl * 4 / 5;
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
  #         improve = improve * 4 / 100 / lvl;
  # 
  #         me->add("neili", -380);
  #         ap = me->query_skill("force") + me->query_skill("strike");
  #         dp = target->query_skill("force") + target->query_skill("parry");
  #         ap += ap * improve;
  #         if (me->query("family/family_name") == "灵鹫宫")
  #             ap += ap / 10;
  #         if (target->is_good()) ap += ap / 10;
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = 0;
  #                 if (me->query("max_neili") > target->query("max_neili") * 2)
  #                 {
  #                         msg += HIR "顿时只听“噗”的一声，$N" HIR "一掌将$n"
  #                                HIR "头骨拍得粉碎，脑浆四溅，当即瘫了下去。\n"
  #                                NOR "( $n" RED "受伤过重，已经有如风中残烛，"
  #                                "随时都可能断气。" NOR ")\n";
  #                         damage = -1;
  #                 } else
  #             {
  #             //damage = ap * 2 / 3;
  #                     damage = ap + random(ap / 2);
  # 
  #                     msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 90,
  #                                                HIR "$n" HIR "慌忙抵挡，可已然不及，$N"
  #                                                    HIR "掌劲如洪水般涌入体内，接连震断数根"
  #                                                    "肋骨。\n:内伤@?");
  #             }
  #             me->start_busy(1 + random(3));
  #         } else
  #         {
  #             msg += CYN "$p" CYN "见$P" CYN "掌劲澎湃，决计抵挡不"
  #                        "住，当即身子向后横丈许，躲闪开来。\n" NOR;
  #             me->start_busy(1 + random(4));
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         if (damage < 0)
  #                 target->die(me);
  # 
  #     return 1;
  # }
end
