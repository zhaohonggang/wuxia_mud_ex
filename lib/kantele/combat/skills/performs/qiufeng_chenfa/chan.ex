defmodule Kantele.Combat.Skills.Performs.QiufengChenfa.Chan do
  @moduledoc """
  缠字诀「chan」（对照 `kungfu/skill/qiufeng-chenfa/chan.c`）

  秋风尘法牵制攻击：需真气>=200、秋风尘法>=80、目标未处于忙乱且存活。
  命中判定 `random(自身combat_exp) > 目标combat_exp/2`：命中令目标忙乱
  `whip/28 + 2` 轮；未命中攻击方忙乱 4。两者均扣 100 真气
  （LPC 前置 `start_busy(random(1))` 恒为 0，故命中时攻击方不忙乱）。

  差异（TODO(migrate)）：
  - `.c` 的 `target->is_busy()` 与 `living(target)` 门槛由目标侧
    `combat/perform-incoming` 的 `cond` 兜底（攻击方拿不到目标 meta）；
  - `.c` 引子与结果同属一条 `message_combatd`，本引擎拆为攻击方/目标侧两段广播。
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

  @perform_id "qiufeng-chenfa/chan"
  @move_name "缠"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with {:ok, target} <- check_target(combat),
         :ok <- check_neili(character),
         :ok <- check_level(stats) do
      apply_perform(conn, character, target, stats)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "牵制攻击只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if ((int)me->query("neili") < 200)
  defp check_neili(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你的真气不够！\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("qiufeng-chenfa", 1) < 80)
  defp check_level(stats) do
    if Stats.skill(stats, "qiufeng-chenfa") < 80 do
      {:error, "你秋风尘法的修为不够，不能使用#{@move_name}字诀！\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, stats) do
    # LPC: msg = CYN "$N" CYN "使出秋风尘法「缠」字诀，拂尘连挥企图把$n"
    #           CYN "的全身缠住。\n" NOR;
    #      me->start_busy(random(1));  // 恒为 0
    conn =
      Broadcast.publish(
        conn,
        "$N使出秋风尘法「缠」字诀，拂尘连挥企图把$n的全身缠住。\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        combat_exp: stats.combat_exp || 0,
        whip: Stats.skill(stats, "whip"),
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
        # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
        Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？\n",
          n1: attacker.name,
          n2: character.name
        )

      character.meta.combat.busy > 0 ->
        # LPC: if (target->is_busy())
        #          return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
        Broadcast.publish(conn, "$n目前正自顾不暇，放胆攻击吧。",
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
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(me->query("combat_exp")) > (int)target->query("combat_exp") / 2)
    my_exp = max(Map.get(data, :combat_exp, 0), 1)
    ob_exp = div(stats.combat_exp || 0, 2)
    whip = Map.get(data, :whip, 0)

    if Engine.rand(rng, my_exp) > ob_exp do
      # LPC: msg += CYN "结果$p" CYN "被$P" CYN "攻了个措手不及。\n" NOR;
      #      target->start_busy((int)me->query_skill("whip") / 28 + 2);
      combat = Combat.start_busy(character.meta.combat, div(whip, 28) + 2)
      character = %{character | meta: %{character.meta | combat: combat}}

      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate("结果$p被$P攻了个措手不及。\n", bindings)
        )

      # LPC: me->add("neili", -100);  // 命中时 start_busy(random(1)) == 0
      Performs.feedback(attacker, 100, 0)
      put_character(conn, character)
    else
      # LPC: msg += CYN "可是$p" CYN "看破了$P" CYN "的企图，并没有上当。\n" NOR;
      #      me->start_busy(4);
      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate("可是$p看破了$P的企图，并没有上当。\n", bindings)
        )

      Performs.feedback(attacker, 100, 4)
      conn
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "qiufeng-chenfa/chan",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // chan.c 秋风尘法 缠字诀
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     string msg;
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail("牵制攻击只能对战斗中的对手使用。\n");
  # 
  #     if ((int)me->query("neili") < 200)
  #         return notify_fail("你的真气不够！\n");
  # 
  #     if ((int)me->query_skill("qiufeng-chenfa", 1) < 80)
  #         return notify_fail("你秋风尘法的修为不够，不能使用缠字诀！\n");
  # 
  #     if (target->is_busy())
  #         return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = CYN "$N" CYN "使出秋风尘法「缠」字诀，拂尘连挥企图把$n"
  #               CYN "的全身缠住。\n" NOR;
  # 
  #     me->start_busy(random(1));
  #     if (random(me->query("combat_exp")) > (int)target->query("combat_exp") / 2)
  #         {
  #         msg += CYN "结果$p" CYN "被$P" CYN "攻了个措手不及。\n" NOR;
  #         target->start_busy( (int)me->query_skill("whip") / 28 + 2);
  #     } else
  #         {
  #         msg += CYN "可是$p" CYN "看破了$P" CYN "的企图，并没有上当。\n" NOR;
  #         me->start_busy(4);
  #     }
  #     message_combatd(msg, me, target);
  #     me->add("neili", -100);
  #     return 1;
  # }
end
