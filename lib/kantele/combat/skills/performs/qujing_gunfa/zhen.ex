defmodule Kantele.Combat.Skills.Performs.QujingGunfa.Zhen do
  @moduledoc """
  perform「震雷乾坤」（source qujing-gunfa/zhen.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "qujing-gunfa/zhen"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "qujing-gunfa")
    ap = Stats.skill(stats, "club")
    count = 0
    i = 0

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
      Stats.skill(stats, "force") < 350 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "qujing-gunfa") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "club") != "qujing-gunfa" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "force") != "hunyuan-yiqi" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "force") != "luohan-fumogong" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "force") != "yijinjing" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 4000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.max_neili < 4500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 300 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 200}
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
    Performs.feedback(attacker, 200, 1)
    result = Messages.interpolate("$N将手中缓缓压向$n，棍体隐隐带着风雷之劲，正是取经棍法杀着「震雷乾坤」！
电光火石间，棍端竟全被紫电所笼罩，幻作千百根相似，奔雷掣电般向$n席卷而去。
$n被$N气势所撼，完全不知该如何招架，竟而呆立当场！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}], "apply_adds": ["attack", "damage"], "assign_refs": [{"ap", "club"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(1 + random(9));"], "level_gates": [{"force", "350"}, {"qujing-gunfa", "200"}], "map_gates": [{"club", "qujing-gunfa"}, {"force", "hunyuan-yiqi"}, {"force", "luohan-fumogong"}, {"force", "yijinjing"}], "remote_damage": false, "resource_gates": [{"max_neili", "4000"}, {"max_neili", "4500"}, {"neili", "300"}], "var_gates": [{"i", "10"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHEN "「" HIR "震雷乾坤" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int i, ap, dp, count;
  # 
  #         if (userp(me) && ! me->query("can_perform/qujing-gunfa/zhen"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHEN "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "club")
  #                 return notify_fail("你使用的武器不对，难以施展" ZHEN "。\n");
  #                 
  #         if ((me->query_skill_mapped("force") != "hunyuan-yiqi") && (me->query_skill_mapped("force") != "yijinjing") && (me->query_skill_mapped("force") != "luohan-fumogong")) 
  #                 return notify_fail("你现在没有激发少林内功为内功，难以施展" ZHEN "。\n"); 
  # 
  #         if (me->query_skill_mapped("club") != "qujing-gunfa")
  #                 return notify_fail("你没有激发取经棍法，难以施展" ZHEN "。\n");
  # 
  #         if(me->query_skill("qujing-gunfa", 1) < 200 )
  #                 return notify_fail("你取经棍法不够娴熟，难以施展" ZHEN "。\n");
  # 
  #         if( (int)me->query_skill("force") < 350 )
  #                 return notify_fail("你的内功修为不够，难以施展" ZHEN "。\n");
  # 
  #         //if( (int)me->query("max_neili") < 4500 )
  #         if( (int)me->query("max_neili") < 4000 )
  #                 return notify_fail("你的内力修为太弱，难以施展" ZHEN "。\n");
  # 
  #         if( (int)me->query("neili") < 300 )
  #                 return notify_fail("你现在的真气太弱，难以施展" ZHEN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "将手中" + weapon->name() + HIW "缓缓压向$n"
  #               HIW "，棍体隐隐带着风雷之劲，正是取经棍法杀着「" HIR "震"
  #               "雷乾坤" HIW "」！\n电光火石间，棍端竟全被紫电所笼罩，" +
  #               weapon->name() + HIW "幻作千百根相似，奔雷掣电般向$n" HIW
  #               "席卷而去。\n" NOR;
  # 
  #         ap = me->query_skill("club");
  #         dp = target->query_skill("parry");
  # 
  #         if (ap / 2 + random(ap * 2) > dp)
  #         {
  #                 msg += HIR "$n" HIR "被$N" HIR "气势所撼，完全不知该如"
  #                        "何招架，竟而呆立当场！\n" NOR;
  #                 count = ap / 5;
  #                 me->add_temp("apply/attack", count);
  #                 me->add_temp("apply/damage", count);
  #         } else
  #         {
  #                 msg += HIC "$n" HIC "见$N" HIC "气势如虹，心下凛然，急"
  #                        "忙凝神聚气，小心应付！\n" NOR;
  #                 count = 0;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         me->add("neili", -200);
  # 
  #         for (i = 0; i < 10; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  # 
  #         me->add_temp("apply/attack", -count);
  #         me->add_temp("apply/damage", -count);
  #         me->start_busy(1 + random(9));
  #         return 1;
  # }
end
