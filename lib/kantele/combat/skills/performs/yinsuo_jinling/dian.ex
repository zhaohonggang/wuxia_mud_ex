defmodule Kantele.Combat.Skills.Performs.YinsuoJinling.Dian do
  @moduledoc """
  perform「隔空点穴」（source yinsuo-jinling/dian.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "yinsuo-jinling/dian"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "yinsuo-jinling")
    time = 13

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
      Stats.skill(stats, "force") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "yinsuo-jinling") < 80 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "whip") != "yinsuo-jinling" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 150 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 120}
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
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 120, 1)
    result = Messages.interpolate("$n只听$N发出玎玎声响，声虽不大，却是十分怪异，入耳荡心摇魄，一不
留神，被这招点个正着，全身瘫软无力，动弹不得！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-120"}], "assign_refs": [{"time", "yinsuo-jinling"}], "busy_lines": ["if (target->is_busy())", "me->start_busy(1 + random(2));", "target->start_busy(time);"], "level_gates": [{"force", "100"}, {"yinsuo-jinling", "80"}], "map_gates": [{"whip", "yinsuo-jinling"}], "remote_damage": false, "resource_gates": [{"neili", "150"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define DIAN "「" HIG "隔空点穴" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int time;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/yinsuo-jinling/dian"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(DIAN "点穴攻击只能对战斗中的对手使用。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             weapon->query("skill_type") != "whip")
  #                 return notify_fail("你的武器不对，无法施展" DIAN "！\n");
  # 
  #         if (me->query_skill("yinsuo-jinling", 1) < 80)
  #                 return notify_fail("你的银索金铃级别不够，无法施展" DIAN "！\n");
  # 
  #         if (me->query_skill("force") < 100)
  #                 return notify_fail("你的内功修为不够，无法施展" DIAN "！\n");
  # 
  #         if (me->query("neili") < 150)
  #                 return notify_fail("你现在真气不够，无法施展" DIAN "！\n");
  # 
  #         if (me->query_skill_mapped("whip") != "yinsuo-jinling")
  #                 return notify_fail("你没有激发银索金铃，无法施展" DIAN "！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "\n$N" HIY "单手一抖，手中" + weapon->name() +
  #               HIY "疾颤三下，分点$n" HIY "脸上「迎香」、「承泣"
  #               "」、「人中」三个穴道，这三下点穴出手之快、认位之"
  #               "准，实是武林罕见！" NOR;
  # 
  #         me->start_busy(1 + random(2));
  # 
  #         message_sort(msg, me, target);
  # 
  #         if (random(me->query("combat_exp")) > (int)target->query("combat_exp") / 2)
  #         {
  #                 msg = HIR "$n" HIR "只听$N" + weapon->name() +
  #                       HIR "发出玎玎声响，声虽不大，却是"
  #                       "十分怪异，入耳荡心摇魄，一不\n留神"
  #                       "，被这招点个正着，全身瘫软无力，动"
  #                       "弹不得！\n" NOR;
  #                 time = (int)me->query_skill("yinsuo-jinling") / 25;
  #                 time = 2 + random(time);
  #                 if (time > 13) time = 13;
  #                 target->start_busy(time);
  #         } else
  #         {
  #                 msg = CYN "可是$p" CYN "看破了$P"
  #                       CYN "的企图，斜跳躲闪开来。\n" NOR;
  #         }
  #         me->add("neili", -120);
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
