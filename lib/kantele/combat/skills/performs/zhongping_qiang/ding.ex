defmodule Kantele.Combat.Skills.Performs.ZhongpingQiang.Ding do
  @moduledoc """
  perform「定岳七方」（source zhongping-qiang/ding.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "zhongping-qiang/ding"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "zhongping-qiang")
    ap = Stats.skill(stats, "club")
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
      Stats.skill(stats, "force") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "zhongping-qiang") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "club") != "zhongping-qiang" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 2000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
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
    result = Messages.interpolate("$N身形一转，施出中平枪法绝技「定岳七方」，手中接连七刺，枪枪不离$n要害！
$n见$N攻势凶猛异常，实非寻常，不由心生寒意，招架登时散乱。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"assign_refs": [{"ap", "club"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(1 + random(7));"], "level_gates": [{"force", "180"}, {"zhongping-qiang", "120"}], "map_gates": [{"club", "zhongping-qiang"}], "remote_damage": false, "resource_gates": [{"max_neili", "2000"}, {"neili", "200"}], "var_gates": [{"i", "7"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define DING "「" HIY "定岳七方" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg;
  #     int i, ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/zhongping-qiang/ding"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #                 return notify_fail(DING "只能对战斗中的对手使用。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "club")
  #                 return notify_fail("你所使用的武器不对，难以施展" DING "。\n");
  # 
  #         if ((int)me->query_skill("zhongping-qiang", 1) < 120)
  #                 return notify_fail("你中平枪法不够娴熟，难以施展" DING "。\n");
  # 
  #         if (me->query_skill_mapped("club") != "zhongping-qiang")
  #                 return notify_fail("你没有激发中平枪法，难以施展" DING "。\n");
  # 
  #         if ((int)me->query_skill("force") < 180 )
  #                 return notify_fail("你的内功火候不够，难以施展" DING "。\n");
  # 
  #         if ((int)me->query("max_neili") < 2000)
  #                 return notify_fail("你的内力修为不够，难以施展" DING "。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不够，难以施展" DING "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIY "$N" HIY "身形一转，施出中平枪法绝技「" HIR "定岳七方"
  #               HIY "」，手中" + weapon->name() + HIY "接连七刺，枪枪不离"
  #              "$n" HIY "要害！\n" NOR;
  # 
  #     ap = me->query_skill("club");
  #     dp = target->query_skill("parry");
  # 
  #     if (ap / 2 + random(ap * 2) > dp)
  #     {
  #         msg += HIR "$n" HIR "见$N" HIR "攻势凶猛异常，实非"
  #                        "寻常，不由心生寒意，招架登时散乱。\n" NOR;
  #         } else
  #         {
  #                 msg += HIC "$n" HIC "见$N" HIC "攻势凶猛异常，实非"
  #                        "寻常，急忙打起精神，小心应付开来。\n" NOR;
  #         }
  #     message_combatd(msg, me, target);
  # 
  #     me->add("neili", -7 * 20);
  # 
  #     for (i = 0; i < 7; i++)
  #     {
  #         if (! me->is_fighting(target))
  #             break;
  #         COMBAT_D->do_attack(me, target, weapon, 0);
  #     }
  #     me->start_busy(1 + random(7));
  # 
  #     return 1;
  # }
end
