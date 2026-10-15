defmodule Kantele.Combat.Skills.Performs.NianhuaZhi.Fuxue do
  @moduledoc """
  拈花拂穴「fuxue」（对照 `kungfu/skill/nianhua-zhi/fuxue.c`）

  拈花指绝技：需内功>=150、指法>=150、真气>=200、激发 finger 为拈花指、
  目标未忙乱且存活。命中判定 `random(战斗经验) > 目标战斗经验/3`：
  命中令目标忙乱 `nianhua-zhi/19 + 2` 轮并扣 100 真气；
  未命中扣 30 真气、攻击方忙乱 3 轮。

  差异（TODO(migrate)）：
  - `.c` 无 `can_perform` 门槛，本引擎保留 `perform_known?` 守卫（多 1 条信息性 EXTRA）；
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - `target->is_busy()` / 目标战斗经验取引用快照（`%{id,pid,name,room_id}`）的 meta，
    缺 meta 时分别按「非忙」「经验 0」处理；
  - 攻击方真气/忙乱经 `Performs.feedback/3` 由目标侧回传。
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

  @perform_id "nianhua-zhi/fuxue"
  @move_name "拈花拂穴"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat
    rng = &:rand.uniform/1
    level = Stats.skill(stats, "nianhua-zhi")
    exp = Map.get(stats, :combat_exp, 0)

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         :ok <- check_force(stats),
         :ok <- check_finger(stats),
         :ok <- check_neili(character),
         :ok <- check_target_busy(target),
         :ok <- check_mapped(stats) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: level,
          exp: exp,
          rng: rng
        }
      })

      apply_perform(conn, character, target)
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

  # LPC: if (! target || ! me->is_fighting(target))
  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("force") < 150)
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 150 do
      {:error, "你内功火候不够，不能使用#{@move_name}！\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("finger") < 150)
  defp check_finger(stats) do
    if Stats.skill(stats, "finger") < 150 do
      {:error, "你的指法修为不够，目前还不能使用#{@move_name}绝技！\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 200)
  defp check_neili(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在真气不够，不能使用#{@move_name}！\n"}
    else
      :ok
    end
  end

  # LPC: if (target->is_busy())
  #          return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
  defp check_target_busy(target) do
    if target_busy?(target) do
      {:error, "#{Map.get(target, :name)}目前正自顾不暇，放胆攻击吧！\n"}
    else
      :ok
    end
  end

  defp target_busy?(target) do
    case get_in(target, [:meta, :combat, :busy]) do
      busy when is_integer(busy) -> busy > 0
      _ -> false
    end
  end

  # LPC: if (me->query_skill_mapped("finger") != "nianhua-zhi")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "finger") == "nianhua-zhi" do
      :ok
    else
      {:error, "你没有激发拈花指，无法使用#{@move_name}！\n"}
    end
  end

  defp apply_perform(conn, character, target) do
    # LPC: msg = HIY "$N" HIY "使出拈花指绝技「拈花拂穴」，罩住了$n"
    #           HIY "的全身，指气层层叠叠的攻向$p" HIY "的要穴！\n" NOR;
    conn
    |> Broadcast.publish(
      "$N使出拈花指绝技「拈花拂穴」，罩住了$n的全身，指气层层叠叠的攻向$p的要穴！\n",
      n1: character.name,
      n2: target.name
    )
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？\n",
        n1: attacker.name,
        n2: character.name
      )
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    exp = max(Map.get(data, :exp, 0), 1)
    level = Map.get(data, :level, 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(me->query("combat_exp")) > (int)target->query("combat_exp") / 3)
    dp = div(Map.get(stats, :combat_exp, 0), 3)

    if Engine.rand(rng, exp) > dp do
      # LPC: msg += HIG "结果$p" HIG "被$P" HIG "攻了个措手不及！\n" NOR;
      #      target->start_busy((int)me->query_skill("nianhua-zhi", 1) / 19 + 2);
      #      me->add("neili", -100);
      combat = Combat.start_busy(character.meta.combat, div(level, 19) + 2)
      character = %{character | meta: %{character.meta | combat: combat}}

      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate("结果$p被$P攻了个措手不及！\n", bindings)
        )

      Performs.feedback(attacker, 100, 0)
      put_character(conn, character)
    else
      # LPC: msg += CYN "可是$p" CYN "看破了$P" CYN "的招式，连忙跃开，避开了$P" CYN "的攻击。\n" NOR;
      #      me->add("neili", -30); me->start_busy(3);
      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate("可是$p看破了$P的招式，连忙跃开，避开了$P的攻击。\n", bindings)
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
      id: "nianhua-zhi/fuxue",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // fuxue.c 拈花指 「拈花拂穴」
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
  #         return notify_fail("拈花拂穴只能对战斗中的对手使用。\n");
  # 
  #     if ((int)me->query_skill("force") < 150)
  #         return notify_fail("你内功火候不够，不能使用拈花拂穴！\n");
  # 
  #     if ((int)me->query_skill("finger") < 150)
  #         return notify_fail("你的指法修为不够，目前还不能使用拈花拂穴绝技！\n");
  # 
  #     if ((int)me->query("neili") < 200)
  #         return notify_fail("你现在真气不够，不能使用拈花拂穴！\n");
  # 
  #     if (target->is_busy())
  #         return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
  # 
  #     if (me->query_skill_mapped("finger") != "nianhua-zhi")
  #         return notify_fail("你没有激发拈花指，无法使用拈花拂穴！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIY "$N" HIY "使出拈花指绝技「拈花拂穴」，罩住了$n"
  #               HIY "的全身，指气层层叠叠的攻向$p" HIY "的要穴！\n" NOR;
  # 
  #     if (random(me->query("combat_exp")) > (int)target->query("combat_exp") / 3)
  #     {
  #         msg +=  HIG "结果$p" HIG "被$P" HIG "攻了个措手不及！\n" NOR;
  #         target->start_busy((int)me->query_skill("nianhua-zhi", 1) / 19 + 2);
  #         me->add("neili", -100);
  #     }
  #     else
  #     {
  #         msg += CYN "可是$p" CYN "看破了$P"
  #                        CYN "的招式，连忙跃开，避开了$P"
  #                        CYN "的攻击。\n" NOR;
  #         me->add("neili", -30);
  #         me->start_busy(3);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
