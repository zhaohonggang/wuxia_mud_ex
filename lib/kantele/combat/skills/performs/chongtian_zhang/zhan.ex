defmodule Kantele.Combat.Skills.Performs.ChongtianZhang.Zhan do
  @moduledoc """
  perform「翅展九州」（source chongtian-zhang/zhan.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 未持兵器 → 内功>=150 →
  白鹤冲天掌>=120 → 激发 strike 为白鹤冲天掌 → 准备白鹤冲天掌 → 真气>=300 →
  目标存活。攻击方无条件扣 50 真气；命中判定 `strike/2 + random(strike)` vs
  目标 `force`：命中则伤害 `strike*3/5 + random(strike*3/5/3)`、按 30% 计伤，
  攻击方再扣 100 真气并忙乱 3；未命中忙乱 4。

  差异（TODO(migrate)）：
  - LPC 的 `COMBAT_D->do_damage`（含 armor 减免）折算为 `Vitals.damage(:qi, ...)`
    + `Vitals.wound(:qi, damage*30/100)`；
  - `me->query_temp("secondary_weapon")` 副兵器检查未实现；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧 `combat/perform-incoming`
    的死亡检查兜底。
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
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "chongtian-zhang/zhan"
  @move_name "「翅展九州」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "chongtian-zhang")
    # LPC: ap = me->query_skill("strike")
    ap = Stats.skill(stats, "strike")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(character),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_prepared(character),
         :ok <- check_resources(character),
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

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  defp check_weapon(character) do
    if Combat.weapon(character.meta.combat) != nil do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "chongtian-zhang") < 120 ->
        {:error, "你的白鹤冲天掌不够娴熟，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "chongtian-zhang")
  defp check_mapped(character) do
    stats = character.meta.stats

    if Stats.mapped(stats, "strike") == "chongtian-zhang" do
      :ok
    else
      {:error, "你没有激发白鹤冲天掌，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "chongtian-zhang")
  defp check_prepared(character) do
    stats = character.meta.stats

    case Stats.prepared_perform(stats, "strike") do
      nil ->
        {:error, "你没有准备白鹤冲天掌，难以施展#{@move_name}。\n"}

      value ->
        if String.split(value, "/") |> hd() == "chongtian-zhang" do
          :ok
        else
          {:error, "你没有准备白鹤冲天掌，难以施展#{@move_name}。\n"}
        end
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    if vitals.neili < 300 do
      {:error, "你的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活，
  # 由目标侧 combat/perform-incoming 的死亡检查兜底。
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
    # LPC: me->add("neili", -50);  msg = HIW "$N" HIW "双臂舒张，……\n" NOR;
    #      message_combatd(msg, me, target);
    # 命中/伤害/busy 在目标侧结算（dp 需目标 force）。
    vitals = character.meta.vitals
    vitals = %{vitals | neili: max(vitals.neili - 50, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn =
      Broadcast.publish(
        conn,
        "$N双臂舒张，掌缘微微颤动，身形一展，已移至$n跟前，双掌交叉奋力劈下，正是\n白鹤冲天掌「翅展九州」绝技，空气中顿时爆响出一阵尖锐的破空声。\n",
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
    stats = character.meta.stats
    # LPC: dp = target->query_skill("force")
    dp = Stats.skill(stats, "force")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (ap / 2 + random(ap) > dp)
    hit = div(ap, 2) + Engine.rand(rng, ap) > dp

    vitals =
      if hit do
        # LPC: damage = me->query_skill("strike") * 3 / 5; damage += random(damage / 3);
        damage = div(ap * 3, 5)
        damage = damage + Engine.rand(rng, div(damage, 3))

        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 30, 100))
      else
        character.meta.vitals
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: 命中 me->add("neili", -100) + me->start_busy(3)；未命中 me->start_busy(4)
    if hit do
      Performs.feedback(attacker, 100, 3)
    else
      Performs.feedback(attacker, 0, 4)
    end

    msg =
      if hit,
        do: "$n躲闪不得，只能硬挡下双掌，顿时被$P双掌砍中双肩两侧，吐血不止！\n",
        else: "可是$p奋力招架，终于将$P这双掌架开，没有受到任何伤害。\n"

    conn
    |> Broadcast.publish(Messages.interpolate(msg, bindings))
    |> put_character(character)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHAN "「" HIW "翅展九州" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/chongtian-zhang/zhan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHAN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(ZHAN "只能空手施展。\n");
  # 
  #         if (me->query_skill("force") < 150)
  #                 return notify_fail("你的内功火候不够，难以施展" ZHAN "。\n");
  # 
  #         if ((int)me->query_skill("chongtian-zhang", 1) < 120)
  #                 return notify_fail("你的白鹤冲天掌不够娴熟，难以施展" ZHAN "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "chongtian-zhang")
  #                 return notify_fail("你没有激发白鹤冲天掌，难以施展" ZHAN "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "chongtian-zhang")
  #                 return notify_fail("你没有准备白鹤冲天掌，难以施展" ZHAN "。\n");
  # 
  #         if (me->query("neili") < 300)
  #                 return notify_fail("你的真气不够，难以施展" ZHAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "双臂舒张，掌缘微微颤动，身形一展，已移至$n"
  #               HIW "跟前，双掌交叉奋力劈下，正是\n白鹤冲天掌「翅展九州」"
  #               "绝技，空气中顿时爆响出一阵尖锐的破空声。\n" NOR;
  # 
  #         me->add("neili", -50);
  #         ap = me->query_skill("strike");
  #         dp = target->query_skill("force");
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = me->query_skill("strike") * 3 / 5;
  #                 damage += random(damage / 3);
  #                 me->add("neili", -100);
  # 
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
  #                                            HIR "$n" HIR "躲闪不得，只能硬挡下双掌"
  #                                            "，顿时被$P" HIR "双掌砍中双肩两侧，吐"
  #                                            "血不止！\n" NOR);
  #                 me->start_busy(3);
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "奋力招架，终于将$P"
  #                        CYN "这双掌架开，没有受到任何伤害。\n"NOR;
  #                 me->start_busy(4);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
