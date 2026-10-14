defmodule Kantele.Combat.Skills.Performs.NeverDefeated.Juemie do
  @moduledoc """
  perform「天地绝灭」（对照 `kungfu/skill/never-defeated/perform/juemie.c`，源注释 juemi.c）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 不败神功>=120 → 手持兵刃 →
  真气>=200 → 目标存活。
  起手文案（含武器名）在攻击方广播；攻击方无条件忙乱 2、扣 50 真气。
  命中判定 `ap/2 + random(ap)`（`dp = 目标 dodge + dex*20 + 目标 martical-cognize`，
  `.c` 为「ap/2 + random(ap) < dp 则失手」）在目标侧结算：命中则攻击方再扣 70 真气，
  目标 qi 伤 `ap/2 + random(ap/3)`、qi 上限伤 40%。

  差异（TODO(migrate)）：
  - `.c` 未列「是否已学此招」门槛（`can_perform`），本引擎以框架层
    `perform_known?/2` 统一把关（多出的文案不影响对齐）；
  - `me->clean_up_enemy(); target = me->select_opponent();` 折算为取
    `combat.enemies` 头部（`clean_up_enemy` 清理已阵亡敌人无对应物，未建模）；
  - `.c` 把起手与分支文案累积到 `msg` 后一次 `message_combatd`；此处按引擎惯例拆分
    （起手在攻击方 `apply_effect` 广播，分支在目标侧广播，同 `guzhuo_zhang/yu.ex`）；
  - `me->start_busy(2)` 无条件、`me->add("neili",-50)` 无条件 → 攻击方直接结算；
    命中分支内的 `me->add("neili",-70)` 经 `Performs.feedback/3` 回执；
  - `COMBAT_D->do_damage(...,damage,40,msg)` → `damage(:qi,damage)` +
    `wound(:qi, div(damage*40,100))` 并广播该文案；
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

  @perform_id "never-defeated/juemie"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "never-defeated")
    wn = weapon_name(combat)

    # LPC: ap = me->query_skill("never-defeated", 1) * 3 / 2 + me->query("int") * 20 +
    #             me->query_skill("martial-cognize", 1);
    ap =
      div(Stats.skill(stats, "never-defeated") * 3, 2) +
        Stats.query_int(stats) * 20 + Stats.skill(stats, "martial-cognize")

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
          ap: ap,
          wn: wn,
          rng: rng
        }
      })

      apply_effect(conn, character, target, wn)
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

  # LPC: if (! target) { me->clean_up_enemy(); target = me->select_opponent(); }
  #      if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "天地绝灭只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_skill("never-defeated", 1) < 120)
  defp check_level(stats) do
    if Stats.skill(stats, "never-defeated") < 120 do
      {:error, "你的不败神功还不够娴熟，不能使用天地绝灭！\n"}
    else
      :ok
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")))
  defp check_weapon(combat) do
    if Combat.weapon(combat) do
      :ok
    else
      {:error, "你必须手持兵刃才能施展天地绝灭！\n"}
    end
  end

  # LPC: if (me->query("neili") < 200)
  defp check_neili(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你的内力不够，不能使用天地绝灭！\n"}
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

  defp apply_effect(conn, character, target, wn) do
    # LPC: msg = HIC "$N" HIC "随便走了几步，忽然一荡手中的" + weapon->name() +
    #            HIC "，迅捷无比的扫向$n" HIC "，变化复杂之极，不可思议！\n" NOR;
    conn =
      Broadcast.publish(
        conn,
        "$N随便走了几步，忽然一荡手中的" <> wn <> "，迅捷无比的扫向$n，变化复杂之极，不可思议！\n",
        n1: character.name,
        n2: target.name
      )

    # LPC: me->start_busy(2);  me->add("neili", -50);
    combat = Combat.start_busy(character.meta.combat, 2)
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 50}
    character = %{character | meta: %{character.meta | combat: combat, vitals: vitals}}

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
    ap = max(Map.get(data, :ap, 0), 1)

    # LPC: dp = target->query_skill("dodge") + target->query("dex") * 20 +
    #             target->query_skill("martial-cognize", 1);
    dp =
      Stats.skill(stats, "dodge") + Stats.query_dex(stats) * 20 +
        Stats.skill(stats, "martial-cognize")

    # LPC: if (ap / 2 + random(ap) < dp) { msg += "…就躲过了$N这一击！\n"; }
    #      else { me->add("neili",-70); damage = ap / 2 + random(ap / 3);
    #             msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 40, "…"); }
    if div(ap, 2) + Engine.rand(rng, ap) < dp do
      Broadcast.publish(
        conn,
        "$n只见并不慌张，只是轻轻一闪，就躲过了$N这一击！\n",
        bindings
      )
    else
      # LPC: me->add("neili", -70);（命中分支内）
      Performs.feedback(attacker, 70, 0)

      damage = div(ap, 2) + Engine.rand(rng, div(ap, 3))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 40, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      conn
      |> Broadcast.publish(
        "$n连忙格挡，可是这一招实在是鬼神莫测，哪里琢磨得透？登时中了$P的重创！\n",
        bindings
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // juemi.c 天地绝灭
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
  #     int ap, dp;
  #         int damage;
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail("天地绝灭只能对战斗中的对手使用。\n");
  # 
  #     if (me->query_skill("never-defeated", 1) < 120)
  #         return notify_fail("你的不败神功还不够娴熟，不能使用天地绝灭！\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")))
  #                 return notify_fail("你必须手持兵刃才能施展天地绝灭！\n");
  # 
  #         if (me->query("neili") < 200)
  #                 return notify_fail("你的内力不够，不能使用天地绝灭！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIC "$N" HIC "随便走了几步，忽然一荡手中的" + weapon->name() +
  #               HIC "，迅捷无比的扫向$n" HIC "，变化复杂之极，不可思议！\n" NOR;
  # 
  #     ap = me->query_skill("never-defeated", 1) * 3 / 2 + me->query("int") * 20 +
  #              me->query_skill("martial-cognize", 1);
  #     dp = target->query_skill("dodge") + target->query("dex") * 20 +
  #              target->query_skill("martial-cognize", 1);
  # 
  #         me->start_busy(2);
  #         me->add("neili", -50);
  #         if (ap / 2 + random(ap) < dp)
  #         {
  #         msg += HIG "只见$n" HIG "并不慌张，只是轻轻一闪，就躲过了$N"
  #                    HIG "这一击！\n"NOR;
  #         } else
  #     {
  #         me->add("neili",-70);
  #                 damage = ap / 2 + random(ap / 3);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 40,
  #                                            HIR "$n" HIR "连忙格挡，可是这一招实在是鬼神莫"
  #                                            "测，哪里琢磨得透？登时中了$P" HIR "的重创！\n" NOR);
  #     }
  # 
  #     message_combatd(msg, me, target);
  #     return 1;
  # }
end
