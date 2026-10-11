defmodule Kantele.Combat.Skills.Performs.TaijiShengong.Dian do
  @moduledoc """
  exert「鹤嘴劲点龙跃窍」（source taiji-shengong/dian.c，由 translate_perform.py 生成，inherit ?）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_gates(character) do
      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对
  defp check_gates(character) do
    with :ok <- check_levels(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "taiji-shengong") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
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

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-800"}], "busy_lines": ["if (! target->is_busy())", "me->start_busy(10);"], "level_gates": [{"taiji-shengong", "100"}], "remote_damage": false, "resource_gates": [{"jing", "100"}, {"max_neili", "1500"}, {"neili", "1000"}], "set_flags": [{"jing", "1"}, {"qi", "1"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # #define DIAN "「" HIW "鹤嘴劲点龙跃窍" NOR "」"
  # 
  # int exert(object me, object target)
  # {
  #         if (userp(me) && ! me->query("can_perform/taiji-shengong/dian"))
  #                 return notify_fail("你所学的内功中没有这种功能。\n");
  # 
  #         if (! target)
  #                 return notify_fail("你要用真气为谁疗伤？\n");
  # 
  #         if (target == me)
  #                 return notify_fail(DIAN "只能对别人施展。\n");
  # 
  #         if (me->is_fighting() || target->is_fighting())
  #                 return notify_fail("战斗中无法运功疗伤。\n");
  # 
  #         if (target->query("not_living"))
  #                 return notify_fail("你无法给" + target->name() + "疗伤。\n");
  # 
  #         if ((int)me->query_skill("taiji-shengong", 1) < 100)
  #                 return notify_fail("你的太极神功不够娴熟，难以施展" DIAN "。\n");
  # 
  #         if ((int)me->query("max_neili") < 1500)
  #                 return notify_fail("你的内力修为太浅，难以施展" DIAN "。\n");
  # 
  #         if ((int)me->query("neili") < 1000)
  #                 return notify_fail("你现在的真气不足，难以施展" DIAN "。\n");
  # 
  #         if ((int)me->query("jing") < 100)
  #                 return notify_fail("你现在精神状态不佳，难以施展" DIAN "。\n");
  # 
  #         if (target->query("eff_qi") >= target->query("max_qi") &&
  #             target->query("eff_jing") >= target->query("max_jing"))
  #                 return notify_fail("对方没有受伤，不需要接受治疗。\n");
  # 
  #         message_sort(HIW "\n只见$N" HIW "双手食指和拇指虚拿，成鹤嘴劲"
  #                      "势，以食指指尖点在$n" HIW "耳尖三分处的龙跃窍，"
  #                      "运起内功，微微摆动。这招鹤嘴劲点龙跃窍使将出来，"
  #                      "便是新断气之人也能还魂片刻。过得一会便见得$p额头"
  #                      "上冒出豆大汗珠，头上冒出隐隐白雾，哇的一下吐出瘀"
  #                      "血，脸色登时看起来红润多了。\n" NOR, me, target);
  # 
  #         me->add("neili", -800);
  #         me->receive_damage("qi", 100);
  #         me->receive_damage("jing", 50);
  # 
  #         target->receive_curing("qi", 100 + (int)me->query_skill("force") +
  #                                      (int)me->query_skill("taiji-shengong", 1) * 3);
  # 
  #         if (target->query("qi") <= 0)
  #                 target->set("qi", 1);
  # 
  #         target->receive_curing("jing", 100 + (int)me->query_skill("force") / 3 +
  #                                        (int)me->query_skill("taiji-shengong", 1));
  # 
  #         if (target->query("jing") <= 0)
  #                 target->set("jing", 1);
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
