defmodule Kantele.Combat.Skills.Performs.YiyangZhi.Heal do
  @moduledoc """
  perform「起死回生」（source yiyang-zhi/heal.c，由 translate_perform.py 生成，inherit ?）

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

  @perform_id "yiyang-zhi/heal"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "yiyang-zhi")

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
      Stats.skill(stats, "jingluo-xue") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "yiyang-zhi") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "finger") != "yiyang-zhi" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.jing < 100 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.max_neili < 1500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 1000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 800}
    vitals = %{vitals | jing: 1}
    vitals = %{vitals | qi: 1}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 10)
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
    Performs.feedback(attacker, 800, 10)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-800"}], "busy_lines": ["if (! target->is_busy())", "me->start_busy(10);"], "level_gates": [{"jingluo-xue", "100"}, {"yiyang-zhi", "100"}], "map_gates": [{"finger", "yiyang-zhi"}], "prepared_gates": [{"finger", "yiyang-zhi"}], "remote_damage": false, "resource_gates": [{"jing", "100"}, {"max_neili", "1500"}, {"neili", "1000"}], "set_flags": [{"jing", "1"}, {"qi", "1"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # #define HEAL "「" HIR "起死回生" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #         string force;
  # 
  #         if (userp(me) && ! me->query("can_perform/yiyang-zhi/heal"))
  #                 return notify_fail("你所学的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #                 return notify_fail("你要用真气为谁疗伤？\n");
  # 
  #         if (target == me)
  #                 return notify_fail(HEAL "只能对别人施展。\n");
  # 
  #         if (me->is_fighting() || target->is_fighting())
  #                 return notify_fail("战斗中无法运功疗伤。\n");
  # 
  #         if (target->query("not_living"))
  #                 return notify_fail("你无法给" + target->name() + "疗伤。\n");
  # 
  #         if ((int)me->query_skill("yiyang-zhi", 1) < 100)
  #                 return notify_fail("你的一阳指诀不够娴熟，难以施展" HEAL "。\n");
  # 
  #         if ((int)me->query_skill("jingluo-xue", 1) < 100)
  #                 return notify_fail("你对经络学的了解不够，难以施展" HEAL "。\n");
  # 
  #         if (me->query_skill_mapped("finger") != "yiyang-zhi")
  #                 return notify_fail("你没有激发一阳指，难以施展" HEAL "。\n");
  # 
  #         if (me->query_skill_prepared("finger") != "yiyang-zhi")
  #                 return notify_fail("你没有准备一阳指，难以施展" HEAL "。\n");
  # 
  #         if (! (force = me->query_skill_mapped("force")))
  #                 return notify_fail("你必须激发一种内功才能施展" HEAL "。\n");
  # 
  #         if ((int)me->query("max_neili") < 1500)
  #                 return notify_fail("你的内力修为太浅，难以施展" HEAL "。\n");
  # 
  #         if ((int)me->query("neili") < 1000)
  #                 return notify_fail("你现在的真气不足，难以施展" HEAL "。\n");
  # 
  #         if ((int)me->query("jing") < 100)
  #                 return notify_fail("你现在的状态不佳，难以施展" HEAL "。\n");
  # 
  #         if (target->query("eff_qi") >= target->query("max_qi") &&
  #             target->query("eff_jing") >= target->query("max_jing"))
  #                 return notify_fail("对方没有受伤，不需要接受治疗。\n");
  # 
  #         message_sort(HIY "\n只见$N" HIY "默默运转" + to_chinese(force) +
  #                      HIY "，深深吸进一口气，头上隐隐冒出白雾，陡然施展开"
  #                      "一阳指诀，以纯阳指力瞬时点遍了$n" HIY "全身七十二"
  #                      "处大穴。过得一会，便见得$n" HIY "“哇”的一下吐出"
  #                      "几口瘀血，脸色登时看起来红润多了。\n" NOR, me, target);
  # 
  #         me->add("neili", -800);
  #         me->receive_damage("qi", 100);
  #         me->receive_damage("jing", 50);
  # 
  #         target->receive_curing("qi", 100 + (int)me->query_skill("force") +
  #                                      (int)me->query_skill("yiyang-zhi", 1) * 3);
  # 
  #         if (target->query("qi") <= 0)
  #                 target->set("qi", 1);
  # 
  #         target->receive_curing("jing", 100 + (int)me->query_skill("force") / 3 +
  #                                        (int)me->query_skill("yiyang-zhi", 1));
  # 
  #         if (target->query("jing") <= 0)
  #                 target->set("jing", 1);
  # 
  #         if ((int)target->query_condition("tiezhang_yin")
  #            || (int)target->query_condition("tiezhang_yang"))
  #         {
  #                 target->clear_condition("tiezhang_yin");
  #                 target->clear_condition("tiezhang_yang");
  #                 tell_object(target, HIC "\n你只觉体内残存的铁掌掌劲慢慢"
  #                                     "消退，感觉好多了。\n" NOR);
  #         }
  # 
  #         if ((int)target->query_condition("freezing"))
  #         {
  #                 target->clear_condition("freezing");                
  #                 tell_object(target, HIC "\n你只觉浑身渐渐转暖，寒冰真气之毒已消失得无影无踪。\n" NOR);
  #         }
  # 
  #         if (! living(target))
  #                 target->revive();
  # 
  #         if (! target->is_busy())
  #                 target->stary_busy(2);
  # 
  #         message_vision("\n$N闭目冥坐，开始运功调息。\n", me);
  #         me->start_busy(10);
  #         return 1;
  # }
end
