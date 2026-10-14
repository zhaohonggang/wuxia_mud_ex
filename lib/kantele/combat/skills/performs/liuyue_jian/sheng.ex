defmodule Kantele.Combat.Skills.Performs.LiuyueJian.Sheng do
  @moduledoc """
  perform「天升剑诀」（source liuyue-jian/sheng.c，inherit F_SSERVER）

  手工补齐：门槛文案按字符串宏 `SHENG`（→「天升剑诀」）展开；`do_attack` 六连击
  （无独立命中文案，由战斗管线出字）折算为逐击命中判定与伤害累加。
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

  @perform_id "liuyue-jian/sheng"

  # LPC: #define SHENG "「" HIW "天升剑诀" NOR "」"
  @move_name "「天升剑诀」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "liuyue-jian")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(stats),
         :ok <- check_resources(character),
         :ok <- check_mapped(stats),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
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
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #       (string)weapon->query("skill_type") != "sword")
  # （两个条件共用一个 notify_fail 文案）
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if is_map(weapon) and Map.get(weapon, :skill_type) == "sword" do
      :ok
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill("force") < 200)
  #      if (me->query_skill("liuyue-jian", 1) < 140)
  defp check_levels(stats) do
    cond do
      Stats.skill(stats, "force") < 200 ->
        {:error, "你的内功的修为不够，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "liuyue-jian") < 140 ->
        {:error, "你的流月剑舞修为不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query("neili") < 300)
  defp check_resources(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "liuyue-jian")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") != "liuyue-jian" do
      {:error, "你没有激发流月剑舞，难以施展#{@move_name}。\n"}
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

  # LPC: me->add("neili", -100); me->start_busy(1 + random(6));（均无条件）
  defp apply_effect(conn, character, target) do
    rng = &:rand.uniform/1
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 100}
    combat = Combat.start_busy(character.meta.combat, 1 + Engine.rand(rng, 6))
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    # LPC: msg = HIW "$N" HIW "手腕一阵疾抖，剑身微颤，剑作龙吟。刹那间剑芒陡涨，"
    #               "如天河倒泻一般洒向$n" HIW "。\n" NOR;（合并为单段）
    conn =
      Broadcast.publish(
        conn,
        "$N手腕一阵疾抖，剑身微颤，剑作龙吟。刹那间剑芒陡涨，如天河倒泻一般洒向$n。\n",
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
    stats = character.meta.stats
    dodge = Stats.skill(stats, "dodge")
    per_hit = max(div(level, 15), 1)
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: for (i = 0; i < 6; i++) { if (! me->is_fighting(target)) break;
    #        COMBAT_D->do_attack(me, target, weapon, 0); }
    # 折算：每击 level/15 基础伤害 + 命中判定（level/2 + random(level) vs 目标 dodge）。
    {damage, hits} =
      Enum.reduce(1..6, {0, 0}, fn _, {damage_acc, hit_acc} ->
        if not Combat.fighting?(character.meta.combat) do
          {damage_acc, hit_acc}
        else
          if div(level, 2) + Engine.rand(rng, level) > dodge do
            {damage_acc + per_hit + Engine.rand(rng, per_hit), hit_acc + 1}
          else
            {damage_acc, hit_acc}
          end
        end
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC `do_attack` 由战斗管线出字，原文无独立命中/失手文案；
    # 此处仅在命中时给一句通用提示（信息性 EXTRA，同 bagua_dao/tian、feifeng_bian/xi）。
    if hits > 0 do
      conn
      |> Broadcast.publish("$n被$N击中！", bindings)
      |> put_character(character)
    else
      put_character(conn, character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define SHENG "「" HIW "天升剑诀" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int i;
  # 
  #         if (userp(me) && ! me->query("can_perform/liuyue-jian/sheng"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(SHENG "只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #               (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" SHENG "。\n");
  # 
  #         if (me->query_skill("force") < 200)
  #                 return notify_fail("你的内功的修为不够，难以施展" SHENG "。\n");
  # 
  #         if (me->query_skill("liuyue-jian", 1) < 140)
  #                 return notify_fail("你的流月剑舞修为不够，难以施展" SHENG "。\n");
  # 
  #         if (me->query("neili") < 300)
  #                 return notify_fail("你的真气不够，难以施展" SHENG "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "liuyue-jian")
  #                 return notify_fail("你没有激发流月剑舞，难以施展" SHENG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "手腕一阵疾抖，剑身微颤，剑作龙吟。刹那间剑芒陡涨，"
  #               "如天河倒泻一般洒向$n"
  #               HIW "。\n" NOR;
  # 
  #         message_combatd(msg, me, target);
  #         me->add("neili", -100);
  # 
  #         for (i = 0; i < 6; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  # 
  #         me->start_busy(1 + random(6));
  # 
  #         return 1;
  # }
end
