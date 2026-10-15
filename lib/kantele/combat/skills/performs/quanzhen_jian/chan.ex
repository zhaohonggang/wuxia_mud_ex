defmodule Kantele.Combat.Skills.Performs.QuanzhenJian.Chan do
  @moduledoc """
  缠字诀「chan」（对照 `kungfu/skill/quanzhen-jian/chan.c`）

  全真剑法牵制攻击：需持剑、目标未忙乱且存活、全真剑法>=80、激发 sword 为
  全真剑法、真气>=100。攻击方恒扣 50 真气；命中判定
  `ap/2 + random(ap) > 目标force`（ap = sword）：命中令目标忙乱
  `level/28 + 2` 轮（level = 全真剑法）；未命中攻击方忙乱 1。

  差异（TODO(migrate)）：
  - `.c` 的 `target->is_busy()` 与 `living(target)` 门槛由目标侧
    `combat/perform-incoming` 的 `cond` 兜底（攻击方拿不到目标 meta）；
  - 引子在攻击方广播，命中/落空在目标侧结算。
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

  @perform_id "quanzhen-jian/chan"
  @move_name "「缠字诀」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_neili(character) do
      apply_perform(conn, character, target, weapon, stats)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/quanzhen-jian/chan"))
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

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #           (string)weapon->query("skill_type") != "sword")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      {:ok, weapon}
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((level = me->query_skill("quanzhen-jian", 1)) < 80)
  defp check_level(stats) do
    if Stats.skill(stats, "quanzhen-jian") < 80 do
      {:error, "你全真剑法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "quanzhen-jian")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "quanzhen-jian" do
      :ok
    else
      {:error, "你没有激发全真剑法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query("neili") < 100)
  defp check_neili(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, weapon, stats) do
    weapon_name = Map.get(weapon, :name, "")
    level = Stats.skill(stats, "quanzhen-jian")

    # LPC: msg = HIC "$N" HIC "使出全真剑法「缠」字诀，" + weapon->name() +
    #           HIC "带出阵阵风声，从四面八方盘绕向$n" HIC "。\n" NOR;
    #      me->add("neili", -50);
    #      ap = me->query_skill("sword"); dp = target->query_skill("force");
    conn =
      Broadcast.publish(
        conn,
        "$N使出全真剑法「缠」字诀，" <>
          weapon_name <> "带出阵阵风声，从四面八方盘绕向$n。\n",
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
        ap: Stats.skill(stats, "sword"),
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

    # LPC: ap = me->query_skill("sword"); dp = target->query_skill("force");
    ap = max(Map.get(data, :ap, 0), 1)
    dp = Stats.skill(stats, "force")

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: msg += HIR "$p" HIR "只觉得$P" HIR "剑上压力一层强过一层，
      #          只能使尽浑身解数运功抵挡。\n" NOR;
      #      target->start_busy(level / 28 + 2);
      level = Map.get(data, :level, 0)
      combat = Combat.start_busy(character.meta.combat, div(level, 28) + 2)
      character = %{character | meta: %{character.meta | combat: combat}}

      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate(
            "$p只觉得$P剑上压力一层强过一层，只能使尽浑身解数运功抵挡。\n",
            bindings
          )
        )

      # LPC: me->add("neili", -50) 为无条件扣减，经 Performs.feedback/3 回传攻击方。
      Performs.feedback(attacker, 50, 0)
      put_character(conn, character)
    else
      # LPC: msg += CYN "$p" CYN "见$P" CYN "招法严谨，当下不敢小觑"
      #           "，巧妙拆解$P" CYN "的来招，不露半点破绽。\n" NOR;
      #      me->start_busy(1);
      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate(
            "$p见$P招法严谨，当下不敢小觑，巧妙拆解$P的来招，不露半点破绽。\n",
            bindings
          )
        )

      # LPC: me->add("neili", -50) 为无条件扣减，经 Performs.feedback/3 回传攻击方。
      Performs.feedback(attacker, 50, 1)
      conn
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "quanzhen-jian/chan",
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
  # #define CHAN "「" HIC "缠字诀" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         int level;
  #         string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/quanzhen-jian/chan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(CHAN "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" CHAN "。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #         if ((level = me->query_skill("quanzhen-jian", 1)) < 80)
  #                 return notify_fail("你全真剑法不够娴熟，难以施展" CHAN "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "quanzhen-jian")
  #                 return notify_fail("你没有激发全真剑法，难以施展" CHAN "。\n");
  # 
  #         if (me->query("neili") < 100)
  #                 return notify_fail("你现在的真气不够，难以施展" CHAN "。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIC "$N" HIC "使出全真剑法「缠」字诀，" + weapon->name() +
  #               HIC "带出阵阵风声，从四面八方盘绕向$n" HIC "。\n" NOR;
  # 
  #         me->add("neili", -50);
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("force");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += HIR "$p" HIR "只觉得$P" HIR
  #                        "剑上压力一层强过一层，只能使尽浑身解数运功抵挡。\n" NOR;
  #                 target->start_busy(level / 28 + 2);
  #         } else
  #         {
  #                 msg += CYN "$p" CYN "见$P" CYN "招法严谨，当下不敢小觑"
  #                        "，巧妙拆解$P" CYN "的来招，不露半点破绽。\n" NOR;
  #                 me->start_busy(1);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
