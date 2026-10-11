defmodule Kantele.Combat.Skills.Performs.LuoyingShenzhang.Zhuan do
  @moduledoc """
  perform「奇门五转」（source luoying-shenzhang/zhuan.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "luoying-shenzhang/zhuan"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "luoying-shenzhang")

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
      Stats.skill(stats, "force") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "luoying-shenzhang") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "qimen-wuxing") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "luoying-shenzhang" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
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
    vitals = %{vitals | neili: vitals.neili - 150}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
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
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 150, 3)
    result = Messages.interpolate("$n大吃一惊，登时接连中掌，狂喷出一口鲜血，身子急转个不停。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-150"}], "assign_refs": [{"ap", "luoying-shenzhang"}, {"damage", "force"}, {"dp", "dodge"}], "busy_lines": ["target->start_busy(2 + random(3));", "me->start_busy(2);", "me->start_busy(3);"], "level_gates": [{"force", "180"}, {"luoying-shenzhang", "120"}, {"qimen-wuxing", "120"}], "map_gates": [{"strike", "luoying-shenzhang"}], "prepared_gates": [{"strike", "luoying-shenzhang"}], "remote_damage": true, "resource_gates": [{"neili", "300"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHUAN "「" HIY "奇门五转" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/luoying-shenzhang/zhuan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHUAN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(ZHUAN "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("luoying-shenzhang", 1) < 120)
  #                 return notify_fail("你的落英神剑掌不够娴熟，难以施展" ZHUAN "。\n");
  # 
  #         if ((int)me->query_skill("qimen-wuxing", 1) < 120)
  #                 return notify_fail("你对奇门五行的研究不够，难以施展" ZHUAN "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "luoying-shenzhang")
  #                 return notify_fail("你没有激发落英神剑掌，难以施展" ZHUAN "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "luoying-shenzhang")
  #                 return notify_fail("你没有准备落英神剑掌，难以施展" ZHUAN "。\n");
  # 
  #         if ((int)me->query_skill("force") < 180)
  #                 return notify_fail("你的内功火候不足，难以施展" ZHUAN "。\n");
  # 
  #         if ((int)me->query("neili") < 300)
  #                 return notify_fail("你现在的内力不够，难以施展" ZHUAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "掌势陡然一变，施出落英神剑掌「奇门五转」绝技，虚虚"
  #               "实实的攻向$n" HIY "。\n" NOR;
  # 
  #         ap = (int)me->query_skill("luoying-shenzhang", 1) +
  #              (int)me->query_skill("qimen-wuxing", 1) +
  #              (int)me->query_skill("force") +
  #              (int)me->query("int") * 10;
  # 
  #         dp = (int)target->query_skill("dodge") +
  #              (int)target->query_skill("parry") +
  #              (int)target->query_skill("qimen-wuxing", 1) +
  #              (int)target->query("int") * 10;
  # 
  #         me->add("neili", -150);
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 target->start_busy(2 + random(3));
  #             me->start_busy(2);
  #                 damage = (int)me->query_skill("force") + (int)me->query_skill("strike");
  #                 damage = damage / 4;
  #                 damage += random(damage);
  # 
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
  #                                            HIR "$n" HIR "大吃一惊，登时接连中掌，"
  #                                            "狂喷出一口鲜血，身子急转个不停。\n" NOR);
  #         } else
  #     {
  #             me->start_busy(3);
  #                 msg += HIC "可是$p" HIC "看破了$P" HIC "的企图，连消带打，避开了$P"
  #                        HIC "这一击。\n"NOR;
  #     }
  #         message_vision(msg, me, target);
  #         return 1;
  # }
end
