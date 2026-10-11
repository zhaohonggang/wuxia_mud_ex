defmodule Kantele.Combat.Skills.Performs.PoyangJian.Long do
  @moduledoc """
  perform「天外玉龙」（source poyang-jian/long.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "poyang-jian/long"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "poyang-jian")
    improve = 0
    n = 0
    m = 0
    neili = 300
    hit_point = 80
    time = (3 + Engine.rand(rng, 4))
    ap = Stats.skill(stats, "sword")
    damage = (div(ap, 2) + Engine.rand(rng, ap))

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
      Stats.skill(stats, "dodge") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "force") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "poyang-jian") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "poyang-jian" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 2700 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 350 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 150}
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
    Performs.feedback(attacker, 150, 1)
    result = Messages.interpolate("$n见此招来势凶猛， 阻挡不及， 顿时被所伤，苦不堪言。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-150"}], "assign_refs": [{"ap", "sword"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(time);", "me->start_busy(1 + random(2));"], "level_gates": [{"dodge", "200"}, {"force", "200"}, {"poyang-jian", "180"}], "map_gates": [{"sword", "poyang-jian"}], "remote_damage": true, "resource_gates": [{"max_neili", "2700"}, {"neili", "350"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define LONG "「" HIC "天外玉龙" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  #         int neili, hit_point, time;
  # 
  #         float improve;
  #         int lvls, m, n;
  #         string martial;
  #         string *ks;
  #         martial = "sword";
  # 
  #         if (userp(me) && ! me->query("can_perform/poyang-jian/long"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(LONG "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" LONG "。\n");
  # 
  #         if (me->query_skill("force") < 200)
  #                 return notify_fail("你的内功的修为不够，难以施展" LONG "。\n");
  # 
  #         if (me->query_skill("poyang-jian", 1) < 180)
  #                 return notify_fail("你的破阳冷光剑修为不够，难以施展" LONG "。\n");
  # 
  #         if ((int)me->query_skill("dodge") < 200)
  #                 return notify_fail("你的轻功火候不够，难以施展" LONG "。\n");
  # 
  #         if ((int)me->query("max_neili") < 2700)
  #                 return notify_fail("你的内力修为不足，难以施展" LONG "。\n");
  # 
  #         if (me->query("neili") < 350)
  #                 return notify_fail("你的真气不够，难以施展" LONG "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "poyang-jian")
  #                 return notify_fail("你没有激发破阳冷光剑，难以施展" LONG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
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
  #         improve = improve * 5 / 100 / lvls;
  # 
  #         if (! me->query("real_perform/poyang-jian/long"))
  #         {
  #                 msg = HIY "\n只见$N" HIY "手中" + weapon->name() + HIY
  #                       "横扫而出，施出绝招「" HIC "天外玉龙" HIY "」，"
  #                       "剑势纵横，犹如一条长龙蜿蜒而出，刺向$n\n" HIY "。" NOR;
  # 
  #                 neili = 220;
  #                 hit_point = 55;
  #                 time = 2 + random(2);
  #         }
  # 
  #         else
  #         {
  #                 msg = HIW "\n但见$N" HIW "手中" + weapon->name() + HIW
  #                       "自半空中横过，剑身似曲似直，便如一件活物一般，正"
  #                       "是破阳冷光剑的精髓「" HIY "天外玉龙" HIW "」，一"
  #                       "柄死剑被$N" HIW "使得如灵蛇，如神龙，猛然剑刺向$n\n"
  #                       HIW "。" NOR;
  # 
  #                 neili = 300;
  #                 hit_point = 80;
  #                 time = 3 + random(4);
  #         }
  #         message_sort(msg, me, target);
  # 
  #         ap = me->query_skill("sword");
  # 
  #         dp = target->query_skill("parry");
  # 
  #         ap += ap * improve;
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap / 2 + random(ap);
  #                 me->add("neili", -neili);
  #                 me->start_busy(time);
  #                 msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, hit_point,
  #                                            HIR "$n" HIR "见此招来势凶猛， 阻挡不"
  #                                            "及， 顿时被" + weapon->name() + HIR
  #                                            "所伤，苦不堪言。\n" NOR);
  #         } else
  #         {
  #                 me->add("neili", -150);
  #                 me->start_busy(1 + random(2));
  #                 msg = CYN "可却见" CYN "$n" CYN "猛的拔地而起，避开了"
  #                       CYN "$N" CYN "来势凶猛的一招。\n" NOR;
  #         }
  #         message_vision(msg, me, target);
  # 
  #         return 1;
  # }
end
