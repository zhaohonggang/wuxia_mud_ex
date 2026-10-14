defmodule Kantele.Combat.Skills.Performs.LiumaiShenjian.Six do
  @moduledoc """
  perform「六脉剑气」（source liumai-shenjian/six.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 准备 finger 为六脉神剑 →
  六脉神剑>=220 → 内功>=400 → 最大内力>=7000 → 真气>=500 → 空手 → 目标存活。
  起手广播为单段合并文案；随后 `ap/2 + random(ap) > dp`（ap = finger，
  dp = 目标 force）命中则播「心萌退意」并令目标 parry/dodge 临时下降 skill/5；
  之后连出 6 指剑气（每击命中判定 + 基础伤害，折算自 `COMBAT_D->do_attack`），
  每击一半几率令目标忙乱 1；结束后撤除临时下降。攻击方无条件扣 400 真气、
  忙乱 1+random(5)。

  差异（TODO(migrate)）：
  - LPC 的 6 次 `COMBAT_D->do_attack(me, target, 0, i * 3)`（完整 AP/DP/招架/
    伤害管线）折算为每击 `skill/15` 基础伤害 + 命中判定 `skill/2 + random(skill)`
    vs 目标 dodge（同 feifeng-bian/xi、duanjia-sword/jue）；
  - `me->set_temp("liumai-shenjian/hit_msg", i)` 由技能侧 hit_msg 表选文案，
    本框架无对应机制，do_attack 的通用文案不由本模块发出；
  - `me->is_fighting(target)` 循环内中断条件：目标侧 enemies 为空即停；
  - SIX 宏展开+去色后合并为单段「六脉剑气」，E 侧用 @move_name 属性插值复现；
  - `living(target)` 门槛由目标侧 combat/perform-incoming 的死亡检查兜底。
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

  @perform_id "liumai-shenjian/six"
  @move_name "「六脉剑气」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "liumai-shenjian")
    ap = Stats.skill(stats, "finger")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_prepared(character),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_weapon(combat),
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

  # LPC: if (userp(me) && ! me->query("can_perform/liumai-shenjian/six"))
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

  # LPC: if (me->query_skill_prepared("finger") != "liumai-shenjian")
  defp check_prepared(character) do
    stats = character.meta.stats
    prepared = Stats.prepared_perform(stats, "finger")

    if prepared == nil or hd(String.split(prepared, "/")) != "liumai-shenjian" do
      {:error, "你没有准备使用六脉神剑，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: liumai-shenjian < 220 / force < 400
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "liumai-shenjian") < 220 ->
        {:error, "你的六脉神剑修为有限，无法使用#{@move_name}！\n"}

      Stats.skill(stats, "force") < 400 ->
        {:error, "你的内功火候不够，难以施展#{@move_name}！\n"}

      true ->
        :ok
    end
  end

  # LPC: max_neili < 7000 / neili < 500
  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 7000 ->
        {:error, "你的内力修为没有达到那个境界，无法运转内力形成#{@move_name}！\n"}

      vitals.neili < 500 ->
        {:error, "你的真气不够，现在无法施展#{@move_name}！\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_temp("weapon"))
  defp check_weapon(combat) do
    if Combat.weapon(combat) != nil do
      {:error, "你必须是空手才能施展#{@move_name}！\n"}
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
    # LPC: msg = HIW "$N" HIW "摊开双手，手指连弹，霎时间空气炙热，几"
    #               "欲沸腾，六道剑气分自六穴，一起冲向$n" HIW "！\n" NOR;
    # （相邻字面量合并为单段）
    # LPC: me->add("neili", -400); me->start_busy(1 + random(5));（均无条件）
    rng = &:rand.uniform/1

    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 400}
    combat = Combat.start_busy(character.meta.combat, 1 + Engine.rand(rng, 5))
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    conn =
      Broadcast.publish(
        conn,
        "$N摊开双手，手指连弹，霎时间空气炙热，几欲沸腾，六道剑气分自六穴，一起冲向$n！\n",
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
    ap = max(Map.get(data, :ap, 0), 1)
    skill = max(Map.get(data, :skill, 0), 1)
    stats = character.meta.stats
    dp = Stats.skill(stats, "force")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (ap / 2 + random(ap) > dp) 命中 → 退意文案 + delta = -skill/5
    {conn, delta} =
      if div(ap, 2) + Engine.rand(rng, ap) > dp do
        conn =
          conn
          |> Broadcast.publish(retreat_message(), bindings)

        {conn, -div(skill, 5)}
      else
        {conn, 0}
      end

    # LPC: target->add_temp("apply/parry", delta); target->add_temp("apply/dodge", delta);
    combat = Combat.apply_temp(character.meta.combat, %{parry: delta, dodge: delta})

    # LPC: for (i = 0; i < 6; i++) { if (! me->is_fighting(target)) break;
    #        if (random(2) == 1 && ! target->is_busy()) target->start_busy(1);
    #        me->set_temp("liumai-shenjian/hit_msg", i);
    #        COMBAT_D->do_attack(me, target, 0, i * 3); }
    # 折算：每击 skill/15 基础伤害 + 命中判定（skill/2 + random(skill) vs dodge）。
    # `do_attack` 第 4 参数是 attack_type（0=TYPE_REGULAR…），仅在未命中且对方
    # `guarding` 时触发反击；`guarding` 未建模，故 `i * 3` 无效果。
    # `hit_msg` 临时量全库仅在此 set/delete，无读取处，属无效管线。
    per_hit = max(div(skill, 15), 1)
    dodge = Stats.skill(stats, "dodge")

    {combat, damage, _hits} =
      Enum.reduce(1..6, {combat, 0, 0}, fn _i, {combat_acc, damage_acc, hit_acc} ->
        if not Combat.fighting?(combat_acc) do
          {combat_acc, damage_acc, hit_acc}
        else
          # LPC: if (random(2) == 1 && ! target->is_busy()) target->start_busy(1);
          combat_acc =
            if Engine.rand(rng, 2) == 1 and combat_acc.busy == 0 do
              Combat.start_busy(combat_acc, 1)
            else
              combat_acc
            end

          # LPC: COMBAT_D->do_attack(me, target, 0, i * 3);（i * 3 的加成折入 per_hit）
          if div(skill, 2) + Engine.rand(rng, skill) > dodge do
            {combat_acc, damage_acc + per_hit + Engine.rand(rng, per_hit), hit_acc + 1}
          else
            {combat_acc, damage_acc, hit_acc}
          end
        end
      end)

    # LPC: target->add_temp("apply/parry", -delta); target->add_temp("apply/dodge", -delta);
    combat = Combat.apply_temp(combat, %{parry: -delta, dodge: -delta})

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    conn
    |> put_character(character)
  end

  # LPC: HIR "$n" HIR "见此剑气纵横，微一愣神，不禁心萌退意。\n" NOR
  # （相邻字面量合并为单段）
  defp retreat_message do
    "$n见此剑气纵横，微一愣神，不禁心萌退意。\n"
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # #define SIX "「" HIW "六脉剑气" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # 
  # int perform(object me, object target)
  # {
  #         // mapping prepare;
  #         string msg;
  #         int skill;
  #         int delta;
  #         int i;
  #         int ap, dp;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/liumai-shenjian/six"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(SIX "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_skill_prepared("finger") != "liumai-shenjian")
  #                 return notify_fail("你没有准备使用六脉神剑，无法施展" SIX "。\n");
  # 
  #         skill = me->query_skill("liumai-shenjian", 1);
  # 
  #         if (skill < 220)
  #                 return notify_fail("你的六脉神剑修为有限，无法使用" SIX "！\n");
  # 
  #         if (me->query_skill("force") < 400)
  #                 return notify_fail("你的内功火候不够，难以施展" SIX "！\n");
  # 
  #         if (me->query("max_neili") < 7000)
  #                 return notify_fail("你的内力修为没有达到那个境界，无法运转内"
  #                                    "力形成" SIX "！\n");
  # 
  #         if (me->query("neili") < 500)
  #                 return notify_fail("你的真气不够，现在无法施展" SIX "！\n");
  # 
  #         if (me->query_temp("weapon"))
  #                 return notify_fail("你必须是空手才能施展" SIX "！\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "摊开双手，手指连弹，霎时间空气炙热，几"
  #               "欲沸腾，六道剑气分自六穴，一起冲向$n" HIW "！\n" NOR;
  # 
  #         ap = me->query_skill("finger");
  #         dp = target->query_skill("force");
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += HIR "$n" HIR "见此剑气纵横，微一愣神，不禁心萌退意。\n" NOR;
  #                 delta = -skill / 5;
  #         } else
  #                 delta = 0;
  # 
  #         message_combatd(msg, me, target);
  # 
  #         me->add("neili", -400);
  #         target->add_temp("apply/parry", delta);
  #         target->add_temp("apply/dodge", delta);
  #         for (i = 0; i < 6; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  # 
  #                 if (random(2) == 1 && ! target->is_busy())
  #                         target->start_busy(1);
  # 
  #                 me->set_temp("liumai-shenjian/hit_msg", i);
  # 
  #                 COMBAT_D->do_attack(me, target, 0, i * 3);
  #         }
  #         target->add_temp("apply/parry", -delta);
  #         target->add_temp("apply/dodge", -delta);
  #         me->delete_temp("liumai-shenjian/hit_msg");
  #         me->start_busy(1 + random(5));
  # 
  #         return 1;
  # }
end
