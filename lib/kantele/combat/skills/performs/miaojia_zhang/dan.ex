defmodule Kantele.Combat.Skills.Performs.MiaojiaZhang.Dan do
  @moduledoc """
  perform「丹阳劲」（对照 `kungfu/skill/miaojia-zhang/dan.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 空手（未持主武器）→
  苗家掌法>=40 → 内力上限>=200 → 激发 `strike` 为苗家掌法 → 准备苗家掌法 →
  真气>=50 → 目标存活。
  起手文案在攻击方广播；攻击方无条件扣 30 真气、忙乱 3（两分支相同）；
  命中判定 `random(攻击方内功) > 目标内功/2` 在目标侧结算：命中则目标忙乱
  `random(3)`，目标 qi 伤 `内功/3 + random(内功/3)`、qi 上限伤 30%。

  差异（TODO(migrate)）：
  - `.c` 把起手与分支文案累积到 `msg` 后一次 `message_combatd`；此处按引擎惯例拆分
    （起手在攻击方 `apply_effect` 广播，分支在目标侧广播，同 `guzhuo_zhang/yu.ex`）；
  - 命中条件依赖目标 `force`、伤害依赖攻击方 `force`，均经事件数据传递到目标侧；
  - 两分支的 `me->start_busy(3)` 经 `Performs.feedback/3` 回执（`neili` 无条件已在前结算）；
  - `COMBAT_D->do_damage(...,damage,30,msg)` → `damage(:qi,damage)` +
    `wound(:qi, div(damage*30,100))` 并广播该文案（含 `:内伤@?` 标记，逐字保留）；
  - `!living(target)` 门槛在攻击方无 meta 可查，恒判存活，由目标侧
    `combat/perform-incoming` 的死亡检查兜底。
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

  @perform_id "miaojia-zhang/dan"
  @move_name "「丹阳劲」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "miaojia-zhang")
    # LPC: damage = (int)me->query_skill("force", 1);（目标侧折算用）
    force = Stats.skill(stats, "force")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_level(stats),
         :ok <- check_max_neili(character),
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
          force: force,
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

  # LPC: if (userp(me) && ! me->query("can_perform/miaojia-zhang/dan"))
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
  defp check_weapon(combat) do
    if Combat.weapon(combat) == nil do
      :ok
    else
      {:error, "你必须空手才能使用#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("miaojia-zhang", 1) < 40)
  defp check_level(stats) do
    if Stats.skill(stats, "miaojia-zhang") < 40 do
      {:error, "你的苗家掌法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("max_neili") < 200)
  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 200 do
      {:error, "你的内功修为不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "miaojia-zhang")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "strike") != "miaojia-zhang" do
      {:error, "你没有激发苗家掌法，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "miaojia-zhang")
  defp check_prepared(stats) do
    prepared = Stats.prepared_perform(stats, "strike")

    if is_binary(prepared) and String.split(prepared, "/") |> hd() == "miaojia-zhang" do
      :ok
    else
      {:error, "你没有准备苗家掌法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query("neili") < 50)
  defp check_neili(character) do
    if character.meta.vitals.neili < 50 do
      {:error, "你现在真气太弱，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target))
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIM "$N" HIM "凝聚内力，深深吸入一口气，掌劲吞吐，对准$n"
    #            HIM "平平拍出。\n" NOR;（合并为单段）
    conn =
      Broadcast.publish(
        conn,
        "$N凝聚内力，深深吸入一口气，掌劲吞吐，对准$n平平拍出。\n",
        n1: character.name,
        n2: target.name
      )

    # LPC: me->add("neili", -30);
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 30}
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
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]
    force = max(Map.get(data, :force, 0), 0)

    # LPC: if (random(me->query_skill("force")) > target->query_skill("force") / 2)
    #      { me->start_busy(3); target->start_busy(random(3));
    #        damage = force / 3 + random(force / 3);
    #        msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30, "…"); }
    #      else { me->start_busy(3); msg += "可是$p看破了$P的企图，并没有上当。\n"; }
    if Engine.rand(rng, force) > div(Stats.skill(stats, "force"), 2) do
      # LPC: target->start_busy(random(3));
      combat = Combat.start_busy(character.meta.combat, Engine.rand(rng, 3))
      character = %{character | meta: %{character.meta | combat: combat}}

      damage = div(force, 3) + Engine.rand(rng, div(force, 3))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 30, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}
      # LPC: me->start_busy(3);
      Performs.feedback(attacker, 0, 3)

      conn
      |> Broadcast.publish(
        "$n见势连忙向后一纵，但却只觉胸口一震，顿时两耳轰鸣，已被$N掌劲所伤！\n:内伤@?",
        bindings
      )
      |> put_character(character)
    else
      # LPC: me->start_busy(3);
      Performs.feedback(attacker, 0, 3)

      Broadcast.publish(conn, "可是$p看破了$P的企图，并没有上当。\n", bindings)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define DAN "「" HIM "丹阳劲" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/miaojia-zhang/dan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(DAN "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(me->query_temp("weapon")))
  #                 return notify_fail("你必须空手才能使用" DAN "。\n");         
  #                 
  #         if ((int)me->query_skill("miaojia-zhang", 1) < 40)
  #                 return notify_fail("你的苗家掌法不够娴熟，难以施展" DAN "。\n");
  # 
  #         if (me->query("max_neili") < 200)
  #                 return notify_fail("你的内功修为不足，难以施展" DAN "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "miaojia-zhang")
  #                 return notify_fail("你没有激发苗家掌法，难以施展" DAN "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "miaojia-zhang")
  #                 return notify_fail("你没有准备苗家掌法，难以施展" DAN "。\n");
  # 
  #         if (me->query("neili") < 50)
  #                 return notify_fail("你现在真气太弱，难以施展" DAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIM "$N" HIM "凝聚内力，深深吸入一口气，掌劲吞吐，对准$n"
  #               HIM "平平拍出。\n" NOR;
  #         me->add("neili", -30);
  # 
  #         if (random(me->query_skill("force")) > target->query_skill("force") / 2)
  #         {
  #                 me->start_busy(3);
  #                 target->start_busy(random(3));
  #                 
  #                 damage = (int)me->query_skill("force", 1);
  #                 damage = damage / 3 + random(damage / 3);
  #                 
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
  #                                            HIR "$n" HIR "见势连忙向后一纵，但却只觉"
  #                                            "胸口一震，顿时两耳轰鸣，已被$N" HIR "掌"
  #                                            "劲所伤！\n:内伤@?");
  #         } else 
  #         {
  #                 me->start_busy(3);
  #                 msg += CYN "可是$p" CYN "看破了$P"
  #                        CYN "的企图，并没有上当。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
