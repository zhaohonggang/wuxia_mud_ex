defmodule Kantele.Combat.Skills.Performs.DuguJiujian.Jue do
  @moduledoc """
  perform「总诀式」（source dugu-jiujian/jue.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "dugu-jiujian/jue"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "dugu-jiujian")
    skill = Stats.skill(stats, "dugu-jiujian")
    jing_cost = 30

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
  defp check_gates(character), do: check_resources(character)

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 85 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
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
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"assign_refs": [{"skill", "dugu-jiujian"}], "busy_lines": ["me->start_busy(random(3));"], "remote_damage": false, "resource_gates": [{"neili", "85"}], "var_gates": [{"jing_cost", "30"}, {"skill", "60"}]}

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
