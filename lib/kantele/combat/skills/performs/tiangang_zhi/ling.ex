defmodule Kantele.Combat.Skills.Performs.TiangangZhi.Ling do
  @moduledoc """
  凌空指穴「ling」（对照 `kungfu/skill/tiangang-zhi/ling.c`）

  天罡指穴法绝技：需内功>=150、天罡指穴法>=100、真气>=100、激发 finger 为
  天罡指穴法、目标未忙乱且存活。命中判定 `ap/2 + random(ap) > 目标dodge`
  （ap = finger）：命中令目标忙乱 `tiangang-zhi/22 + 2` 轮并扣 100 真气；
  未命中攻击方忙乱 3 并扣 30 真气。

  差异（TODO(migrate)）：
  - 引子在攻击方广播，命中/落空在目标侧结算；
  - `.c` 的 `target->is_busy()`（句末为全角句号「放胆攻击吧。」）与
    `living(target)` 门槛由目标侧 `combat/perform-incoming` 的 `cond` 兜底；
  - 攻守双方 finger/dodge 通过事件数据传递。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  @perform_id "tiangang-zhi/ling"
  @move_name "「凌空指穴」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         :ok <- check_force(stats),
         {:ok, level} <- check_skill_level(stats),
         :ok <- check_neili(character),
         :ok <- check_mapped(stats) do
      apply_perform(conn, character, target, level, stats)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("force") < 150)
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 150 do
      {:error, "你内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("tiangang-zhi", 1) < 100)
  defp check_skill_level(stats) do
    level = Stats.skill(stats, "tiangang-zhi")

    if level < 100 do
      {:error, "你的天罡指穴法修为不够，难以施展#{@move_name}。\n"}
    else
      {:ok, level}
    end
  end

  # LPC: if ((int)me->query("neili") < 100)
  defp check_neili(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你的真气现在不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("finger") != "tiangang-zhi")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "finger") == "tiangang-zhi" do
      :ok
    else
      {:error, "你没有激发天罡指穴法，不能施展#{@move_name}。\n"}
    end
  end

  defp apply_perform(conn, character, target, level, stats) do
    # LPC: msg = HIC "$N" HIC "使出天罡指穴法绝技「凌空指穴」，左手"
    #           "一连七指向着$n" HIC "胸前大穴接连戳出。\n" NOR;
    conn =
      Broadcast.publish(
        conn,
        "$N使出天罡指穴法绝技「凌空指穴」，左手一连七指向着$n胸前大穴接连戳出。\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        level: level,
        finger: Stats.skill(stats, "finger"),
        rng: &:rand.uniform/1
      }
    })

    conn
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    cond do
      character.meta.combat.dead ->
        # LPC: if (! living(target))
        #          return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
        Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？\n",
          n1: attacker.name,
          n2: character.name
        )

      character.meta.combat.busy > 0 ->
        # LPC: if (target->is_busy())
        #          return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
        Broadcast.publish(conn, "$n目前正自顾不暇，放胆攻击吧。\n",
          n1: attacker.name,
          n2: character.name
        )

      true ->
        do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    level = Map.get(data, :level, 0)
    ap = max(Map.get(data, :finger, 0), 1)
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: ap = me->query_skill("finger"); dp = target->query_skill("dodge");
    dp = Stats.skill(stats, "dodge")

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: msg += HIR "结果$p" HIR "不及攻敌，拼力躲避$P"
      #                   HIR "指力顿时动作大乱！\n" NOR;
      #      target->start_busy((int)me->query_skill("tiangang-zhi", 1) / 22 + 2);
      #      me->add("neili", -100);
      combat = Combat.start_busy(character.meta.combat, div(level, 22) + 2)
      character = %{character | meta: %{character.meta | combat: combat}}

      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate("结果$p不及攻敌，拼力躲避$P指力顿时动作大乱！\n", bindings)
        )

      Performs.feedback(attacker, 100, 0)
      put_character(conn, character)
    else
      # LPC: msg += CYN "$p" CYN "情急智生，奋力一跃，退出老远。\n" NOR;
      #      me->start_busy(3); me->add("neili", -30);
      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate("$p情急智生，奋力一跃，退出老远。\n", bindings)
        )

      Performs.feedback(attacker, 30, 3)
      conn
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "tiangang-zhi/ling",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define LING "「" HIC "凌空指穴" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/tiangang-zhi/ling"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(LING "只能对战斗中的对手使用。\n");
  # 
  #     if ((int)me->query_skill("force") < 150)
  #         return notify_fail("你内功火候不够，难以施展" LING "。\n");
  # 
  #     if ((int)me->query_skill("tiangang-zhi", 1) < 100)
  #         return notify_fail("你的天罡指穴法修为不够，难以施展" LING "。\n");
  # 
  #     if ((int)me->query("neili") < 100)
  #         return notify_fail("你的真气现在不够，难以施展" LING "。\n");
  # 
  #     if (target->is_busy())
  #         return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #         if (me->query_skill_mapped("finger") != "tiangang-zhi")
  #                 return notify_fail("你没有激发天罡指穴法，不能施展" LING "。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIC "$N" HIC "使出天罡指穴法绝技「凌空指穴」，左手"
  #               "一连七指向着$n" HIC "胸前大穴接连戳出。\n" NOR;
  #         ap = me->query_skill("finger");
  #         dp = target->query_skill("dodge");
  #     if (ap / 2 + random(ap) > dp)
  #     {
  #         msg += HIR "结果$p" HIR "不及攻敌，拼力躲避$P"
  #                        HIR "指力顿时动作大乱！\n" NOR;
  #         target->start_busy((int)me->query_skill("tiangang-zhi", 1) / 22 + 2);
  #         me->add("neili", -100);
  #     } else
  #     {
  #         msg += CYN "$p" CYN "情急智生，奋力一跃，退出老远。\n" NOR;
  #         me->start_busy(3);
  #                 me->add("neili", -30);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
