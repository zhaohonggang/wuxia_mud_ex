defmodule Kantele.Combat.Skills.Performs.JiuyinShengong.Zhang do
  @moduledoc """
  perform「九阴神掌」（source jiuyin-shengong/perform/zhang.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 空手 →
  九阴神功>=260 → 基本掌法>=220 → 准备 unarmed 或 strike 为九阴神功 → 目标存活。
  ap = 九阴神功；dp = 目标招架。命中则 count = ap/5，否则 count = 9。
  起手扣 320 内力、忙乱 2+random(4)；临时 apply/attack 加成（count）折入连击伤害。
  连击 9 次 do_attack：每击命中判定，random(2)==1 且目标未忙乱则目标忙乱 1。
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
  alias Kantele.Character.Vitals

  @perform_id "jiuyin-shengong/zhang"
  @move_name "「九阴神掌」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jiuyin-shengong")
    ap = lvl

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_prepared(character),
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

  # LPC: if (me->query_temp("weapon")) return notify_fail("此招只能空手施展！\n");
  defp check_weapon(combat) do
    if Combat.weapon(combat) != nil do
      {:error, "此招只能空手施展！\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("jiuyin-shengong", 1) < 260)
  #          / if ((int)me->query_skill("strike", 1) < 220)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "jiuyin-shengong") < 260 ->
        {:error, "你的九阴神功不够深厚，不会使用#{@move_name}。\n"}

      Stats.skill(stats, "strike") < 220 ->
        {:error, "你的基本掌法修为不够，不会使用#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_prepared("unarmed") != "jiuyin-shengong"
  #          && me->query_skill_prepared("strike") != "jiuyin-shengong")
  # prepared_perform 返回绝招 ID（如 jiuyin-shengong/zhang），须取技能前缀比对
  defp check_prepared(character) do
    stats = character.meta.stats
    prepared_unarmed = Stats.prepared_perform(stats, "unarmed")
    prepared_strike = Stats.prepared_perform(stats, "strike")
    ok_unarmed = prepared_unarmed != nil and hd(String.split(prepared_unarmed, "/")) == "jiuyin-shengong"
    ok_strike = prepared_strike != nil and hd(String.split(prepared_strike, "/")) == "jiuyin-shengong"

    if not ok_unarmed and not ok_strike do
      {:error, "你没有准备使用九阴神功，无法施展#{@move_name}。\n"}
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

  # LPC: 起手文案（message_combatd 前置广播）；me->add("neili", -320);
  #      me->start_busy(2 + random(4));
  defp apply_effect(conn, character, target) do
    rng = &:rand.uniform/1
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 320}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    combat = Combat.start_busy(character.meta.combat, 2 + Engine.rand(rng, 4))
    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> Broadcast.publish(
      Messages.interpolate(
        "$N双掌一错，幻化出无数掌影，层层叠荡向$n逼去！\n",
        [n1: character.name, n2: target.name]
      )
    )
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

  defp do_resolve_incoming(conn, character, _attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    # LPC 源码此处写作 query_skill("jiujin-shengong")（笔误），按九阴神功计
    ap = max(Map.get(data, :ap, 0), 1)
    stats = character.meta.stats

    # LPC: dp = target->query_skill("parry", 1);
    #      if (ap / 2 + random(ap) > dp) count = ap / 5; else count = 9;
    dp = Stats.skill(stats, "parry")
    count = if div(ap, 2) + Engine.rand(rng, ap) > dp, do: div(ap, 5), else: 9

    # LPC: for (i = 0; i < 9; i++) { if (!me->is_fighting(target)) break;
    #          if (random(2) == 1 && !target->is_busy()) target->start_busy(1);
    #          COMBAT_D->do_attack(me, target, 0, ); }
    # 折算：每击命中判定（无显式 ap/dp，取 ap/2 + random(ap) 对闪避），
    #       me 的 apply/attack 临时加成（count）折入每击基础伤害。
    dodge = Stats.skill(stats, "dodge")
    per_hit = max(div(ap + count, 15), 1)

    {damage, combat} =
      Enum.reduce(1..9, {0, character.meta.combat}, fn _, {dmg_acc, combat} ->
        combat =
          if Engine.rand(rng, 2) == 1 and not Combat.busy?(combat) do
            Combat.start_busy(combat, 1)
          else
            combat
          end

        if div(ap, 2) + Engine.rand(rng, ap) > dodge do
          {dmg_acc + per_hit + Engine.rand(rng, per_hit), combat}
        else
          {dmg_acc, combat}
        end
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    conn
    |> put_character(character)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // zhang.c 九阴神掌
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define ZHANG "「" HIM "九阴神掌" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #     string msg;
  #     int ap, dp;
  #     int i, count;
  # 
  #     if (userp(me) && !me->query("can_perform/jiuyin-shengong/zhang"))
  #         return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (!target)
  #         target = offensive_target(me);
  # 
  #     if (!target || !me->is_fighting(target))
  #         return notify_fail(ZHANG "只能对战斗中的对手使用。\n");
  # 
  #     if (me->query_temp("weapon"))
  #         return notify_fail("此招只能空手施展！\n");
  # 
  #     if ((int)me->query_skill("jiuyin-shengong", 1) < 260)
  #         return notify_fail("你的九阴神功不够深厚，不会使用" ZHANG "。\n");
  # 
  #     if ((int)me->query_skill("strike", 1) < 220)
  #         return notify_fail("你的基本掌法修为不够，不会使用" ZHANG "。\n");
  # 
  #     if (me->query_skill_prepared("unarmed") != "jiuyin-shengong" && me->query_skill_prepared("strike") != "jiuyin-shengong")
  #         return notify_fail("你没有准备使用九阴神功，无法施展" ZHANG "。\n");
  # 
  #     if (!living(target))
  #         return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIY "$N" HIY "双掌一错，幻化出无数掌影，层层叠荡向$n" HIY "逼去！\n" NOR;
  #     message_combatd(msg, me, target); //修正pfm描述信息显示时间错误 by MK
  # 
  #     ap = me->query_skill("jiujin-shengong", 1);
  #     dp = target->query_skill("parry", 1);
  # 
  #     if (ap / 2 + random(ap) > dp)
  #         // count = ap / 7;
  #         count = ap / 5;
  # 
  #     else
  #         count = 9;
  # 
  #     me->add_temp("apply/attack", count);
  #     for (i = 0; i < 9; i++)
  #     {
  #         if (!me->is_fighting(target))
  #             break;
  # 
  #         if (random(2) == 1 && !target->is_busy())
  #             target->start_busy(1);
  # 
  #         COMBAT_D->do_attack(me, target, 0, );
  #     }
  #     me->start_busy(2 + random(4));
  #     me->add("neili", -320);
  # 
  #     me->add_temp("apply/attack", -count);
  # 
  #     return 1;
  # }
end
