defmodule Kantele.Combat.Skills.Performs.TaijiJian.Zhenwu do
  @moduledoc """
  perform「真武除邪」（source taiji-jian/zhenwu.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "taiji-jian/zhenwu"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "taiji-jian")
    improve = 0
    n = 0
    m = 0
    ap = Stats.skill(stats, "sword")
    damage = (ap + Engine.rand(rng, div(ap, 3)))

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
      Stats.skill(stats, "taiji-jian") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "taiji-jian" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 50}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
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
    ap = Map.get(data, :ap, 0)
    damage = Map.get(data, :damage, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "parry")
    hit = div(ap, 2) + Engine.rand(rng, ap) > dp
    vitals = character.meta.vitals
    if hit do
          vitals = Vitals.damage(vitals, :jing, div(damage, 4))
          vitals = Vitals.wound(vitals, :jing, div(damage, 8))
    end

    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 50, 2)
    result = if hit, do: Messages.interpolate("", n1: attacker.name, n2: character.name), else: Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-50"}], "assign_refs": [{"ap", "sword"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(2);"], "level_gates": [{"taiji-jian", "180"}], "map_gates": [{"sword", "taiji-jian"}], "remote_damage": true, "resource_gates": [{"neili", "200"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHENWU "「" HIY "真武除邪" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # string final(object me, object target, int damage);
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  # 
  #         float improve;
  #         int lvl, m, n;
  #         string martial;
  #         string *ks;
  #         martial = "sword";
  # 
  #         if (userp(me) && ! me->query("can_perform/taiji-jian/zhenwu"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHENWU "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" ZHENWU "。\n");
  # 
  #         if ((int)me->query_skill("taiji-jian", 1) < 180)
  #                 return notify_fail("你的太极剑法不够娴熟，难以施展" ZHENWU "。\n");
  # 
  #         if (me->query("neili") < 200)
  #                 return notify_fail("你现在真气不够，难以施展" ZHENWU "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "taiji-jian")
  #                 return notify_fail("你没有激发太极剑法，难以施展" ZHENWU "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "跨前一步，平平挥出一剑，横扫$n" HIY "而去，毫"
  #               "无半点花巧可言。\n" NOR;
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
  #         improve = improve * 5 / 100 / lvl;
  # 
  #         me->add("neili", -50);
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("parry");
  #         ap += ap * improve;
  #         if (target->is_bad()) ap += ap / 8;
  # 
  #         me->start_busy(2);
  #         if (ap * 3 / 5 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 3);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 85,
  #                                            (: final, me, target, damage :));
  #         } else
  #         {
  #                 msg += HIC "可是$n" HIC "看透$P" HIC "招后更有杀着，镇"
  #                        "定逾恒，全神应对自如。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
  # 
  # string final(object me, object target, int damage)
  # {
  #         target->receive_damage("jing", damage / 4, me);
  #         target->receive_wound("jing", damage / 8, me);
  #         return  HIY "结果$n" HIY "却丝毫未把这招放在眼里，随手应了一招，却见$N"
  #                 HIY "剑势\n忽然一变，气象万千，变幻无穷，极具王者风范！\n" NOR +
  #                 HIR "$n" HIR "顿时惊慌失措，被$P" HIR "这一剑击中要害，鲜血崩流"
  #                 "，惨不忍睹！\n" NOR;
  # }
end
