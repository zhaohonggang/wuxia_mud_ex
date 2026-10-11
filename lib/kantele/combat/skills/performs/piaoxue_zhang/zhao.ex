defmodule Kantele.Combat.Skills.Performs.PiaoxueZhang.Zhao do
  @moduledoc """
  perform「佛光普照」（source piaoxue-zhang/zhao.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "piaoxue-zhang/zhao"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "piaoxue-zhang")

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
      Stats.skill(stats, "force") < 300 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "piaoxue-zhang") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "force") != "emei-jiuyang" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "force") != "jiuyang-shengong" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "force") != "shaolin-jiuyang" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "force") != "wudang-jiuyang" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "strike") != "piaoxue-zhang" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 3500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 1000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 400}
    vitals = %{vitals | neili: vitals.neili - 600}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 3)
    combat = Combat.start_busy(combat, 4)
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
    Performs.feedback(attacker, 600, 4)
    result = Messages.interpolate("只听轰然一声巨响，$n被$N一招正中，身子便如稻草般平平飞出，重
重摔在地下，呕出一大口鲜血，动也不动。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-400"}, {"neili", "-600"}], "assign_refs": [{"ap", "strike"}, {"dp", "dodge"}], "busy_lines": ["me->start_busy(3);", "me->start_busy(3);", "me->start_busy(4);"], "level_gates": [{"force", "300"}, {"piaoxue-zhang", "180"}], "map_gates": [{"force", "emei-jiuyang"}, {"force", "jiuyang-shengong"}, {"force", "shaolin-jiuyang"}, {"force", "wudang-jiuyang"}, {"strike", "piaoxue-zhang"}], "prepared_gates": [{"strike", "piaoxue-zhang"}], "remote_damage": true, "resource_gates": [{"max_neili", "3500"}, {"neili", "1000"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHAO "「" HIY "佛光普照" NOR "」"
  # 
  # inherit F_SSERVER; 
  #          
  # int perform(object me, object target) 
  # { 
  # //      object weapon; 
  #         string msg; 
  #         int ap, dp; 
  #         int damage; 
  # 
  #         if (userp(me) && ! me->query("can_perform/piaoxue-zhang/zhao"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me); 
  #         
  #         if (! target || ! me->is_fighting(target)) 
  #                 return notify_fail(ZHAO "只能在战斗中对对手使用。\n"); 
  #          
  #         if (me->query_temp("weapon") || 
  #             me->query_temp("secondary_weapon")) 
  #                 return notify_fail("你必须空手才能施展" ZHAO "。\n"); 
  #          
  #         if (me->query_skill("force") < 300) 
  #                 return notify_fail("你的内功的修为不够，无法施展" ZHAO "。\n"); 
  #         
  #         if (me->query_skill("piaoxue-zhang", 1) < 180) 
  #                 return notify_fail("你的飘雪穿云掌修为不够，无法施展" ZHAO "。\n"); 
  #          
  #         if (me->query("neili") < 1000 || me->query("max_neili") < 3500) 
  #                 return notify_fail("你的真气不够，无法施展" ZHAO "。\n"); 
  # 
  # /*
  #         if (me->query_skill_mapped("force") != "emei-jiuyang" &&
  #             me->query_skill_mapped("force") != "wudang-jiuyang" &&
  #             me->query_skill_mapped("force") != "shaolin-jiuyang" &&
  #             me->query_skill_mapped("force") != "jiuyang-shengong") 
  #                 return notify_fail("你没有激发内功为九阳神功，无法施展" ZHAO "。\n"); 
  # */
  # 
  #         if (me->query_skill_mapped("strike") != "piaoxue-zhang") 
  #                 return notify_fail("你没有激发飘雪穿云掌，无法施展" ZHAO "。\n"); 
  # 
  #         if (me->query_skill_prepared("strike") != "piaoxue-zhang")
  #                 return notify_fail("你没有准备飘雪穿云掌，无法施展" ZHAO "。\n"); 
  # 
  #         if (! me->query_temp("powerup"))
  #                 return notify_fail("你必须将全身功力尽数提起才能施展" ZHAO "。\n");
  # 
  #         if (! living(target))
  #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "运起全身功力，顿时真气迸发，全身骨骼噼啪作"
  #               "响，猛然一掌向$n" HIY "\n全力拍出，力求一击毙敌，正是一"
  #               "招「佛光普照」。\n" NOR;
  #          
  #         ap = me->query_skill("strike") +
  #              me->query_skill("force") +
  #              me->query("str") * 5;
  # 
  #         dp = target->query_skill("dodge") +
  #              target->query_skill("force") +
  #              target->query("con") * 5;
  # 
  #         //damage = random(ap / 3) + ap / 3;
  #         damage = random(ap / 2) + ap / 2;
  # 
  #         if (target->query_skill_mapped("force") == "jiuyang-shengong")
  #         {
  #                 me->add("neili", -600);
  #                 me->start_busy(3);
  #                 msg += HIW "只听轰然一声巨响，$n" HIW "已被一招正中，可$N"
  #                        HIW "只觉全身内力犹如江河入\n海，又如水乳交融，登"
  #                        "时消失得无影无踪。\n" NOR; 
  #         } else
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 me->add("neili", -600);
  #                 me->start_busy(3);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 100,
  #                                            HIR "只听轰然一声巨响，$n" HIR "被$N"
  #                                            HIR "一招正中，身子便如稻草般平平飞出"
  #                                            "，重\n重摔在地下，呕出一大口鲜血，动"
  #                                            "也不动。\n" NOR);
  #         } else 
  #         { 
  #                 me->add("neili", -400);
  #                 me->start_busy(4);
  #                 msg += CYN "可是$p" CYN "内力深厚，及时摆脱了" 
  #                        CYN "$P" CYN "内力的牵扯，躲开了这一击！\n" NOR; 
  #         }
  #         message_combatd(msg, me, target);
  #        
  #         return 1; 
  # }
end
