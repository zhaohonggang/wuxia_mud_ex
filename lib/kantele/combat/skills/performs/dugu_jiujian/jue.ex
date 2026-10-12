defmodule Kantele.Combat.Skills.Performs.DuguJiujian.Jue do
  @moduledoc """
  perform「总诀式」（source dugu-jiujian/jue.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招（`dugu-jiujian`<60 亦归此文案）→ 非战斗 →
  持剑 → `dugu-jiujian`>=60 → 基本剑法>=`dugu-jiujian` → 真气>=85 →
  精神>=`-jing_cost`（`jing_cost = max(80-int, 30)`）→ 尚可提升。
  演练广播后扣 `50 + random(30)` 真气、耗 `jing_cost` 精神；
  令「基本剑法」「独孤九剑」各提升 `10 + random(int)/2`，并忙乱 `random(3)`。

  差异（TODO(migrate)）：
  - 房间 `no_fight` 标记与 `me->query("doing")` 未建模，`check_no_fight/1`
    恒为 :ok，仅保留文案以对齐 .c；
  - `.c` 首次 `skill < 60` 门槛与框架 `perform_known?` 合并为 `check_perform_known/1`；
  - `tell_object(me, …)` 折算为对自身的 `render(CommandView, "text", …)`；
  - `.c` 起手文案 `"…将手中" + weapon->name() + "随意挥舞击刺。\n"` 按原样拆为三段。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.LearnGate
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine

  @perform_id "dugu-jiujian/jue"
  @move_name "「总诀式」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    rng = &:rand.uniform/1
    # LPC: jing_cost = 80 - me->query("int"); if (jing_cost < 30) jing_cost = 30;
    jing_cost = max(80 - stats.int, 30)

    with :ok <- check_perform_known(character),
         :ok <- check_no_fight(character),
         :ok <- check_not_fighting(character),
         {:ok, weapon} <- check_weapon(character),
         :ok <- check_skill_min(stats),
         :ok <- check_sword_level(stats),
         :ok <- check_neili(character),
         :ok <- check_jing(character, jing_cost),
         :ok <- check_can_improve(stats) do
      apply_effect(conn, character, weapon, jing_cost, rng)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (skill < 60) return notify_fail("你所使用的外功中没有这种功能。\n");
  # （框架以 perform_known? 承担「是否已学此招」。）
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (environment(me)->query("no_fight") && me->query("doing") != "scheme")
  #         return notify_fail("你周围过于嘈杂，难以演练" JUE "。\n");
  # 房间 no_fight 标记未建模，恒为 :ok，仅保留文案以对齐 .c。
  defp check_no_fight(_character) do
    _ = "你周围过于嘈杂，难以演练#{@move_name}。\n"
    :ok
  end

  # LPC: if (me->is_fighting()) return notify_fail(JUE "不能在战斗中演练。\n");
  defp check_not_fighting(character) do
    if Combat.fighting?(character.meta.combat) do
      {:error, "#{@move_name}不能在战斗中演练。\n"}
    else
      :ok
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #          (string)weapon->query("skill_type") != "sword")
  defp check_weapon(character) do
    case Combat.weapon(character.meta.combat) do
      %{skill_type: "sword"} = weapon -> {:ok, weapon}
      _ -> {:error, "你使用的武器不对，难以演练#{@move_name}。\n"}
    end
  end

  # LPC: if (! skill || skill < 60)
  #         return notify_fail("你的独孤九剑等级不够，难以演练" JUE "。\n");
  defp check_skill_min(stats) do
    if Stats.skill(stats, "dugu-jiujian") < 60 do
      {:error, "你的独孤九剑等级不够，难以演练#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill("sword", 1) < skill)
  #         return notify_fail("你的基本剑法等级有限，难以演练" JUE "。\n");
  defp check_sword_level(stats) do
    if Stats.skill(stats, "sword") < Stats.skill(stats, "dugu-jiujian") do
      {:error, "你的基本剑法等级有限，难以演练#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili") < 85)
  defp check_neili(character) do
    if character.meta.vitals.neili < 85 do
      {:error, "你现在真气不足，难以演练#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("jing") < -jing_cost)
  defp check_jing(character, jing_cost) do
    if character.meta.vitals.jing < -jing_cost do
      {:error, "你现在精神不佳，难以演练#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! me->can_improve_skill("dugu-jiujian"))
  #         return notify_fail("你实战经验不足，难以演练" JUE "。\n");
  defp check_can_improve(stats) do
    if LearnGate.can_improve?(stats, "dugu-jiujian") do
      :ok
    else
      {:error, "你实战经验不足，难以演练#{@move_name}。\n"}
    end
  end

  defp apply_effect(conn, character, weapon, jing_cost, rng) do
    stats = character.meta.stats

    # LPC: msg = HIC "$N" HIC "使出独孤九剑之「" HIW "总诀式" HIC "」，将手中" +
    #            weapon->name() + HIC "随意挥舞击刺。\n" NOR;
    #      message_combatd(msg, me);
    conn =
      Broadcast.publish(
        conn,
        "$N使出独孤九剑之「总诀式」，将手中" <>
          Map.get(weapon, :name) <> "随意挥舞击刺。\n",
        n1: character.name
      )

    # LPC: me->add("neili", -50 - random(30)); me->receive_damage("jing", jing_cost);
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 50 - Engine.rand(rng, 30)}
    vitals = Vitals.damage(vitals, :jing, jing_cost)
    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: improve = 10 + random(me->query("int")) / 2;
    improve = 10 + div(Engine.rand(rng, stats.int), 2)
    character = improve_skill(character, "sword", improve)
    character = improve_skill(character, "dugu-jiujian", improve)

    # LPC: me->start_busy(random(3));
    busy = Engine.rand(rng, 3)

    character =
      if busy > 0 do
        combat = Combat.start_busy(character.meta.combat, busy)
        %{character | meta: %{character.meta | combat: combat}}
      else
        character
      end

    # LPC: tell_object(me, HIY "你对「基本剑法」和「独孤九剑」有了新的领悟。\n" NOR);
    conn
    |> render(CommandView, "text", %{text: "你对「基本剑法」和「独孤九剑」有了新的领悟。\n"})
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # LPC: me->improve_skill("sword", improve); me->improve_skill("dugu-jiujian", improve);
  defp improve_skill(character, skill_name, gain) do
    current = Stats.skill(character.meta.stats, skill_name)
    skills = Map.put(character.meta.stats.skills, skill_name, current + gain)
    stats = %{character.meta.stats | skills: skills}
    %{character | meta: %{character.meta | stats: stats}}
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # #define JUE "「" HIC "总诀式" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me)
  # {
  #         string msg;
  #         object weapon;
  #         int skill, jing_cost;
  #         int improve;
  # 
  #         skill = me->query_skill("dugu-jiujian", 1);
  # 
  #         if (skill < 60)
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         jing_cost = 80 - (int)me->query("int");
  #         if (jing_cost < 30) jing_cost = 30;
  # 
  #         if (environment(me)->query("no_fight") && me->query("doing") != "scheme")
  #                 return notify_fail("你周围过于嘈杂，难以演练" JUE "。\n");
  # 
  #         if (me->is_fighting())
  #                 return notify_fail(JUE "不能在战斗中演练。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以演练" JUE "。\n");
  # 
  #         if (! skill || skill < 60)
  #                 return notify_fail("你的独孤九剑等级不够，难以演练" JUE "。\n");
  # 
  #         if (me->query_skill("sword", 1) < skill)
  #                 return notify_fail("你的基本剑法等级有限，难以演练" JUE "。\n");
  # 
  #         if (me->query("neili") < 85)
  #                 return notify_fail("你现在真气不足，难以演练" JUE "。\n");
  # 
  #         if (me->query("jing") < -jing_cost)
  #                 return notify_fail("你现在精神不佳，难以演练" JUE "。\n");
  # 
  #         if (! me->can_improve_skill("dugu-jiujian"))
  #                 return notify_fail("你实战经验不足，难以演练" JUE "。\n");
  # 
  #         msg = HIC "$N" HIC "使出独孤九剑之「" HIW "总诀式"
  #               HIC "」，将手中" + weapon->name() + HIC "随"
  #               "意挥舞击刺。\n" NOR;
  #         message_combatd(msg, me);
  # 
  #         me->add("neili", -50 - random(30));
  #         me->receive_damage("jing", jing_cost);
  # 
  #         improve = 10 + random(me->query("int")) / 2;
  # 
  #         tell_object(me, HIY "你对「基本剑法」和「独孤九剑」"
  #                         "有了新的领悟。\n" NOR);
  #         me->improve_skill("sword", improve);
  #         me->improve_skill("dugu-jiujian", improve);
  #         me->start_busy(random(3));
  #         return 1;
  # }
end
