defmodule Kantele.Combat.Skills.Performs.SunFinger.Dian do
  @moduledoc """
  神指点穴「dian」（对照 `kungfu/skill/sun-finger/dian.c`）

  一阳指（孙指）牵制攻击：需一阳指法>=80、激发 finger 为一阳指法、目标未忙乱
  且存活。命中判定 `ap/2 + random(ap) > 目标parry`（ap = finger）：命中令目标
  忙乱 `finger/20 + 2` 轮；未命中攻击方忙乱 1。
  `.c` 无内力消耗、无兵器门槛（空手出指）。

  差异（TODO(migrate)）：
  - `.c` 无 `can_perform` 门槛，本引擎保留 `perform_known?` 守卫（多 1 条信息性 EXTRA）；
  - `.c` 的 `target->is_busy()` 与 `living(target)` 门槛由目标侧
    `combat/perform-incoming` 的 `cond` 兜底（攻击方拿不到目标 meta）；
  - 门槛文案逐字对 `.c`：忙乱门槛句末为全角叹号（`放胆攻击吧！\\n`）。
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

  @perform_id "sun-finger/dian"
  @move_name "「神指点穴」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         :ok <- check_level(stats),
         :ok <- check_mapped(stats) do
      apply_perform(conn, character, target, stats)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC 无 can_perform 门槛；本引擎保留已知绝招守卫（信息性 EXTRA）。
  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("sun-finger", 1) < 80)
  defp check_level(stats) do
    if Stats.skill(stats, "sun-finger") < 80 do
      {:error, "你的一阳指法不够娴熟，不会使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("finger") != "sun-finger")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "finger") == "sun-finger" do
      :ok
    else
      {:error, "你没有激发一阳指法，不能使用#{@move_name}。\n"}
    end
  end

  defp apply_perform(conn, character, target, stats) do
    # LPC: msg = HIY "$N" HIY "凝神攻出一指，变化多端，巧妙的威胁$n"
    #           HIY "诸处大穴！\n" NOR;
    #      ap = me->query_skill("finger"); dp = target->query_skill("parry");
    conn =
      Broadcast.publish(
        conn,
        "$N凝神攻出一指，变化多端，巧妙的威胁$n诸处大穴！\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: Stats.skill(stats, "finger"),
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
        #          return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
        Broadcast.publish(conn, "$n目前正自顾不暇，放胆攻击吧！",
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

    # LPC: ap = me->query_skill("finger"); dp = target->query_skill("parry");
    ap = max(Map.get(data, :ap, 0), 1)
    dp = Stats.skill(stats, "parry")

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: target->start_busy((int)me->query_skill("finger") / 20 + 2);
      combat = Combat.start_busy(character.meta.combat, div(ap, 20) + 2)
      character = %{character | meta: %{character.meta | combat: combat}}

      # LPC: msg += HIR "结果$p" HIR "被$P" HIR "逼得招" "架不迭，一时无法反击！\n" NOR;
      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate(
            "结果$p被$P逼得招架不迭，一时无法反击！\n",
            bindings
          )
        )

      put_character(conn, character)
    else
      # LPC: msg += CYN "可是$p" CYN "看破了$P" CYN "的变化，"
      #           "小心招架，挡住了$P" CYN "的进击。\n" NOR;
      #      me->start_busy(1);
      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate(
            "可是$p看破了$P的变化，小心招架，挡住了$P的进击。\n",
            bindings
          )
        )

      Performs.feedback(attacker, 0, 1)
      conn
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "sun-finger/dian",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // dian.c 神指点穴
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     // object weapon;
  #     string msg;
  #   int ap, dp;
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail("「神指点穴」只能对战斗中的对手使用。\n");
  # 
  #     if (target->is_busy())
  #         return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
  # 
  #     if ((int)me->query_skill("sun-finger", 1) < 80)
  #         return notify_fail("你的一阳指法不够娴熟，不会使用「神指点穴」。\n");
  # 
  #         if (me->query_skill_mapped("finger") != "sun-finger")
  #                 return notify_fail("你没有激发一阳指法，不能使用「神指点穴」。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIY "$N" HIY "凝神攻出一指，变化多端，巧妙的威胁$n"
  #               HIY "诸处大穴！\n" NOR;
  # 
  #         ap = me->query_skill("finger");
  #         dp = target->query_skill("parry");
  #     if (ap / 2 + random(ap) > dp)
  #         {
  #         msg += HIR "结果$p" HIR "被$P" HIR "逼得招"
  #                        "架不迭，一时无法反击！\n" NOR;
  #         target->start_busy((int)me->query_skill("finger") / 20 + 2);
  #     } else
  #         {
  #         msg += CYN "可是$p" CYN "看破了$P" CYN "的变化，"
  #                        "小心招架，挡住了$P" CYN "的进击。\n" NOR;
  #         me->start_busy(1);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
