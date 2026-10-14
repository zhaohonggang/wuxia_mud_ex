defmodule Kantele.Combat.Skills.Performs.LiuyangZhang.Huan do
  @moduledoc """
  perform「寰阳式」（source liuyang-zhang/huan.c，inherit F_SSERVER）

  手工补齐：门槛文案按字符串宏 `HUAN`（→「寰阳式」）展开；命中判定、伤害与
  攻击方内力消耗按原始 LPC 语义建模。
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

  @perform_id "liuyang-zhang/huan"

  # LPC: #define HUAN "「" HIR "寰阳式" NOR "」"
  # （字符串宏展开后与相邻字面量合并成单段，用插值复现）
  @move_name "「寰阳式」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(stats),
         :ok <- check_mapped(stats),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      ap = Stats.skill(stats, "force")
      strike = Stats.skill(stats, "strike")

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          ap: ap,
          strike: strike,
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

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  defp check_weapon(combat) do
    if Combat.weapon(combat) != nil do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill("force") < 200)
  #      if (me->query_skill("liuyang-zhang", 1) < 130)
  defp check_levels(stats) do
    cond do
      Stats.skill(stats, "force") < 200 ->
        {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "liuyang-zhang") < 130 ->
        {:error, "你的天山六阳掌不够娴熟，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "liuyang-zhang")
  #      if (me->query_skill_prepared("strike") != "liuyang-zhang")
  defp check_mapped(stats) do
    cond do
      Stats.mapped(stats, "strike") != "liuyang-zhang" ->
        {:error, "你没有激发天山六阳掌，难以施展#{@move_name}。\n"}

      prepared_is_not?(stats, "strike", "liuyang-zhang") ->
        {:error, "你没有准备使用天山六阳掌，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC query_skill_prepared 返回绝招 ID（如 "liuyang-zhang/huan"），需按技能前缀比对。
  defp prepared_is_not?(stats, skill, mapped) do
    case Stats.prepared_perform(stats, skill) do
      nil -> true
      prepared -> hd(String.split(prepared, "/")) != mapped
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

  # LPC: if (! living(target))
  # （目标侧 perform_incoming 另有死亡短路；此处保留门槛文案）
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  # LPC: me->add("neili", -50); me->start_busy(3);（两者均无条件，命中与否都执行）
  defp apply_effect(conn, character, target) do
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 50}
    combat = Combat.start_busy(character.meta.combat, 3)
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    # LPC: msg = HIR "$N" HIR "双掌一振，施出天山六阳掌「寰阳式」，幻出"
    #               "满天掌影，团团罩住$n" HIR "。\n" NOR;
    # （相邻字面量合并为单段）
    conn =
      Broadcast.publish(
        conn,
        "$N双掌一振，施出天山六阳掌「寰阳式」，幻出满天掌影，团团罩住$n。\n",
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
    strike = max(Map.get(data, :strike, 0), 0)
    stats = character.meta.stats
    # LPC: dp = target->query_skill("force");
    dp = Stats.skill(stats, "force")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (ap / 2 + random(ap) > dp)
    hit? = div(ap, 2) + Engine.rand(rng, ap) > dp

    {vitals, msg} =
      if hit? do
        # LPC: damage = me->query_skill("strike") + ap - dp;
        #      damage += random(damage * 2 / 5);
        base = strike + ap - dp
        damage = base + Engine.rand(rng, div(base * 2, 5))
        damage = max(damage, 0)

        vitals =
          character.meta.vitals
          |> Vitals.damage(:qi, damage)
          |> Vitals.wound(:qi, div(damage * 40, 100))

        # LPC: me->add("neili", -100);（仅命中分支，跨进程回执）
        _ = Performs.feedback(attacker, 100, 0)

        # LPC: HIR "$n" HIR "见躲闪不得，只能硬挡下一" "招，顿时被$P"
        #      HIR "震得连退数步，吐血" "不止！\n" NOR;（合并为单段）
        {vitals, "$n见躲闪不得，只能硬挡下一招，顿时被$P震得连退数步，吐血不止！\n"}
      else
        # LPC: HIC "可是$p" HIC "强运内力，硬生生的挡住$P" HIC "这一掌，没有受到任何伤害。\n" NOR;
        # （合并为单段）
        {character.meta.vitals, "可是$p强运内力，硬生生的挡住$P这一掌，没有受到任何伤害。\n"}
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn
    |> Broadcast.publish(msg, bindings)
    |> put_character(character)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define HUAN "「" HIR "寰阳式" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  # //    object weapon;
  #     int damage;
  #     string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/liuyang-zhang/huan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  # 
  #     if (! target || ! me->is_fighting(target))
  #                 return notify_fail(HUAN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(HUAN "只能空手施展。\n");
  # 
  #         if (me->query_skill("force") < 200)
  #                 return notify_fail("你的内功火候不够，难以施展" HUAN "。\n");
  # 
  #         if ((int)me->query_skill("liuyang-zhang", 1) < 130)
  #                 return notify_fail("你的天山六阳掌不够娴熟，难以施展" HUAN "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "liuyang-zhang")
  #                 return notify_fail("你没有激发天山六阳掌，难以施展" HUAN "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "liuyang-zhang")
  #                 return notify_fail("你没有准备使用天山六阳掌，难以施展" HUAN "。\n");
  # 
  #         if (me->query("neili") < 300)
  #                 return notify_fail("你的真气不够，难以施展" HUAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIR "$N" HIR "双掌一振，施出天山六阳掌「寰阳式」，幻出"
  #               "满天掌影，团团罩住$n" HIR "。\n" NOR;
  # 
  #     me->add("neili", -50);
  #         ap = me->query_skill("force");
  #         dp = target->query_skill("force");
  #         if (ap / 2 + random(ap) > dp)
  #     {
  #         damage = me->query_skill("strike") + ap - dp;
  #                 damage += random(damage * 2 / 5);
  #         me->add("neili", -100);
  # 
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 40,
  #                                            HIR "$n" HIR "见躲闪不得，只能硬挡下一"
  #                                            "招，顿时被$P" HIR "震得连退数步，吐血"
  #                                            "不止！\n" NOR);
  #         me->start_busy(3);
  #     } else
  #     {
  #         msg += HIC "可是$p" HIC "强运内力，硬生生的挡住$P"
  #                        HIC "这一掌，没有受到任何伤害。\n"NOR;
  #         me->start_busy(3);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
