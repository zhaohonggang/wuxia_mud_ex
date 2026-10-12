defmodule Kantele.Combat.Skills.Performs.ChongyangShenzhang.Lian do
  @moduledoc """
  perform「重阳连环掌」（source chongyang-shenzhang/lian.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 未持兵器 → 重阳神掌>=100 →
  激发 strike 为重阳神掌 → 准备重阳神掌 → 内功>=120 → 真气>=100 → 目标存活。
  前置广播后攻击方扣 80 真气，连续 `do_attack` 4 击，收招忙乱 `1+random(4)`。

  差异（TODO(migrate)）：
  - LPC 的 4 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线）折算为每击
    `level/15` 基础伤害 + 命中判定 `level/2 + random(level)` vs 目标 `dodge`；
  - `.c` 的 `me->set_temp("action_flag", af)` 只是把出招位标记为 strike，折算后
    不再需要；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧 `combat/perform-incoming`
    的死亡检查兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Performs

  @perform_id "chongyang-shenzhang/lian"
  @move_name "「重阳连环掌」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "chongyang-shenzhang")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(character),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_prepared(character),
         :ok <- check_force(character),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
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
  defp check_weapon(character) do
    if Combat.weapon(character.meta.combat) != nil do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    if Stats.skill(stats, "chongyang-shenzhang") < 100 do
      {:error, "你重阳神掌不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "chongyang-shenzhang")
  defp check_mapped(character) do
    stats = character.meta.stats

    if Stats.mapped(stats, "strike") == "chongyang-shenzhang" do
      :ok
    else
      {:error, "你没有激发重阳神掌，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (! mapp(p = me->query_skill_prepare()) || p["strike"] != "chongyang-shenzhang")
  defp check_prepared(character) do
    stats = character.meta.stats

    case Stats.prepared_perform(stats, "strike") do
      nil ->
        {:error, "你没有准备重阳神掌，难以施展#{@move_name}。\n"}

      value ->
        if String.split(value, "/") |> hd() == "chongyang-shenzhang" do
          :ok
        else
          {:error, "你没有准备重阳神掌，难以施展#{@move_name}。\n"}
        end
    end
  end

  defp check_force(character) do
    stats = character.meta.stats

    if Stats.skill(stats, "force") < 120 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    if vitals.neili < 100 do
      {:error, "你目前的真气不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
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

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIY "$N" HIY "大喝一声，施出「" HIR "重阳连环掌" HIY "」，顿"
    #              "时双掌纷飞，向$n" HIY "猛攻而去。\n" NOR;
    #      message_combatd(msg, me, target);  me->add("neili", -80);
    # 连击伤害/busy 在目标侧结算。
    vitals = character.meta.vitals
    vitals = %{vitals | neili: max(vitals.neili - 80, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn =
      Broadcast.publish(
        conn,
        "$N大喝一声，施出「重阳连环掌」，顿时双掌纷飞，向$n猛攻而去。\n",
        n1: character.name,
        n2: target.name
      )

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
    level = max(Map.get(data, :level, 0), 1)
    # LPC: for (i = 0; i < 4; i++) { if (! me->is_fighting(target)) break;
    #         me->set_temp("action_flag", af); COMBAT_D->do_attack(me, target, 0, 0); }
    # 折算：每击 level/15 基础伤害 + 命中判定（无显式 ap/dp，取 level/2 + random(level)）。
    dodge = Stats.skill(character.meta.stats, "dodge")
    per_hit = max(div(level, 15), 1)

    damage =
      Enum.reduce(1..4, 0, fn _, damage_acc ->
        if div(level, 2) + Engine.rand(rng, level) > dodge do
          damage_acc + per_hit + Engine.rand(rng, per_hit)
        else
          damage_acc
        end
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: me->start_busy(1 + random(4))（收招后，位于连击之后）
    Performs.feedback(attacker, 0, 1 + Engine.rand(rng, 4))

    conn
    |> put_character(character)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define LIAN "「" HIR "重阳连环掌" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  # //    object weapon;
  #         string msg;
  #         mapping p;
  #         int i, af;
  # 
  #         if (userp(me) && ! me->query("can_perform/chongyang-shenzhang/lian"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail(LIAN "只能对战斗中的对手使用。\n");
  # 
  #     if (objectp(me->query_temp("weapon")))
  #                 return notify_fail(LIAN "只能空手施展。\n");
  # 
  #     if ((int)me->query_skill("chongyang-shenzhang", 1) < 100)
  #         return notify_fail("你重阳神掌不够娴熟，难以施展" LIAN "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "chongyang-shenzhang")
  #                 return notify_fail("你没有激发重阳神掌，难以施展" LIAN "。\n");
  # 
  #         if (! mapp(p = me->query_skill_prepare())
  #            || p["strike"] != "chongyang-shenzhang")
  #                 return notify_fail("你没有准备重阳神掌，难以施展" LIAN "。\n");
  # 
  #     if ((int)me->query_skill("force") < 120)
  #         return notify_fail("你的内功火候不够，难以施展" LIAN "。\n");
  # 
  #     if ((int)me->query("neili") < 100)
  #         return notify_fail("你目前的真气不足，难以施展" LIAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIY "$N" HIY "大喝一声，施出「" HIR "重阳连环掌" HIY "」，顿"
  #               "时双掌纷飞，向$n" HIY "猛攻而去。\n" NOR;
  #     message_combatd(msg, me, target);
  #     me->add("neili", -80);
  # 
  #         af = member_array("strike", keys(p));
  # 
  #         for (i = 0; i < 4; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  # 
  #                 me->set_temp("action_flag", af);
  #             COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  # 
  #     me->start_busy(1 + random(4));
  #     return 1;
  # }
end
