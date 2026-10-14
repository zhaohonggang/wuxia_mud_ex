defmodule Kantele.Combat.Skills.Performs.LonelySword.Jue do
  @moduledoc """
  perform「总诀式」（source lonely-sword/jue.c，inherit F_SSERVER）

  自练型绝招（无目标）。门槛（按 .c 顺序）：房间 `no_fight` 且非 `scheme`
  状态 → 非战斗 → 持剑 → `lonely-sword`>=20 → 真气>=50 →
  精神>=`-jing_cost`（`jing_cost = max(80-int, 30)`）→ 尚可提升。
  演练广播后扣 `40 + random(10)` 真气、耗 `jing_cost` 精神；
  `improve = 1 + random(int)`，「基本剑法」提升 `improve/2`、
  「独孤九剑」提升 `improve`，并忙乱 `random(3)`。

  差异（TODO(migrate)）：
  - 房间 `no_fight` 标记与 `me->query("doing")` 未建模，`check_no_fight/1`
    恒为 :ok，仅保留文案以对齐 .c；
  - `.c` 无 `can_perform` 门槛，故本模块不设 `check_perform_known/1`；
  - `tell_object(me, …)` 折算为对自身的 `render(CommandView, "text", …)`；
  - `.c` 起手文案 `"…将手中" + weapon->name() + "随意挥舞击刺。\n"` 按原样拆为两段。
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

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    rng = &:rand.uniform/1
    # LPC: jing_cost = 80 - (int)me->query("int"); if (jing_cost < 30) jing_cost = 30;
    jing_cost = max(80 - stats.int, 30)

    with :ok <- check_no_fight(character),
         :ok <- check_not_fighting(character),
         {:ok, weapon} <- check_weapon(character),
         :ok <- check_skill_min(stats),
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

  # LPC: if (environment(me)->query("no_fight") && me->query("doing") != "scheme")
  #         return notify_fail("这里太嘈杂，你不能静下心来演练。\n");
  # 房间 no_fight 标记与 me->query("doing") 未建模，恒为 :ok，仅保留文案以对齐 .c。
  defp check_no_fight(_character) do
    _ = "这里太嘈杂，你不能静下心来演练。\n"
    :ok
  end

  # LPC: if (me->is_fighting()) return notify_fail("「总诀式」不能在战斗中演练。\n");
  defp check_not_fighting(character) do
    if Combat.fighting?(character.meta.combat) do
      {:error, "「总诀式」不能在战斗中演练。\n"}
    else
      :ok
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #          (string)weapon->query("skill_type") != "sword")
  #         return notify_fail("你必须先去找一把剑。\n");
  defp check_weapon(character) do
    case Combat.weapon(character.meta.combat) do
      %{skill_type: "sword"} = weapon -> {:ok, weapon}
      _ -> {:error, "你必须先去找一把剑。\n"}
    end
  end

  # LPC: if (! skill || skill < 20)
  #         return notify_fail("你的独孤九剑等级不够, 不能演练「总诀式」！\n");
  defp check_skill_min(stats) do
    if Stats.skill(stats, "lonely-sword") < 20 do
      {:error, "你的独孤九剑等级不够, 不能演练「总诀式」！\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili") < 50)
  #         return notify_fail("你的内力不够，没有力气演练「总诀式」！\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 50 do
      {:error, "你的内力不够，没有力气演练「总诀式」！\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("jing") < -jing_cost)
  #         return notify_fail("你现在太累了，无法集中精神演练「总诀式」！\n");
  defp check_jing(character, jing_cost) do
    if character.meta.vitals.jing < -jing_cost do
      {:error, "你现在太累了，无法集中精神演练「总诀式」！\n"}
    else
      :ok
    end
  end

  # LPC: if (! me->can_improve_skill("lonely-sword"))
  #         return notify_fail("你的实战经验不够，无法体会「总诀式」！\n");
  defp check_can_improve(stats) do
    if LearnGate.can_improve?(stats, "lonely-sword") do
      :ok
    else
      {:error, "你的实战经验不够，无法体会「总诀式」！\n"}
    end
  end

  defp apply_effect(conn, character, weapon, jing_cost, rng) do
    stats = character.meta.stats

    # LPC: msg = HIG "$N" HIG "使出独孤九剑之「总诀式」，将手中" +
    #            weapon->name() + HIG "随意挥舞击刺。\n" NOR;
    #      message_combatd(msg, me);
    conn =
      Broadcast.publish(
        conn,
        "$N使出独孤九剑之「总诀式」，将手中" <>
          Map.get(weapon, :name) <> "随意挥舞击刺。\n",
        n1: character.name
      )

    # LPC: me->add("neili", -40 - random(10)); me->receive_damage("jing", jing_cost);
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 40 - Engine.rand(rng, 10)}
    vitals = Vitals.damage(vitals, :jing, jing_cost)
    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: improve = 1 + random(me->query("int"));
    improve = 1 + Engine.rand(rng, stats.int)
    character = improve_skill(character, "sword", div(improve, 2))
    character = improve_skill(character, "lonely-sword", improve)

    # LPC: me->start_busy(random(3));
    busy = Engine.rand(rng, 3)

    character =
      if busy > 0 do
        combat = Combat.start_busy(character.meta.combat, busy)
        %{character | meta: %{character.meta | combat: combat}}
      else
        character
      end

    # LPC: tell_object(me, MAG "你的「基本剑法」和「独孤九剑」进步了！\n" NOR);
    conn
    |> render(CommandView, "text", %{text: "你的「基本剑法」和「独孤九剑」进步了！\n"})
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # LPC: me->improve_skill("sword", improve / 2); me->improve_skill("lonely-sword", improve);
  defp improve_skill(character, skill_name, gain) do
    current = Stats.skill(character.meta.stats, skill_name)
    skills = Map.put(character.meta.stats.skills, skill_name, current + gain)
    stats = %{character.meta.stats | skills: skills}
    %{character | meta: %{character.meta | stats: stats}}
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
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
  #         skill = me->query_skill("lonely-sword", 1);
  # 
  #         jing_cost = 80 - (int)me->query("int");
  #         if (jing_cost < 30) jing_cost = 30;
  # 
  #         if (environment(me)->query("no_fight") && me->query("doing") != "scheme")
  #                 return notify_fail("这里太嘈杂，你不能静下心来演练。\n");
  # 
  #         if (me->is_fighting())
  #                 return notify_fail("「总诀式」不能在战斗中演练。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你必须先去找一把剑。\n");
  # 
  #         if (! skill || skill < 20)
  #                 return notify_fail("你的独孤九剑等级不够, 不能演练「总诀式」！\n");
  # 
  #         if (me->query("neili") < 50)
  #                 return notify_fail("你的内力不够，没有力气演练「总诀式」！\n");
  # 
  #         if (me->query("jing") < -jing_cost)
  #                 return notify_fail("你现在太累了，无法集中精神演练「总诀式」！\n");
  # 
  #         if (! me->can_improve_skill("lonely-sword"))
  #                 return notify_fail("你的实战经验不够，无法体会「总诀式」！\n");
  # 
  #         msg = HIG "$N" HIG "使出独孤九剑之「总诀式」，将手中" +
  #               weapon->name() + HIG "随意挥舞击刺。\n" NOR;
  #         message_combatd(msg, me);
  # 
  #         me->add("neili", -40 - random(10));
  #         me->receive_damage("jing", jing_cost);
  # 
  #         improve = 1 + random(me->query("int"));
  # 
  #         tell_object(me, MAG "你的「基本剑法」和「独孤九剑」进步了！\n" NOR);
  #         me->improve_skill("sword", improve / 2);
  #         me->improve_skill("lonely-sword", improve);
  #         me->start_busy(random(3));
  #         return 1;
  # }
end
