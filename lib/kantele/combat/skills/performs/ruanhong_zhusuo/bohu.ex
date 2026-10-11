defmodule Kantele.Combat.Skills.Performs.RuanhongZhusuo.Bohu do
  @moduledoc """
  perform「搏虎诀」（source ruanhong-zhusuo/bohu.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "ruanhong-zhusuo/bohu"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "ruanhong-zhusuo")
    improve = 0
    n = 0
    m = 0
    ap = (Stats.skill(stats, "whip") + Stats.skill(stats, "force"))
    damage = (div(ap, 4) + Engine.rand(rng, div(ap, 3)))

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
      Stats.skill(stats, "ruanhong-zhusuo") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "whip") != "ruanhong-zhusuo" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 300 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    vitals = %{vitals | neili: vitals.neili - 300}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1)
    combat = Combat.start_busy(combat, 3)
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
    rng = Map.get(data, :rng, &:rand.uniform/1)
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 300, 3)
    result = Messages.interpolate("只听$n一声惨叫，已在$p身上划出数道深可见骨的伤口，皮肉分离，鲜血飞溅，苦不堪言！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-300"}], "assign_refs": [{"ap", "whip"}, {"dp", "force"}], "busy_lines": ["me->start_busy(1);", "me->start_busy(3);"], "level_gates": [{"ruanhong-zhusuo", "150"}], "map_gates": [{"whip", "ruanhong-zhusuo"}], "remote_damage": true, "resource_gates": [{"neili", "300"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // bohu.c 搏虎诀
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define BOHU "「" HIY "搏虎诀" NOR "」"
  # 
  # inherit F_SSERVER;
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
  #         martial = "whip";
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/ruanhong-zhusuo/bohu"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(BOHU "只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #               (string)weapon->query("skill_type") != "whip")
  #                 return notify_fail("你使用的武器不对，无法施展" BOHU "。\n");
  # 
  #         if ((int)me->query_skill("ruanhong-zhusuo", 1) < 150)
  #                 return notify_fail("你的软红蛛索不够娴熟，无法施展" BOHU "。\n");
  # 
  #         if (me->query("neili") < 300)
  #                 return notify_fail("你的真气不够，无法施展" BOHU "。\n");
  # 
  #         if (me->query_skill_mapped("whip") != "ruanhong-zhusuo")
  #                 return notify_fail("你没有激发软红蛛索，无法施展" BOHU "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "一声暴喝，使出「搏虎」诀，手中" + weapon->name() +
  #               HIY "狂舞，漫天鞭影幻作无数小圈，铺天盖地罩向$n" + HIY "！\n" NOR;
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
  #         ap = me->query_skill("whip") + me->query_skill("force");
  #         dp = target->query_skill("force") + target->query_skill("parry");
  # 
  #         ap += ap * improve;
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap / 4 + random(ap / 3);
  #                 me->add("neili", -300);
  #                 me->start_busy(1);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 55,
  #                                            HIR "只听$n" HIR "一声惨叫，" + weapon->name() + HIR
  #                                            "已在$p" + HIR "身上划出数道深可见骨的伤口，皮肉"
  #                                            "分离，鲜血飞溅，苦不堪言！\n" NOR);
  #         } else
  #         {
  #                 me->add("neili", -100);
  #                 me->start_busy(3);
  #                 msg += CYN "可是$p" CYN "运足内力，奋力挡住了"
  #                        CYN "$P" CYN "这神鬼莫测的一击！\n"NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
