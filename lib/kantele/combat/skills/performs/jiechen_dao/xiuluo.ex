defmodule Kantele.Combat.Skills.Performs.JiechenDao.Xiuluo do
  @moduledoc """
  perform「修罗焰」（source jiechen-dao/xiuluo.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：目标为战斗中的对手 → 手持刀 → 激发 blade 为戒尘刀 →
  戒尘刀>=180 → 基本刀法>=180 → 心意气混元功>=140 → 先天根骨
  `query_con()`>=34 → 激发 force 为心意气混元功 → 内力上限>=3000 →
  真气>=1000。
  起手广播后连出 `4+random(4)` 击（`COMBAT_D->do_attack`）。
  攻击方扣 600 真气（`.c` 的固定 300 + `xiuluo` 标记分支的 300）并忙乱
  `1+random(3)`（均为无条件）。

  差异（TODO(migrate)）：
  - `.c` 无 `can_perform` 门槛，故本文件不设「已知此招」检查（`perform_command.ex`
    已在调用点按 `perform_list` 放行）；
  - LPC 的 N 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线）折算为
    每击 `level` 基础判定 + 伤害（与 `honglian_dao/huo.ex` 同构）；
  - `.c` 在连击期间把 `jiali` 临时设为 `force/2 * (3+random(4))` 并
    `add_temp("apply/attack", jiali/2)`（收招后还原）——该临时加成已折入上述
    每击 `level` 模型，本引擎不落 `combat.jiali`；
  - `.c` 收招时 `if(!me->query_temp("xiuluo")) me->add("neili", -300); else
    me->delete_temp("xiuluo");` 的 `xiuluo` 标记在本引擎无处设置，故恒走
    「扣 300」分支（合计扣 600）；
  - `.c` 循环内的 `if (! me->is_fighting(target)) break;` 未建模（目标侧单次结算）。
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

  @perform_id "jiechen-dao/xiuluo"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jiechen-dao")
    # LPC: count = 4; count += random(4);
    strikes = 4 + Engine.rand(rng, 4)

    with {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_mapped(character),
         :ok <- check_levels(character),
         :ok <- check_con(character),
         :ok <- check_force_mapped(character),
         :ok <- check_resources(character) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          strikes: strikes,
          rng: rng
        }
      })

      apply_effect(conn, character, target, rng)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: 该文件无 can_perform 门槛（`jiechen-dao.c` 中 set_temp("xiuluo") 已被注释），
  # 故不设「已知此招」检查；调用点由 perform_command.ex 的 perform_list 放行。

  # LPC: if( !target || !target->is_character() || !me->is_fighting(target) || !living(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「修罗焰」攻击只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #          (string)weapon->query("skill_type") != "blade")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon != nil and Map.get(weapon, :skill_type) == "blade" do
      :ok
    else
      {:error, "你先找把刀再说吧！\n"}
    end
  end

  # LPC: if (me->query_skill_mapped("blade") != "jiechen-dao")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "blade") == "jiechen-dao" do
      :ok
    else
      {:error, "你必须使用戒尘刀来施展「修罗焰」。\n"}
    end
  end

  # LPC: if(me->query_skill("jiechen-dao", 1) < 180 ) / if(me->query_skill("blade", 1) < 180 )
  #      / if( (int)me->query_skill("hunyuan-yiqi", 1) < 140 )
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "jiechen-dao") < 180 ->
        {:error, "你的戒尘刀火候还嫌不够，这「修罗焰」绝技不用也罢。\n"}

      Stats.skill(stats, "blade") < 180 ->
        {:error, "你的基本刀法还不够娴熟，使不出「修罗焰」绝技。\n"}

      Stats.skill(stats, "hunyuan-yiqi") < 140 ->
        {:error, "你的心意气混元功等级不够，使不出「修罗焰」绝技。\n"}

      true ->
        :ok
    end
  end

  # LPC: if( (int)me->query_con() < 34)
  defp check_con(character) do
    if Stats.query_con(character.meta.stats) < 34 do
      {:error, "你的身体还不够强壮，强使「修罗焰」绝技是引火自焚！\n"}
    else
      :ok
    end
  end

  # LPC: if ( me->query_skill_mapped("force") != "hunyuan-yiqi")
  defp check_force_mapped(character) do
    if Stats.mapped(character.meta.stats, "force") == "hunyuan-yiqi" do
      :ok
    else
      {:error, "你现在这内功平平无奇，如何使得出「修罗焰」绝技来！？\n"}
    end
  end

  # LPC: if (me->query("max_neili") < 3000) / if (me->query("neili") < 1000)
  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 3000 -> {:error, "你的内力修为不够，这「修罗焰」绝技不用也罢。\n"}
      vitals.neili < 1000 -> {:error, "以你目前的内力来看，这「修罗焰」绝技不用也罢。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character, target, rng) do
    # LPC: me->add("neili", -300);
    #      message_vision(HIR "\n突然$N将手中武器从右手交到左手，运出十二分真力，脸色顿时通红，\n"
    #                         "宛如修罗降世。刀刃在内力的催动下立刻攻势大胜，\n"
    #                         "向着$n直劈而下！\n" NOR, me, target);
    #      i = me->query_skill("force") / 2 * (3+random(4)); jiali = me->query("jiali");
    #      me->set("jiali", i); me->add_temp("apply/attack", jiali/2);
    #      count = 4 + random(4); while (count--) COMBAT_D->do_attack(me, target, weapon, 0);
    #      me->add_temp("apply/attack", -jiali/2); me->set("jiali", jiali);
    #      if(!me->query_temp("xiuluo")) me->add("neili", -300); else me->delete_temp("xiuluo");
    #      me->start_busy(1+random(3));
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 600}
    combat = Combat.start_busy(character.meta.combat, 1 + Engine.rand(rng, 3))
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    conn
    |> Broadcast.publish(
      "\n突然$N将手中武器从右手交到左手，运出十二分真力，脸色顿时通红，\n" <>
        "宛如修罗降世。刀刃在内力的催动下立刻攻势大胜，\n向着$n直劈而下！\n",
      n1: character.name,
      n2: target.name
    )
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    # .c 的 living(target) 门槛由目标侧 death 检查兜底
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, _attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    level = max(Map.get(data, :level, 0), 1)
    strikes = Map.get(data, :strikes, 4)
    dodge = Stats.skill(character.meta.stats, "dodge")

    # LPC 连击 count 次，每次 COMBAT_D->do_attack(me, target, weapon, 0)
    damage =
      Enum.reduce(1..strikes, 0, fn _, acc ->
        if div(level, 2) + Engine.rand(rng, level) > dodge do
          acc + level + Engine.rand(rng, level)
        else
          acc
        end
      end)

    vitals =
      if damage > 0 do
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage, 3))
      else
        character.meta.vitals
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn
    |> put_character(character)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #        int i, jiali, count; 
  #         // string msg;
  #        object weapon;
  # 
  #        if( !target ) target = offensive_target(me);
  #        if( !target
  #                 || !target->is_character()
  #                 || !me->is_fighting(target)
  #                 || !living(target))
  #                 return notify_fail("「修罗焰」攻击只能对战斗中的对手使用。\n");
  #        if (! objectp(weapon = me->query_temp("weapon")) ||
  #           (string)weapon->query("skill_type") != "blade")
  #                 return notify_fail("你先找把刀再说吧！\n");
  # 
  #         if (me->query_skill_mapped("blade") != "jiechen-dao")
  #                 return notify_fail("你必须使用戒尘刀来施展「修罗焰」。\n");
  # 
  #         if(me->query_skill("jiechen-dao", 1) < 180 )
  #                 return notify_fail("你的戒尘刀火候还嫌不够，这「修罗焰」绝技不用也罢。\n");
  # 
  #         if(me->query_skill("blade", 1) < 180 )
  #                 return notify_fail("你的基本刀法还不够娴熟，使不出「修罗焰」绝技。\n");
  # 
  #         if( (int)me->query_skill("hunyuan-yiqi", 1) < 140 )
  #                 return notify_fail("你的心意气混元功等级不够，使不出「修罗焰」绝技。\n");
  # 
  #         if( (int)me->query_con() < 34)
  #                 return notify_fail("你的身体还不够强壮，强使「修罗焰」绝技是引火自焚！\n");
  # 
  #         if ( me->query_skill_mapped("force") != "hunyuan-yiqi")
  #            return notify_fail("你现在这内功平平无奇，如何使得出「修罗焰」绝技来！？\n");
  # 
  #         if (me->query("max_neili") < 3000)
  #            return notify_fail("你的内力修为不够，这「修罗焰」绝技不用也罢。\n");
  # 
  #         if (me->query("neili") < 1000)
  #            return notify_fail("以你目前的内力来看，这「修罗焰」绝技不用也罢。\n");
  # 
  #         me->add("neili", -300);
  # 
  #         message_vision(HIR "\n突然$N将手中武器从右手交到左手，运出十二分真力，脸色顿时通红，\n"
  #                            "宛如修罗降世。刀刃在内力的催动下立刻攻势大胜，\n"
  #                            "向着$n直劈而下！\n" NOR, me, target);
  # 
  #         i = me->query_skill("force") / 2 * (3+random(4));
  #         jiali = me->query("jiali");
  # 
  #         me->set("jiali", i);
  #         me->add_temp("apply/attack", jiali/2);
  # 
  #         count = 4;
  #         count += random(4);
  #         while (count --)
  #         {
  # 
  #               COMBAT_D->do_attack(me, target, me->query_temp("weapon"), 0);
  #         }
  # 
  #         me->add_temp("apply/attack", -jiali/2);
  #         me->set("jiali", jiali);
  #         if(!me->query_temp("xiuluo")) me->add("neili", -300);
  #         else me->delete_temp("xiuluo");
  # 
  #         me->start_busy(1+random(3));
  #         return 1;
  # }
end
