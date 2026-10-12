defmodule Kantele.Combat.Skills.Performs.Force.Lifeheal do
  @moduledoc """
  exert「lifeheal」（source force/lifeheal.c）

  为他人疗伤：需指定目标、双方均非战斗、目标非 `not_living`、已激发内功、
  该内功>=50、`max_neili>=300`、真气>=150、目标 `eff_qi < max_qi` 且
  `eff_qi >= max_qi/5`。扣真气 150；目标 `receive_curing("qi", 10+force/2)`、
  `add("qi", 10+force/3)`（上限 `eff_qi`）。

  差异（TODO(migrate)）：
  - 真实运行为 `Kantele.Combat.Skills.Force.Lifeheal`（`skills/force_lifeheal.ex`），
    本文件为并存的对齐副本（仅供文案对齐）；目标侧回复由真实实现经
    `combat/perform-incoming` 结算；
  - 本引擎 exert 无目标参数，故以敌列表首个引用快照代理「目标」（真实实现同此约定）；
    敌列表为空即视为「无目标」，给 `.c` 的「你要用真气为谁疗伤？」；
  - 敌列表仅存引用快照（无 `vitals`），目标伤情两道门槛在无法判定时保守放行；
  - `to_chinese(force)` 折算为映射 id 原样（引擎未维护内功 id→中文名 表，
    同 `sanku_shengong/dispel.ex` 约定）；
  - LPC `eff_qi`/`max_qi` 对应本引擎 `vitals.max_qi`/`vitals.base_qi`。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast


  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with {:ok, target} <- find_target(character),
         :ok <- check_gates(character, target) do
      apply_effect(conn, character, target)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (! target || target == me) return notify_fail("你要用真气为谁疗伤？\n");
  # 本引擎 exert 无目标参数，以敌列表首个引用快照代理目标；无目标或目标即自身时同此文案。
  defp find_target(character) do
    case character.meta.combat.enemies do
      [%{id: id} = target | _] when id != character.id -> {:ok, target}
      _ -> {:error, "你要用真气为谁疗伤？\n"}
    end
  end

  defp check_gates(character, target) do
    with :ok <- check_not_fighting(character),
         :ok <- check_not_living(target),
         :ok <- check_has_force(character),
         :ok <- check_force_level(character),
         :ok <- check_max_neili(character),
         :ok <- check_neili(character),
         :ok <- check_target_wounded(target) do
      :ok
    end
  end

  # LPC: if (me->is_fighting() || target->is_fighting())
  defp check_not_fighting(character) do
    if Combat.fighting?(character.meta.combat) do
      {:error, "战斗中无法运功疗伤！\n"}
    else
      :ok
    end
  end

  # LPC: if (target->query("not_living")) return notify_fail("你不能给" + target->name() + "疗伤。\n");
  defp check_not_living(target) do
    if Map.get(target, :not_living) == true do
      {:error, "你不能给" <> to_string(Map.get(target, :name, "")) <> "疗伤。\n"}
    else
      :ok
    end
  end

  # LPC: force = me->query_skill_mapped("force"); if (! force)
  #        return notify_fail("你必须激发一种内功才能替人疗伤。\n");
  defp check_has_force(character) do
    if force_name(character) != nil do
      :ok
    else
      {:error, "你必须激发一种内功才能替人疗伤。\n"}
    end
  end

  # LPC: if ((int)me->query_skill(force,1) < 50)
  #        return notify_fail("你的" + to_chinese(force) + "等级不够。\n");
  # C 侧 "你的" + to_chinese(force) + "等级不够。\n" 被显式 `+` 切成两段，E 侧同粒度。
  defp check_force_level(character) do
    force = force_name(character)

    if Stats.skill(character.meta.stats, force) < 50 do
      {:error, "你的" <> to_chinese(force) <> "等级不够。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("max_neili") < 300)
  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 300 do
      {:error, "你的内力修为不够。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 150)
  defp check_neili(character) do
    if character.meta.vitals.neili < 150 do
      {:error, "你现在的真气不够。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)target->query("eff_qi") >= (int)target->query("max_qi"))
  #        return notify_fail(target->name() + "现在没有受伤，不需要你运功治疗！\n");
  #      if ((int)target->query("eff_qi") < (int)target->query("max_qi") / 5)
  #        return notify_fail(target->name() + "已经受伤过重，经受不起你的真气震荡！\n");
  defp check_target_wounded(target) do
    case Map.get(target, :vitals) do
      # 敌列表仅存引用快照（无 vitals），无法判定伤情，保守放行。
      nil ->
        :ok

      vitals ->
        name = to_string(Map.get(target, :name, ""))

        cond do
          vitals.max_qi >= vitals.base_qi ->
            {:error, name <> "现在没有受伤，不需要你运功治疗！\n"}

          vitals.max_qi < div(vitals.base_qi, 5) ->
            {:error, name <> "已经受伤过重，经受不起你的真气震荡！\n"}

          true ->
            :ok
        end
    end
  end

  defp apply_effect(conn, character, target) do
    vitals = character.meta.vitals
    force = force_name(character)

    # LPC: message_vision(HIY "$N坐了下来运起" + to_chinese(force) +
    #        "，将手掌贴在$n背心，缓缓地将真气输入$n体内....\n"
    #        HIW "过了不久，$N额头上冒出豆大的汗珠，$n吐出一"
    #        "口瘀血，脸色看起来红润多了。\n" NOR, me, target);
    # C 侧被 `+ to_chinese(force) +` 与颜色宏切成两段，E 侧同粒度。
    conn =
      Broadcast.publish(
        conn,
        "$N坐了下来运起" <>
          to_chinese(force) <>
          "，将手掌贴在$n背心，缓缓地将真气输入$n体内....\n过了不久，$N额头上冒出豆大的汗珠，$n吐出一口瘀血，脸色看起来红润多了。\n",
        n1: character.name,
        n2: Map.get(target, :name)
      )

    # LPC: target->receive_curing("qi", 10 + (int)me->query_skill("force") / 2);
    #      target->add("qi", 10 + (int)me->query_skill("force") / 3);
    #      if ((int)target->query("qi") > (int)target->query("eff_qi"))
    #              target->set("qi", (int)target->query("eff_qi"));
    # 目标回复由真实实现经目标侧 `combat/perform-incoming` 结算，此处只扣自身真气。
    # LPC: me->add("neili", -150);
    vitals = %{vitals | neili: max(vitals.neili - 150, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp force_name(character), do: Stats.mapped(character.meta.stats, "force")

  # LPC: to_chinese(force) —— 引擎未维护内功 id→中文名 表，保留 id 原样
  # （同 `sanku_shengong/dispel.ex` 的对齐副本约定）。
  defp to_chinese(name), do: name
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // lifeheal.c
  # 
  # #include <ansi.h>
  # 
  # int exert(object me, object target)
  # {
  #         string force;
  # 
  #         if (! target || target == me)
  #                 return notify_fail("你要用真气为谁疗伤？\n");
  # 
  #         if (me->is_fighting() || target->is_fighting())
  #                 return notify_fail("战斗中无法运功疗伤！\n");
  # 
  #         if (target->query("not_living"))
  #                 return notify_fail("你不能给" + target->name() + "疗伤。\n");
  # 
  #         force = me->query_skill_mapped("force");
  #         if (! force)
  #                 return notify_fail("你必须激发一种内功才能替人疗伤。\n");
  # 
  #         if ((int)me->query_skill(force,1) < 50)
  #                 return notify_fail("你的" + to_chinese(force) + "等级不够。\n");
  # 
  #         if ((int)me->query("max_neili") < 300)
  #                 return notify_fail("你的内力修为不够。\n");
  # 
  #         if ((int)me->query("neili") < 150)
  #                 return notify_fail("你现在的真气不够。\n");
  # 
  #         if ((int)target->query("eff_qi") >= (int)target->query("max_qi"))
  #                 return notify_fail( target->name() +
  #                         "现在没有受伤，不需要你运功治疗！\n");
  # 
  #         if ((int)target->query("eff_qi") < (int)target->query("max_qi") / 5)
  #                 return notify_fail( target->name() +
  #                         "已经受伤过重，经受不起你的真气震荡！\n");
  # 
  #         message_vision(
  #                 HIY "$N坐了下来运起" + to_chinese(force) +
  #                 "，将手掌贴在$n背心，缓缓地将真气输入$n体内....\n"
  #                 HIW "过了不久，$N额头上冒出豆大的汗珠，$n吐出一"
  #                 "口瘀血，脸色看起来红润多了。\n" NOR,
  #                 me, target );
  # 
  #         target->receive_curing("qi", 10 + (int)me->query_skill("force") / 2);
  #         target->add("qi", 10 + (int)me->query_skill("force") / 3);
  #         if ((int)target->query("qi") > (int)target->query("eff_qi"))
  #                 target->set("qi", (int)target->query("eff_qi"));
  # 
  #         me->add("neili", -150);
  #         return 1;
  # }
end
