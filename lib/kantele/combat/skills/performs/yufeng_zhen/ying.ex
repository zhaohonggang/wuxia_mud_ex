defmodule Kantele.Combat.Skills.Performs.YufengZhen.Ying do
  @moduledoc """
  perform「无影针」（source yufeng-zhen/ying.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "yufeng-zhen/ying"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "yufeng-zhen")
    my_exp = Stats.skill(stats, "throwing")

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
      Stats.skill(stats, "yufeng-zhen") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "throwing") != "yufeng-zhen" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 100 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 80}
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
    level = Map.get(data, :level, 0)
    skill = Map.get(data, :skill, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "parry")
    vitals = character.meta.vitals
        vitals = Vitals.wound(vitals, :qi, (skill + Engine.rand(rng, div(skill, 3))))
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 80, 1)
    result = Messages.interpolate("结果$p反应不及，中了$P一base_unit！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-80"}], "assign_refs": [{"my_exp", "throwing"}, {"ob_exp", "dodge"}, {"skill", "yufeng-zhen"}], "busy_lines": ["me->start_busy(2 + random(2));"], "level_gates": [{"force", "100"}, {"yufeng-zhen", "100"}], "map_gates": [{"throwing", "yufeng-zhen"}], "remote_damage": false, "resource_gates": [{"neili", "100"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define YING "「" HIY "无影针" NOR "」"
  # 
  # #include "/kungfu/skill/eff_msg.h";
  # 
  # int perform(object me, object target)
  # {
  #         int skill;
  #         // int i, n;
  #         int my_exp, ob_exp, p;
  #         string pmsg;
  #         string msg;
  #         object weapon;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! me->query("can_perform/yufeng-zhen/ying"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(YING "只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("handing")) ||
  #             (string)weapon->query("skill_type") != "throwing")
  #                 return notify_fail("你现在手中并没有拿着针，怎么施展" YING "？\n");
  # 
  #         if (weapon->query_amount() < 1)
  #                 return notify_fail("你手中没有针，无法施展" YING "。\n");
  # 
  #         if ((skill = me->query_skill("yufeng-zhen", 1)) < 100)
  #                 return notify_fail("你的玉蜂针手法不够娴熟，不会使用" YING "。\n");
  # 
  #         if (me->query_skill("force") < 100)
  #                 return notify_fail("你的内功火候不够，无法施展" YING "。\n");
  # 
  #         if (me->query_skill_mapped("throwing") != "yufeng-zhen")
  #                 return notify_fail("你没有激发玉蜂针，不能使用" YING "。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你内力不够，无法施展" YING "\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         me->add("neili", -80);
  #         weapon->add_amount(-1);
  # 
  #         msg= HIY "$N" HIY "身不慌，足不移，手掌只是轻轻一抖，只见"
  #              "一点寒光闪过，闪电般的射向$n" HIY "！\n" NOR;
  # 
  #         me->start_busy(2 + random(2));
  # 
  #         my_exp = me->query_skill("throwing");
  #         ob_exp = target->query_skill("dodge");
  #         if (my_exp / 2 + random(my_exp) > ob_exp)
  #         {
  #                 msg += HIR "结果$p" HIR "反应不及，中了$P" + HIR "一" +
  #                        weapon->query("base_unit") + weapon->name() +
  #                        HIR "！\n" NOR;
  #                 target->receive_wound("qi", skill + random(skill / 3), me);
  # 
  #                 COMBAT_D->clear_ahinfo();
  #                 weapon->hit_ob(me, target, me->query("jiali") + 100);
  # 
  #                 p = (int)target->query("qi") * 100 / (int)target->query("max_qi");
  # 
  #                 if (stringp(pmsg = COMBAT_D->query_ahinfo()))
  #                         msg += pmsg;
  # 
  #                 msg += "( $n" + eff_status_msg(p) + " )\n";
  # 
  #                 message_combatd(msg, me, target);
  #         } else
  #         {
  #                 msg += HIG "可是$p" HIG "从容不迫，轻巧的闪过了$P" HIG "发出的" +
  #                        weapon->name() + HIG "。\n" NOR;
  #                 message_combatd(msg, me, target);
  #         }
  # 
  #         me->reset_action();
  #         return 1;
  # }
end
