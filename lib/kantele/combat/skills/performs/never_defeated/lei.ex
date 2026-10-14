defmodule Kantele.Combat.Skills.Performs.NeverDefeated.Lei do
  @moduledoc """
  perform「天打雷劈」（对照 `kungfu/skill/never-defeated/perform/lei.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 不败神功>=150 → 手持兵刃 →
  真气>=300 → 目标存活。
  起手文案（含武器名 `weapon->name()`）在攻击方广播；攻击方无条件扣 60 真气、
  忙乱 `1 + random(2)`。
  目标侧以 `ap = 不败神功` 对抗 `dp = 目标 combat_exp/10000`：
  - `dp >= 100` → 「使出平生所学，奋力化解，没出一点差错。」；
  - 否则 `random(ap) > dp` → 「平生何曾见过这样的招数…颓然倒地！」并**目标即死**；
  - 否则 → 「大吃一惊，连忙胡乱抵挡，居然没有一点伤害，侥幸得脱！」。

  差异（TODO(migrate)）：
  - `.c` 未列「是否已学此招」门槛（`can_perform`），本引擎以框架层
    `perform_known?/2` 统一把关（多出的文案不影响对齐）；
  - `.c` 把起手与分支文案累积到 `msg` 后一次 `message_combatd`；此处按引擎惯例拆分
    （起手在攻击方 `apply_effect` 广播，分支在目标侧广播，同 `guzhuo_zhang/yu.ex`）；
  - `me->add("neili",-60)` 与 `me->start_busy(1+random(2))` 无条件 → 攻击方直接结算；
  - `target->die(me)` 即死 → 目标侧 `qi: 0` + `combat.dead: true`
    （先例 `bluesea_force/mie.ex`；`.c` 在 `die` 前先 `message_combatd`，故先广播后置死）；
  - `me->want_kill(target)` 敌对标记引擎未建模（同既有先例）；
  - `!living(target)` 门槛在攻击方无 meta 可查，恒判存活，由目标侧
    `combat/perform-incoming` 的死亡检查兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine

  @perform_id "never-defeated/lei"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "never-defeated")
    wn = weapon_name(combat)

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_level(stats),
         :ok <- check_weapon(combat),
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
          rng: rng
        }
      })

      apply_effect(conn, character, target, wn, rng)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: 本式无 can_perform 门槛，框架层统一把关（见 moduledoc 差异说明）。
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "天打雷劈只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (me->query_skill("never-defeated", 1) < 150)
  defp check_level(stats) do
    if Stats.skill(stats, "never-defeated") < 150 do
      {:error, "你的不败神功还不够娴熟，不能使用天打雷劈！\n"}
    else
      :ok
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")))
  defp check_weapon(combat) do
    if Combat.weapon(combat) do
      :ok
    else
      {:error, "你必须手持兵刃才能施展天打雷劈！\n"}
    end
  end

  # LPC: if (me->query("neili") < 300)
  defp check_neili(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你的真气不够！\n"}
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

  defp apply_effect(conn, character, target, wn, rng) do
    # LPC: msg = HIC "$N" HIC "大喝一声，手中的" + weapon->name() +
    #            HIC "长劈而下，看似简单，竟然封住了$n"
    #            HIC "所有的退路！\n" NOR;
    conn =
      Broadcast.publish(
        conn,
        "$N大喝一声，手中的" <> wn <> "长劈而下，看似简单，竟然封住了$n所有的退路！\n",
        n1: character.name,
        n2: target.name
      )

    # LPC: me->add("neili", -60);  me->start_busy(1 + random(2));
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 60}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    combat = Combat.start_busy(character.meta.combat, 1 + Engine.rand(rng, 2))
    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp weapon_name(combat) do
    case Combat.weapon(combat) do
      nil -> nil
      weapon -> Map.get(weapon, :name)
    end
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
    # LPC: ap = me->query_skill("never-defeated", 1);
    ap = max(Map.get(data, :skill, 0), 1)

    # LPC: dp = target->query("combat_exp") / 10000;
    dp = div(stats.combat_exp || 0, 10_000)

    # LPC: if (dp >= 100) { msg += "…没出一点差错。\n"; }
    #      else if (random(ap) > dp) { msg += "…颓然倒地！\n";
    #                                 message_combatd(msg, me, target);
    #                                 target->die(me); return 1; }
    #      else { msg += "…侥幸得脱！\n"; }
    cond do
      dp >= 100 ->
        Broadcast.publish(
          conn,
          "$n使出平生所学，奋力化解，没出一点差错。\n",
          bindings
        )

      Engine.rand(rng, ap) > dp ->
        conn =
          Broadcast.publish(
            conn,
            "$n平生何曾见过这样的招数，全然无法化解，顿时被击中数处要害，颓然倒地！\n",
            bindings
          )

        # LPC: target->die(me);（先广播后置死，与 .c 次序一致）
        vitals = %{character.meta.vitals | qi: 0}
        combat = %{character.meta.combat | dead: true}
        character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

        conn
        |> put_character(character)

      true ->
        Broadcast.publish(
          conn,
          "$n大吃一惊，连忙胡乱抵挡，居然没有一点伤害，侥幸得脱！\n",
          bindings
        )
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // lei.c 天打雷劈
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #     string msg;
  #         int ap, dp;
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #             return notify_fail("天打雷劈只能在战斗中对对手使用。\n");
  # 
  #     if (me->query_skill("never-defeated", 1) < 150)
  #         return notify_fail("你的不败神功还不够娴熟，不能使用天打雷劈！\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")))
  #                 return notify_fail("你必须手持兵刃才能施展天打雷劈！\n");
  # 
  #     if (me->query("neili") < 300)
  #         return notify_fail("你的真气不够！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIC "$N" HIC "大喝一声，手中的" + weapon->name() +
  #               HIC "长劈而下，看似简单，竟然封住了$n"
  #               HIC "所有的退路！\n" NOR;
  # 
  #         ap = me->query_skill("never-defeated", 1);
  #         dp = target->query("combat_exp") / 10000;
  #     me->add("neili", -60);
  #     me->start_busy(1 + random(2));
  # 
  #     me->want_kill(target);
  #         if (dp >= 100)
  #         {
  #                 msg += HIY "$n" HIY "使出平生所学，奋力化解，没出一点差错。\n" NOR;
  #         } else
  #         if (random(ap) > dp)
  #         {
  #                 msg += HIR "$n" HIR "平生何曾见过这样的招数，全然无法化解，"
  #                        HIR "顿时被击中数处要害，颓然倒地！\n" NOR;
  #                 message_combatd(msg, me, target);
  #                 target->die(me);
  #                 return 1;
  #         } else
  #         {
  #                 msg += HIM "$n" HIM "大吃一惊，连忙胡乱抵挡，居"
  #                       "然没有一点伤害，侥幸得脱！\n" NOR;
  #         }
  # 
  #         message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
