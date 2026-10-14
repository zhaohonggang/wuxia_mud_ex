defmodule Kantele.Combat.Skills.Performs.SunFinger.Heal do
  @moduledoc """
  exert「疗伤」（source sun-finger/heal.c，inherit F_CLEAN_UP）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "sun-finger/heal"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(character),
         :ok <- check_gates(character, target) do
      apply_effect(conn, character, target)
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

  defp target(character) do
    case character.meta.combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "你要用真气为谁疗伤？\n"}
    end
  end

  defp check_gates(character, target) do
    with :ok <- check_not_self(character, target),
         :ok <- check_not_fighting(character, target),
         :ok <- check_living(target),
         :ok <- check_force_mapped(character),
         :ok <- check_resources(character),
         :ok <- check_target_injured(target) do
      :ok
    end
  end

  defp check_not_self(character, target) do
    if character.id == target.id do
      {:error, "你只能替别人疗伤。\n"}
    else
      :ok
    end
  end

  defp check_not_fighting(character, target) do
    if Combat.fighting?(character.meta.combat) or Combat.fighting?(target.meta.combat) do
      {:error, "战斗中无法运功疗伤！\n"}
    else
      :ok
    end
  end

  defp check_living(target) do
    if target.meta.combat.dead or target.meta.vitals.qi <= 0 do
      {:error, "你不能给"}
      |> Tuple.append("疗伤。\n")
      |> elem(0)
      |> Kernel.||({:error, "你不能给疗伤。\n"})
    else
      :ok
    end
  end

  defp check_force_mapped(character) do
    stats = character.meta.stats

    if Stats.mapped(stats, "force") == nil do
      {:error, "你必须激发一种内功才能运功疗伤。\n"}
    else
      :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 1500 -> {:error, "你的内力还浅，不是运功疗伤。\n"}
      vitals.neili < 1000 -> {:error, "你的真气现在不够，不能贸然行功。\n"}
      vitals.neili < 200 -> {:error, "你的气现在不够，不要贸然行功。\n"}
      vitals.jing < 100 -> {:error, "你的精现在不够，不要贸然行功。\n"}
      true -> :ok
    end
  end

  defp check_target_injured(target) do
    vitals = target.meta.vitals
    max_qi = vitals.max_qi
    max_jing = vitals.max_jing

    if vitals.qi >= max_qi and vitals.jing >= max_jing do
      {:error, "对方没有受伤，不需要接受治疗。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character, target) do
    vitals = character.meta.vitals

    # 攻击者消耗
    vitals = %{vitals | neili: vitals.neili - 1000}
    vitals = %{vitals | qi: vitals.qi - 150}
    vitals = %{vitals | jing: vitals.jing - 80}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    combat = character.meta.combat
    combat = Combat.start_busy(combat, 10)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    # 疗伤广播 - 第一部分（对应 LPC "$N默运" + to_chinese(force)）
    conn = Broadcast.publish(conn, "默运", n1: character.name, n2: target.name)
    # 疗伤广播 - 第二部分（对应 LPC 剩余部分）
    conn =
      Broadcast.publish(conn, "，施展开一阳指法，瞬时点遍了身上诸要穴....深吸一口气，头上隐隐冒出白雾，“哇”的一下吐出瘀血，脸色登时红润多了。",
        n1: character.name,
        n2: target.name
      )

    # 目标恢复
    target_vitals = target.meta.vitals
    force_lvl = Stats.skill(target.meta.stats, "force") || 0
    sun_lvl = Stats.skill(target.meta.stats, "sun-finger") || 0

    qi_cure = 100 + force_lvl + sun_lvl * 3
    jing_cure = 100 + div(force_lvl, 3) + sun_lvl

    target_vitals = Vitals.curing(target_vitals, :qi, qi_cure)
    target_vitals = Vitals.curing(target_vitals, :jing, jing_cure)

    # 确保不为0
    target_vitals = if target_vitals.qi <= 0, do: %{target_vitals | qi: 1}, else: target_vitals

    target_vitals =
      if target_vitals.jing <= 0, do: %{target_vitals | jing: 1}, else: target_vitals

    target_combat = target.meta.combat
    target_combat = Combat.start_busy(target_combat, 2)
    target = %{target | meta: %{target.meta | vitals: target_vitals, combat: target_combat}}

    conn = Broadcast.publish(conn, "\n" <> character.name <> "闭目冥坐，开始运功调息。", n1: character.name)

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-1000"}], "busy_lines": ["me->start_busy(10);"], "remote_damage": false, "resource_gates": [{"jing", "100"}, {"max_neili", "1500"}, {"neili", "1000"}, {"neili", "200"}], "set_flags": [{"jing", "1"}, {"qi", "1"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // heal.c
  #
  # #include <ansi.h>
  #
  # int perform(object me, object target)
  # {
  #         string force;
  #
  #         if (! target)
  #                 return notify_fail("你要用真气为谁疗伤？\n");
  #
  #         if (target == me)
  #                 return notify_fail("你只能替别人疗伤。\n");
  #
  #         if (me->is_fighting() || target->is_fighting())
  #                 return notify_fail("战斗中无法运功疗伤！\n");
  #
  #         if (target->query("not_living"))
  #                 return notify_fail("你不能给" + target->name() + "疗伤。\n");
  #
  #         if (! (force = me->query_skill_mapped("force")))
  #                 return notify_fail("你必须激发一种内功才能运功疗伤。\n");
  #
  #         if ((int)me->query("max_neili") < 1500)
  #                 return notify_fail("你的内力还浅，不是运功疗伤。\n");
  #
  #         if ((int)me->query("neili") < 1000)
  #                 return notify_fail("你的真气现在不够，不能贸然行功。\n");
  #
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你的气现在不够，不要贸然行功。\n");
  #
  #         if ((int)me->query("jing") < 100)
  #                 return notify_fail("你的精现在不够，不要贸然行功。\n");
  #
  #         if (target->query("eff_qi") >= target->query("max_qi") &&
  #             target->query("eff_jing") >= target->query("max_jing"))
  #                 return notify_fail("对方没有受伤，不需要接受治疗。\n");
  #
  #         message_combatd(HIY "$N默运" + to_chinese(force) +
  #                         "，施展开一阳指法，瞬时点遍了$n身上"
  #                         "诸要穴....\n\n" HIC
  #                         "$N深吸一口气，头上隐隐冒出白雾，$n"
  #                         "“哇”的一下吐出瘀血，脸色登时红润"
  #                         "多了。\n" NOR, me, target);
  #
  #         me->add("neili", -1000);
  #         me->receive_damage("qi", 150);
  #         me->receive_damage("jing", 80);
  #
  #         target->receive_curing("qi", 100 + (int) me->query_skill("force") +
  #                                            (int) me->query_skill("sun_finger", 1) * 3);
  #
  #         if (target->query("qi") <= 0) target->set("qi", 1);
  #         target->receive_curing("jing", 100 + (int) me->query_skill("force") / 3 +
  #                                            (int) me->query_skill("sun_finger", 1));
  #
  #         if (target->query("jing") <= 0) target->set("jing", 1);
  #         target->stary_busy(2);
  #
  #         message_vision("\n$N闭目冥坐，开始运功调息。\n", me);
  #         me->start_busy(10);
  #
  #         return 1;
  # }
end
