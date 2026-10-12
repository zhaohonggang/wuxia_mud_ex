defmodule Kantele.Combat.Skills.Performs.GuzhuoZhang.Zhuo do
  @moduledoc """
  perform「大巧若拙」（source guzhuo-zhang/zhuo.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 空手（主/副兵器皆无）→
  目标未忙乱 → 内功>=220 → 内力上限>=1800 → 古拙掌法>=150 →
  激发 `strike` 为古拙掌法 → 准备古拙掌法 → 真气>=300 → 目标存活。
  攻击方无条件扣 150 真气。命中判定 `ap/2 + random(ap)`（`ap = strike`）对目标
  `parry`：命中则目标忙乱 `古拙掌法/22 + 2`、攻击方忙乱 1；否则攻击方忙乱 2。

  差异（TODO(migrate)）：
  - `.c` 的 `target->is_busy()` 门槛读的是目标忙乱；敌人列表只存引用快照
    （%{id,pid,name,room_id}）时无 busy 可查，此处保守恒判未忙乱（文案照留）；
  - 攻击方忙乱依赖目标侧分支（命中 1 / 未中 2），故由目标侧 `Performs.feedback`
    回执（`neili_cost: 0` 不改真气）；
  - `.c` 未列「是否已学此招」门槛（`can_perform`），本引擎以框架层
    `perform_known?/2` 统一把关（多出的文案不影响对齐）；
  - `living(target)` 门槛在攻击方无 meta 可查，此处保守恒判存活，
    由目标侧 `combat/perform-incoming` 的死亡检查兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs

  @perform_id "guzhuo-zhang/zhuo"
  @move_name "「大巧若拙」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "guzhuo-zhang")
    ap = Stats.skill(stats, "strike")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_empty_handed(character),
         :ok <- check_target_busy(target),
         :ok <- check_force(stats),
         :ok <- check_max_neili(character),
         :ok <- check_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_prepared(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
          rng: rng
        }
      })

      apply_effect(conn, character, target)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # 框架层「是否已学此招」门槛（.c 未列 `can_perform`，见 moduledoc 差异说明）。
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  defp check_empty_handed(character) do
    combat = character.meta.combat

    if Combat.occupied?(combat, :weapon) or Combat.occupied?(combat, :secondary_weapon) do
      {:error, "#{@move_name}只能空手使用。\n"}
    else
      :ok
    end
  end

  # LPC: if (target->is_busy())
  #        return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 敌人引用无 busy 快照时保守恒判未忙乱（文案照留）。
  defp check_target_busy(target) do
    if busy?(target) do
      {:error, "#{Map.get(target, :name)}目前正自顾不暇，放胆攻击吧。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("force") < 220)
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 220 do
      {:error, "你内功修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("max_neili") < 1800)
  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 1800 do
      {:error, "你内力修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("guzhuo-zhang", 1) < 150)
  defp check_level(stats) do
    if Stats.skill(stats, "guzhuo-zhang") < 150 do
      {:error, "你古拙掌法火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "guzhuo-zhang")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "strike") != "guzhuo-zhang" do
      {:error, "你没有激发古拙掌法，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "guzhuo-zhang")
  defp check_prepared(stats) do
    prepared = Stats.prepared_perform(stats, "strike")

    if is_binary(prepared) and String.split(prepared, "/") |> hd() == "guzhuo-zhang" do
      :ok
    else
      {:error, "你没有准备古拙掌法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query("neili") < 300)
  defp check_neili(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target))
  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活，
  # 由目标侧 combat/perform-incoming 的死亡检查兜底。
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp busy?(%{meta: %{combat: %{busy: busy}}}), do: busy > 0
  defp busy?(_), do: false

  defp apply_effect(conn, character, target) do
    # LPC: msg = WHT "$N" WHT "手腕一探，平平推出一掌，顿时掌风激进，尘沙四起，直"
    #            "刮得$n" WHT "面庞隐隐生疼。\n" NOR;
    #      me->add("neili", -150);
    conn =
      Broadcast.publish(
        conn,
        "$N手腕一探，平平推出一掌，顿时掌风激进，尘沙四起，直刮得$n面庞隐隐生疼。\n",
        n1: character.name,
        n2: target.name
      )

    vitals = character.meta.vitals
    vitals = %{vitals | neili: max(vitals.neili - 150, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    lvl = Map.get(data, :level, 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("parry");
    #      if (ap / 2 + random(ap) > dp) { msg += "$n见$N掌风凌厉，慌忙招架，顿时便失了先机。\n";
    #            target->start_busy(guzhuo-zhang / 22 + 2); me->start_busy(1); }
    #      else { msg += "可是$n不慌不忙，看破了$N此招虚实，并没有受到半点影响。\n"; me->start_busy(2); }
    dp = Stats.skill(stats, "parry")

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      combat = Combat.start_busy(character.meta.combat, div(lvl, 22) + 2)
      character = %{character | meta: %{character.meta | combat: combat}}

      # LPC: me->start_busy(1);
      Performs.feedback(attacker, 0, 1)

      conn
      |> Broadcast.publish("$n见$N掌风凌厉，慌忙招架，顿时便失了先机。\n", bindings)
      |> put_character(character)
    else
      # LPC: me->start_busy(2);
      Performs.feedback(attacker, 0, 2)

      Broadcast.publish(conn, "可是$n不慌不忙，看破了$N此招虚实，并没有受到半点影响。\n", bindings)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHUO "「" WHT "大巧若拙" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/guzhuo-zhang/zhuo"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHUO "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(ZHUO "只能空手使用。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #         if ((int)me->query_skill("force") < 220)
  #                 return notify_fail("你内功修为不够，难以施展" ZHUO "。\n");
  # 
  #         if ((int)me->query("max_neili") < 1800)
  #                 return notify_fail("你内力修为不够，难以施展" ZHUO "。\n");
  # 
  #         if ((int)me->query_skill("guzhuo-zhang", 1) < 150)
  #                 return notify_fail("你古拙掌法火候不够，难以施展" ZHUO "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "guzhuo-zhang")
  #                 return notify_fail("你没有激发古拙掌法，难以施展" ZHUO "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "guzhuo-zhang")
  #                 return notify_fail("你没有准备古拙掌法，难以施展" ZHUO "。\n");
  # 
  #         if ((int)me->query("neili") < 300)
  #                 return notify_fail("你现在真气不够，难以施展" ZHUO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = WHT "$N" WHT "手腕一探，平平推出一掌，顿时掌风激进，尘沙四起，直"
  #               "刮得$n" WHT "面庞隐隐生疼。\n" NOR;
  #         me->add("neili", -150);
  # 
  #         ap = me->query_skill("strike");
  #         dp = target->query_skill("parry");
  # 
  #         if (ap / 2 + random(ap) > dp)
  # 
  #         {
  #                 msg += HIR "$n" HIR "见$N" HIR "掌风凌厉，慌"
  #                        "忙招架，顿时便失了先机。\n" NOR;
  #                 target->start_busy((int)me->query_skill("guzhuo-zhang", 1) / 22 + 2);
  #                 me->start_busy(1);
  #         } else
  #         {
  #                 msg += CYN "可是$n" CYN "不慌不忙，看破了$N"
  #                        CYN "此招虚实，并没有受到半点影响。\n" NOR;
  #                 me->start_busy(2);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
