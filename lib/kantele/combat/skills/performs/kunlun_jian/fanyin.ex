defmodule Kantele.Combat.Skills.Performs.KunlunJian.Fanyin do
  @moduledoc """
  perform「域外梵音」（source kunlun-jian/fanyin.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 装备剑类武器 →
  弹琴技法>=120 → 昆仑剑法>=120 → 内功>=180 → 内力上限>=2000 → 内力>=300 →
  激发 sword 为昆仑剑法 → 目标存活。
  ap = 剑法；dp = 目标内功（至少 1）。命中判定：random(ap) > dp/2。
  命中：伤害 = (剑法+弹琴技法)/2 + random((剑法+弹琴技法)/2)、60% 外伤
        （WEAPON_ATTACK），扣 200 内力、忙乱 2+random(2)；
  未命中：扣 50 内力、忙乱 3。

  差异（TODO(migrate)）：
  - 起手式被 weapon->name() 拆成两段字面量（前段含「五指对准」相邻字面量合并），
    E 侧用 <> weapon_name <> 保持拆分；
  - `living(target)` 门槛在攻击方无 meta 可查时恒判存活，由目标侧
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
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs
  alias Kantele.Character.Vitals

  @perform_id "kunlun-jian/fanyin"
  @move_name "「域外梵音」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "kunlun-jian")
    ap = Stats.skill(stats, "sword")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_mapped(character),
         :ok <- check_target_alive(target) do
      weapon_name = Map.get(weapon, :name)

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
          # 起手式含 weapon->name()（攻击方武器名），经事件数据传给目标侧
          weapon_name: weapon_name,
          rng: rng
        }
      })

      apply_effect(conn, character, target, weapon_name)
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

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #              (string)weapon->query("skill_type") != "sword")
  # 武器结构体字段是 :skill_type（非 LPC 的 query("skill_type")）
  defp check_weapon(combat) do
    case Combat.weapon(combat) do
      %{skill_type: "sword"} = weapon -> {:ok, weapon}
      _ -> {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill("tanqin-jifa", 1) < 120)
  #          return notify_fail("你的弹琴技法尚且不够熟练, 难以施展" FANYIN "。\n");
  #     if (me->query_skill("kunlun-jian", 1) < 120)
  #          return notify_fail("你的昆仑剑法等级不够, 难以施展" FANYIN "。\n");
  #     if (me->query_skill("force") < 180)
  # （前两条 .c 用半角逗号+空格，逐字保留）
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "tanqin-jifa") < 120 ->
        {:error, "你的弹琴技法尚且不够熟练, 难以施展#{@move_name}。\n"}

      Stats.skill(stats, "kunlun-jian") < 120 ->
        {:error, "你的昆仑剑法等级不够, 难以施展#{@move_name}。\n"}

      Stats.skill(stats, "force") < 180 ->
        {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query("max_neili") < 2000) / if (me->query("neili") < 300)
  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 2000 -> {:error, "你的内力修为尚浅，难以施展#{@move_name}。\n"}
      vitals.neili < 300 -> {:error, "你的真气不够，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "kunlun-jian")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "sword") != "kunlun-jian" do
      {:error, "你没有激发昆仑剑法，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  # LPC: msg = MAG "$N" MAG "微微一笑，左手横握剑柄，右手五"
  #               "指对准" + weapon->name() + NOR + MAG "剑脊"
  #               "轻轻弹拨，剑身微颤，声若龙吟。\n顿时发出一"
  #               "阵清脆的琴音……\n" NOR;
  # 前后两段各自由相邻字面量合并而成，中间被 weapon->name() 拆开，
  # E 侧用 <> weapon_name <> 保持拆分
  defp apply_effect(conn, character, target, weapon_name) do
    msg =
      "$N微微一笑，左手横握剑柄，右手五指对准" <> weapon_name <>
        "剑脊轻轻弹拨，剑身微颤，声若龙吟。\n顿时发出一阵清脆的琴音……\n"

    conn
    |> Broadcast.publish(Messages.interpolate(msg, [n1: character.name, n2: target.name]))
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
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("force"); if (dp < 1) dp = 1;
    dp = max(Stats.skill(stats, "force"), 1)

    # LPC: if (random(ap) > dp / 2)
    if Engine.rand(rng, ap) > div(dp, 2) do
      # LPC: jing_wound = sword + tanqin-jifa;
      #          jing_wound = jing_wound / 2 + random(jing_wound / 2);
      #          do_damage(me, target, WEAPON_ATTACK, jing_wound, 60, …);
      #          me->add("neili", -200); me->start_busy(2 + random(2));
      base = ap + Stats.skill(stats, "tanqin-jifa")
      damage = div(base, 2) + Engine.rand(rng, div(base, 2))
      character = apply_damage(character, damage, 60)
      Performs.feedback(attacker, 200, 2 + Engine.rand(rng, 2))

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "$n顿时只觉琴音犹如两柄利剑一般刺进双耳，刹那间头晕目眩，全身刺痛！\n",
          bindings
        )
      )
      |> put_character(character)
    else
      # LPC: me->add("neili", -50); me->start_busy(3);
      Performs.feedback(attacker, 50, 3)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "可是$n赶忙宁心静气，收敛心神，丝毫不受$N琴音的干扰。\n",
          bindings
        )
      )
      |> put_character(character)
    end
  end

  # LPC: COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, percent, msg)
  # wound = damage * percent / 100（armor 未建模，按 percent 直算）
  defp apply_damage(character, damage, percent) do
    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage * percent, 100))

    %{character | meta: %{character.meta | vitals: vitals}}
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define FANYIN "「" MAG "域外梵音" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me)
  # {
  #         string msg;
  #         object weapon, target;
  #         int skill, ap, dp, jing_wound;
  # 
  #         if (userp(me) && ! me->query("can_perform/kunlun-jian/fanyin"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(FANYIN "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" FANYIN "。\n");
  # 
  #         if (me->query_skill("tanqin-jifa", 1) < 120)
  #                 return notify_fail("你的弹琴技法尚且不够熟练, 难以施展" FANYIN "。\n");
  # 
  #         if (me->query_skill("kunlun-jian", 1) < 120)
  #                 return notify_fail("你的昆仑剑法等级不够, 难以施展" FANYIN "。\n");
  # 
  #         if (me->query_skill("force") < 180)
  #                 return notify_fail("你的内功修为不够，难以施展" FANYIN "。\n");
  # 
  #         if (me->query("max_neili") < 2000)
  #                 return notify_fail("你的内力修为尚浅，难以施展" FANYIN "。\n");
  # 
  #         if (me->query("neili") < 300)
  #                 return notify_fail("你的真气不够，难以施展" FANYIN "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "kunlun-jian")
  #                 return notify_fail("你没有激发昆仑剑法，难以施展" FANYIN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = MAG "$N" MAG "微微一笑，左手横握剑柄，右手五"
  #               "指对准" + weapon->name() + NOR + MAG "剑脊"
  #               "轻轻弹拨，剑身微颤，声若龙吟。\n顿时发出一"
  #               "阵清脆的琴音……\n" NOR;
  # 
  #         skill = me->query_skill("kunlun-jian", 1);
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("force");
  #         if (dp < 1) dp = 1;
  #         if (random(ap) > dp / 2)
  #         {
  #                 me->add("neili", -200);
  #                 jing_wound = (int)me->query_skill("sword") +
  #                              (int)me->query_skill("tanqin-jifa", 1);
  #                 jing_wound = jing_wound / 2 + random(jing_wound / 2);
  # 
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK,
  #                        jing_wound, 60, MAG "$n" MAG "顿时只觉琴音犹"
  #                        "如两柄利剑一般刺进双耳，刹那间头晕目眩，全身"
  #                        "刺痛！\n" NOR);
  #                 me->start_busy(2 + random(2));
  #         } else
  #         {
  #                 me->add("neili", -50);
  #                 msg += CYN "可是$n" CYN "赶忙宁心静气，收敛心神，丝"
  #                        "毫不受$N" CYN "琴音的干扰。\n" NOR;
  #                 me->start_busy(3);
  #         }
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
