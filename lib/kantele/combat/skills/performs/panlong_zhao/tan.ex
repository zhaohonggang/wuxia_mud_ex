defmodule Kantele.Combat.Skills.Performs.PanlongZhao.Tan do
  @moduledoc """
  perform「云中探爪」（source panlong-zhao/tan.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "panlong-zhao/tan"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "panlong-zhao")
    skill = Stats.skill(stats, "panlong-zhao")
    ap = Stats.skill(stats, "claw")
    damage = ((60 + div(ap, 3)) + Engine.rand(rng, div(ap, 3)))

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
    with :ok <- check_mapped(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "claw") != "panlong-zhao" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
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
    vitals = %{vitals | neili: vitals.neili - 150}
    vitals = %{vitals | neili: vitals.neili - 50}
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
    Performs.feedback(attacker, 50, 3)
    result = Messages.interpolate("$p面对$P这电光火石般的双抓，更本无从招架，登时被抓得血肉飞溅！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-150"}, {"neili", "-50"}], "assign_refs": [{"ap", "claw"}, {"dp", "parry"}, {"skill", "panlong-zhao"}], "busy_lines": ["me->start_busy(1);", "me->start_busy(3);"], "map_gates": [{"claw", "panlong-zhao"}], "prepared_gates": [{"claw", "panlong-zhao"}], "remote_damage": true, "resource_gates": [{"neili", "200"}], "var_gates": [{"skill", "130"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define TAN "「" HIW "云中探爪" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me)
  # {
  #         string msg;
  #         object target;
  #         int skill, ap, dp, damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/panlong-zhao/tan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(TAN "只能在战斗中对对手使用。\n");
  # 
  #         if (objectp(me->query_temp("weapon")))
  #                 return notify_fail("你必须空手才能使用" TAN "。\n");
  # 
  #         skill = me->query_skill("panlong-zhao", 1);
  # 
  #         if (skill < 130)
  #                 return notify_fail("你的越空盘龙爪等级不够，难以施展" TAN "。\n");
  # 
  #         if (me->query_skill_mapped("claw") != "panlong-zhao")
  #                 return notify_fail("你没有激发越空盘龙爪，难以施展" TAN "。\n");
  # 
  #         if (me->query_skill_prepared("claw") != "panlong-zhao")
  #                 return notify_fail("你没有准备越空盘龙爪，难以施展" TAN "。\n");
  # 
  #         if (me->query("neili") < 200)
  #                 return notify_fail("你的真气不够，难以施展" TAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "伸出两掌，朝$n" HIW "拍去，待掌至中途，却变掌为爪，幻作两"
  #               "道金光袭向$n" HIW "各处要脉！\n" NOR;
  # 
  #         ap = me->query_skill("claw");
  #         dp = target->query_skill("parry");
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 me->add("neili", -150);
  #                 damage = 60 + ap / 3 + random(ap / 3);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 45,
  #                                            HIR "$p" HIR "面对$P" HIR "这电光火石般"
  #                                            "的双抓，更本无从招架，登时被抓得血肉飞"
  #                                            "溅！\n" NOR);
  #                 me->start_busy(1);
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "的看破了$P" CYN
  #                        "的招式，巧妙的招架开来，没露半点破绽！\n" NOR;
  #                 me->add("neili",-50);
  #                 me->start_busy(3);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
