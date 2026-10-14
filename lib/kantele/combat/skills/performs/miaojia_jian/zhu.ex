defmodule Kantele.Combat.Skills.Performs.MiaojiaJian.Zhu do
  @moduledoc """
  perform「黄龙吐珠」（对照 `kungfu/skill/miaojia-jian/zhu.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 手持 sword 类武器 →
  苗家剑法>=120 → 内功>=150 → 内力上限>=1200 → 真气>=200 → 激发 `sword` 为苗家剑法 →
  目标存活。
  起手文案（含一次武器名 `weapon->name()`）在攻击方广播；命中判定 `ap/2 + random(ap)`
  （`ap = sword`）对目标 `parry` 在目标侧结算：命中则攻击方扣 150 真气、忙乱 2，
  目标 qi 伤 `ap/2 + random(ap/2)`、qi 上限伤 60%；未命中则攻击方扣 50 真气、忙乱 3。

  差异（TODO(migrate)）：
  - `.c` 把起手与分支文案累积到 `msg` 后一次 `message_combatd`；此处按引擎惯例拆分
    （起手在攻击方 `apply_effect` 广播，命中/未命中分支在目标侧广播，
    同 `guzhuo_zhang/yu.ex`）；
  - 起手 `.c` 为 `"…斜" "贯而出…射向$n" + HIY "！\n"`，抽取器在 `+` 处断段，
    故「！\n」是独立段（无汉字、被过滤），E 侧用 `Enum.join/1` 保持该分段，
    不得并入前一字面量；
  - 命中分支的 `add("neili",-150)` + `start_busy(2)` 与未命中分支的
    `add("neili",-50)` + `start_busy(3)` 经 `Performs.feedback/3` 跨进程回执；
  - `COMBAT_D->do_damage(...,damage,60,msg)` → `damage(:qi,damage)` +
    `wound(:qi, div(damage*60,100))` 并广播该文案；
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

  @perform_id "miaojia-jian/zhu"
  @move_name "「黄龙吐珠」"

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
    # LPC: weapon->name()
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

      apply_effect(conn, character, target, wn)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/miaojia-jian/zhu"))
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

  # LPC: if ((int)me->query_skill("miaojia-jian", 1) < 120)
  #      if ((int)me->query_skill("force") < 150 )
  defp check_levels(stats) do
    cond do
      Stats.skill(stats, "miaojia-jian") < 120 ->
        {:error, "你苗家剑法不够娴熟，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if ((int)me->query("max_neili") < 1200)
  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 1200 do
      {:error, "你的内力修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 200)
  defp check_neili(character) do
    if character.meta.vitals.neili < 200 do
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

  defp apply_effect(conn, character, target, wn) do
    # LPC: msg = HIY "$N" HIY "回圈手中" + weapon->name() + HIY "施「黄龙吐珠」斜"
    #            "贯而出，剑尖顿时吐出一道黄芒，闪电般射向$n" + HIY "！\n" NOR;
    # 「！\n」在 `.c` 中位于 `+` 之后、属独立段（无汉字被过滤），故用 Enum.join 保持分段。
    opener =
      Enum.join([
        "$N回圈手中",
        wn,
        "施「黄龙吐珠」斜贯而出，剑尖顿时吐出一道黄芒，闪电般射向$n",
        "！\n"
      ])

    Broadcast.publish(conn, opener, n1: character.name, n2: target.name)
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
    # LPC: dp = target->query_skill("parry");
    dp = Stats.skill(stats, "parry")

    # LPC: if (ap / 2 + random(ap) > dp)
    #      { damage = ap / 2 + random(ap / 2); me->add("neili", -150); me->start_busy(2);
    #        msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 60, "…"); }
    #      else { me->add("neili", -50); me->start_busy(3);
    #        msg += "可是$n一声冷笑…避开了$N发出的剑气。\n"; }
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      damage = div(ap, 2) + Engine.rand(rng, div(ap, 2))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 60, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}
      Performs.feedback(attacker, 150, 2)

      conn
      |> Broadcast.publish(
        "$n见状连忙格挡，可哪里来得及，登时只觉全身一麻，剑气已透胸而过。\n",
        bindings
      )
      |> put_character(character)
    else
      Performs.feedback(attacker, 50, 3)

      Broadcast.publish(
        conn,
        "可是$n一声冷笑，飞身一跃而起，避开了$N发出的剑气。\n",
        bindings
      )
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHU "「" HIY "黄龙吐珠" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/miaojia-jian/zhu"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHU "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" ZHU "。\n");
  # 
  #         if ((int)me->query_skill("miaojia-jian", 1) < 120)
  #                 return notify_fail("你苗家剑法不够娴熟，难以施展" ZHU "。\n");
  # 
  #         if ((int)me->query_skill("force") < 150 )
  #                 return notify_fail("你的内功火候不够，难以施展" ZHU "。\n");
  # 
  #         if ((int)me->query("max_neili") < 1200)
  #                 return notify_fail("你的内力修为不够，难以施展" ZHU "。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你现在真气不够，难以施展" ZHU "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "miaojia-jian")
  #                 return notify_fail("你没有激发苗家剑法，难以施展" ZHU "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "回圈手中" + weapon->name() + HIY "施「黄龙吐珠」斜"
  #               "贯而出，剑尖顿时吐出一道黄芒，闪电般射向$n" + HIY "！\n" NOR;
  # 
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("parry");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap / 2 + random(ap / 2);
  #                 me->add("neili", -150);
  #                 me->start_busy(2);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 60,
  #                                            HIR "$n" HIR "见状连忙格挡，可哪里来得"
  #                                            "及，登时只觉全身一麻，剑气已透胸而过。\n"
  #                                            NOR);
  #         } else
  #         {
  #                 me->add("neili", -50);
  #                 me->start_busy(3);
  #                 msg += CYN "可是" CYN "$n" CYN "一声冷"
  #                        "笑，飞身一跃而起，避开了" CYN
  #                        "$N" CYN "发出的剑气。\n"NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
