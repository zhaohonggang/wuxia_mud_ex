defmodule Kantele.Combat.Skills.Performs.HaotianZhang.Ju do
  @moduledoc """
  perform「三花聚顶」（source haotian-zhang/ju.c，inherit F_SSERVER）

  门槛（按 `.c` 顺序）：已学此招 → 目标在战斗中 → 空手（无主兵器）→
  昊天掌>=120 → 内功>=180 → 激发 `strike` 为昊天掌法 → 准备昊天掌法 →
  真气>=300 → 目标存活。
  起手广播后按 `random(内功) > 目标内功/2` 判定：命中则伤
  `掌法/2 + random(掌法/2)`、qi 上限伤 50%，攻击方忙乱 2、扣 200 真气；
  失手则攻击方忙乱 3、扣 60 真气。

  差异（TODO(migrate)）：
  - `.c` 的 `COMBAT_D->do_damage(..., UNARMED_ATTACK, damage, 50, 文案)` 折算为
    目标侧 `Vitals.damage(:qi, damage)` + `Vitals.wound(:qi, damage*50/100)`；
  - `.c` 的分支费用/忙乱依赖目标属性，故由目标侧 `Performs.feedback/3` 回执；
  - `.c` 的空手门槛只查 `query_temp("weapon")`（不查副兵器），与 `weapon/1` 对应；
  - `.c` 的 `clean_up_enemy()` / `select_opponent()` 折算为敌人列表取首个对手；
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
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs

  @perform_id "haotian-zhang/ju"
  @move_name "「三花聚顶」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "haotian-zhang")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_empty_handed(character),
         :ok <- check_level(stats),
         :ok <- check_force(stats),
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
          force: Stats.skill(stats, "force"),
          strike: Stats.skill(stats, "strike"),
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

  # LPC: if (objectp(me->query_temp("weapon")))
  defp check_empty_handed(character) do
    if Combat.weapon(character.meta.combat) != nil do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("haotian-zhang", 1) < 120)
  defp check_level(stats) do
    if Stats.skill(stats, "haotian-zhang") < 120 do
      {:error, "你的昊天掌不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("force") < 180)
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 180 do
      {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "haotian-zhang")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "strike") != "haotian-zhang" do
      {:error, "你没有激发昊天掌法，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "haotian-zhang")
  defp check_prepared(stats) do
    prepared = Stats.prepared_perform(stats, "strike")

    if is_binary(prepared) and prepared |> String.split("/") |> hd() == "haotian-zhang" do
      :ok
    else
      {:error, "你没有准备昊天掌法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query("neili") < 300)
  defp check_neili(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target))
  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活，
  # 由目标侧 combat/perform-incoming 的死亡检查兜底。
  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIY "$N" HIY "大喝一声，合身向$n" HIY "扑上，双掌同时"
    #            "击出，正是一招「" HIW "三花聚顶" HIY "」。\n" NOR;
    Broadcast.publish(
      conn,
      "$N大喝一声，合身向$n扑上，双掌同时击出，正是一招#{@move_name}。\n",
      n1: character.name,
      n2: target.name
    )
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
    force = max(Map.get(data, :force, 0), 1)
    strike = Map.get(data, :strike, 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(me->query_skill("force")) > target->query_skill("force") / 2)
    #      { me->start_busy(2); me->add("neili", -200);
    #        damage = strike; damage = damage / 2 + random(damage / 2);
    #        do_damage(me, target, UNARMED_ATTACK, damage, 50, 命中文案); }
    #      else { me->start_busy(3); me->add("neili", -60); 化解文案 }
    if Engine.rand(rng, force) > div(Stats.skill(stats, "force"), 2) do
      damage = div(strike, 2) + Engine.rand(rng, max(div(strike, 2), 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 50, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}
      Performs.feedback(attacker, 200, 2)

      conn
      |> Broadcast.publish(
        "结果$p被$P的气势所摄，慌忙后退，却被$P一掌击个正中，吐血不止！\n",
        bindings
      )
      |> put_character(character)
    else
      Performs.feedback(attacker, 60, 3)

      Broadcast.publish(conn, "可是$p识破了$P这一招，斜斜一跃避开。\n", bindings)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define JU "「" HIW "三花聚顶" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         // object weapon;
  #         int damage;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/haotian-zhang/ju"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail(JU "只能对战斗中的对手使用。\n");
  # 
  #     if (objectp(me->query_temp("weapon")))
  #                 return notify_fail(JU "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("haotian-zhang", 1) < 120)
  #                 return notify_fail("你的昊天掌不够娴熟，难以施展" JU "。\n");
  # 
  #         if ((int)me->query_skill("force") < 180)
  #                 return notify_fail("你的内功修为不够，难以施展" JU "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "haotian-zhang")
  #                 return notify_fail("你没有激发昊天掌法，难以施展" JU "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "haotian-zhang")
  #                 return notify_fail("你没有准备昊天掌法，难以施展" JU "。\n");
  # 
  #         if ((int)me->query("neili") < 300)
  #                 return notify_fail("你现在的真气不足，难以施展" JU "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "大喝一声，合身向$n" HIY "扑上，双掌同时"
  #               "击出，正是一招「" HIW "三花聚顶" HIY "」。\n" NOR;
  # 
  #         if (random(me->query_skill("force")) > target->query_skill("force") / 2)
  #         {
  #                 me->start_busy(2);
  #                 me->add("neili", -200);
  #                 damage = me->query_skill("strike");
  #                 damage = damage / 2 + random(damage / 2);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 50,
  #                                            HIR "结果$p" HIR "被$P" HIR "的气势所"
  #                                            "摄，慌忙后退，却被$P" HIR "一掌击个正"
  #                                            "中，吐血不止！\n" NOR);
  #         } else
  #         {
  #                 me->start_busy(3);
  #                 me->add("neili", -60);
  #                 msg += CYN "可是$p" CYN "识破了$P"
  #                        CYN "这一招，斜斜一跃避开。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
