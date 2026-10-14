defmodule Kantele.Combat.Skills.Performs.MiaojiaJian.Gan do
  @moduledoc """
  perform「流星赶月」（对照 `kungfu/skill/miaojia-jian/gan.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 手持 sword 类武器 →
  苗家剑法>=200 → 内功>=280 → 内力上限>=3000 → 真气>=600 → 激发 `sword` 为苗家剑法 →
  目标存活。
  起手文案（含两次武器名 `wn`）在攻击方广播；命中判定 `ap/2 + random(ap)`
  （`ap = sword`）对目标 `dodge` 在目标侧结算：命中则攻击方忙乱 3、扣 500 真气，
  目标 qi 伤 `ap/2 + random(ap)` 再 `+random(该值)`、qi 上限伤 80%；
  未命中则攻击方忙乱 4、扣 500 真气。收尾按「苗家剑法 < 260」分两段文案
  （低熟练度武器脱手、高熟练度抄回），在攻击方广播。

  差异（TODO(migrate)）：
  - `.c` 把起手/分支/收尾累积到 `msg` 后一次 `message_combatd`；此处按引擎惯例拆分
    （起手与收尾在攻击方 `apply_effect` 广播，命中/未命中分支在目标侧广播，
    同 `guzhuo_zhang/yu.ex`），跨进程导致三段顺序不保证；
  - `wn = weapon->name()` 以本地变量复现；`.c` 用 `+` 断段处一律以变量分隔的
    `<>` 拼接（变量两侧不合并），逐段对齐；
  - 命中分支内的 `start_busy(3)` + `add("neili",-500)`、未命中分支的
    `start_busy(4)` + `add("neili",-500)` 经 `Performs.feedback/3` 跨进程回执；
  - `COMBAT_D->do_damage(...,damage,80,msg)` → `damage(:qi,damage)` +
    `wound(:qi, div(damage*80,100))` 并广播该文案；
  - `userp(me) && 苗家剑法<260` 分支中 `userp` 未建模（只按熟练度分档）；
    `weapon->move(environment(me))` 的脱手折算为 `Combat.unequip(:weapon)`
    （本引擎无地面掉落，同 `dugu_jiujian/po.ex`）；
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

  @perform_id "miaojia-jian/gan"
  @move_name "「流星赶月」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "miaojia-jian")
    # LPC: ap = me->query_skill("sword");
    ap = Stats.skill(stats, "sword")
    # LPC: wn = weapon->name();
    wn = weapon_name(combat)

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(stats),
         :ok <- check_max_neili(character),
         :ok <- check_neili(character),
         :ok <- check_mapped(stats),
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

      apply_effect(conn, character, target, wn, stats)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/miaojia-jian/gan"))
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
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #          (string)weapon->query("skill_type") != "sword")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      :ok
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("miaojia-jian", 1) < 200)
  #      if ((int)me->query_skill("force") < 280 )
  defp check_levels(stats) do
    cond do
      Stats.skill(stats, "miaojia-jian") < 200 ->
        {:error, "你苗家剑法不够娴熟，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "force") < 280 ->
        {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if ((int)me->query("max_neili") < 3000)
  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 3000 do
      {:error, "你的内力修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 600)
  defp check_neili(character) do
    if character.meta.vitals.neili < 600 do
      {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "miaojia-jian")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") != "miaojia-jian" do
      {:error, "你没有激发苗家剑法，难以施展#{@move_name}。\n"}
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

  defp apply_effect(conn, character, target, wn, stats) do
    # LPC: msg = HIY "$N" HIY "凝聚内力，手中" + wn + HIY "迸出万道光华，蓦然间破空"
    #            "声骤响，" + wn + HIY "竟离手射出，流星般向$n" HIY "奔去！\n" NOR;
    conn =
      Broadcast.publish(
        conn,
        "$N凝聚内力，手中" <>
          wn <> "迸出万道光华，蓦然间破空声骤响，" <> wn <> "竟离手射出，流星般向$n奔去！\n",
        n1: character.name,
        n2: target.name
      )

    # LPC: if (userp(me) && (int)me->query_skill("miaojia-jian", 1) < 260)
    #      { msg += HIY "只见" + wn + HIY "余势不尽，又向前飞出数丈，方才没入土中。\n" NOR;
    #        weapon->move(environment(me)); }
    #      else { msg += HIY "然而$N" HIY "身形一展，…将射出的" + wn + HIY "又抄回手中。\n" NOR; }
    {combat, conn} =
      if Stats.skill(stats, "miaojia-jian") < 260 do
        conn = Broadcast.publish(conn, "只见" <> wn <> "余势不尽，又向前飞出数丈，方才没入土中。\n", n1: character.name, n2: target.name)
        # LPC: weapon->move(environment(me)); —— 脱手折算为卸下主武器（无地面掉落）。
        {Combat.unequip(character.meta.combat, :weapon), conn}
      else
        conn =
          Broadcast.publish(
            conn,
            "然而$N身形一展，登时跃出数丈，掌出如风，将射出的" <> wn <> "又抄回手中。\n",
            n1: character.name,
            n2: target.name
          )

        {character.meta.combat, conn}
      end

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
    ap = max(Map.get(data, :ap, 0), 1)
    wn = Map.get(data, :wn)
    dp = Stats.skill(stats, "dodge")

    # LPC: if (ap / 2 + random(ap) > dp)
    #      { me->start_busy(3); damage = ap / 2 + random(ap); damage += random(damage);
    #        msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 80, "…");
    #        me->add("neili", -500); }
    #      else { me->start_busy(4);
    #        msg += "…终于躲闪开来。\n"; me->add("neili", -500); }
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      damage = div(ap, 2) + Engine.rand(rng, ap)
      damage = damage + Engine.rand(rng, damage)

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 80, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}
      Performs.feedback(attacker, 500, 3)

      conn
      |> Broadcast.publish(
        "$n顿时大惊失色，只觉胸口处一凉，那柄" <> wn <> "竟然已经穿胸透过，带出一蓬血雨！\n",
        bindings
      )
      |> put_character(character)
    else
      Performs.feedback(attacker, 500, 4)

      Broadcast.publish(
        conn,
        "$n见" <> wn <> "来势汹涌，心知绝不可挡，当即向后横移数尺，终于躲闪开来。\n",
        bindings
      )
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define GAN "「" HIY "流星赶月" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         object weapon;
  #         int ap, dp, wn;
  # 
  #         if (userp(me) && ! me->query("can_perform/miaojia-jian/gan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(GAN "只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" GAN "。\n");
  # 
  #         if ((int)me->query_skill("miaojia-jian", 1) < 200)
  #                 return notify_fail("你苗家剑法不够娴熟，难以施展" GAN "。\n");
  # 
  #         if ((int)me->query_skill("force") < 280 )
  #                 return notify_fail("你的内功火候不够，难以施展" GAN "。\n");
  # 
  #         if ((int)me->query("max_neili") < 3000)
  #                 return notify_fail("你的内力修为不够，难以施展" GAN "。\n");
  # 
  #         if ((int)me->query("neili") < 600)
  #                 return notify_fail("你现在真气不够，难以施展" GAN "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "miaojia-jian")
  #                 return notify_fail("你没有激发苗家剑法，难以施展" GAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         wn = weapon->name();
  # 
  #         msg = HIY "$N" HIY "凝聚内力，手中" + wn + HIY "迸出万道光华，蓦然间破空"
  #               "声骤响，" + wn + HIY "竟离手射出，流星般向$n" HIY "奔去！\n" NOR;
  # 
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("dodge");
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 me->start_busy(3);
  #                 damage = ap / 2 + random(ap);
  #                 damage += random(damage);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 80,
  #                                            HIR "$n" HIR "顿时大惊失色，只觉胸口处"
  #                                            "一凉，那柄" + wn + HIR "竟然已经穿胸透"
  #                                            "过，带出一蓬血雨！\n" NOR);
  #                 me->add("neili", -500);
  #         } else
  #         {
  #                 me->start_busy(4);
  #                 msg += HIC "$n" HIC "见" + wn + HIC "来势汹涌，心知绝"
  #                        "不可挡，当即向后横移数尺，终于躲闪开来。\n" NOR;
  #                 me->add("neili", -500);
  #         }
  # 
  #         if (userp(me) && (int)me->query_skill("miaojia-jian", 1) < 260)
  #         {
  #                 msg += HIY "只见" + wn + HIY "余势不尽，又向前飞出数"
  #                        "丈，方才没入土中。\n" NOR;
  #             weapon->move(environment(me));
  #     } else
  #                 msg += HIY "然而$N" HIY "身形一展，登时跃出数丈，掌"
  #                        "出如风，将射出的" + wn + HIY "又抄回手中。\n" NOR;
  # 
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
