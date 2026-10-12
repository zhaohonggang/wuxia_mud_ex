defmodule Kantele.Combat.Skills.Performs.DashouYin.Yin do
  @moduledoc """
  perform「金刚印」（source dashou-yin/yin.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 空手 → 大手印>=100 → 真气>=150 →
  激发 hand 为大手印 → 准备大手印 → 目标存活。
  命中判定 `ap/2 + random(ap)`（`ap = hand + lamaism`）对目标 `parry`（`<1` 取 1）：
  命中则 `damage = ap/2 + random(ap)`、按 40% 计 qi 伤，攻击方扣 100 真气并忙乱 2；
  未命中扣 40 真气并忙乱 3。

  差异（TODO(migrate)）：
  - `do_damage(..., UNARMED_ATTACK, damage, 40, ...)` 折算为
    `Vitals.damage(:qi, damage)` / `Vitals.wound(:qi, div(damage * 40, 100))`；
  - `.c` 的 `me->query_temp("secondary_weapon")` 副兵器检查未单独建模，统一按
    `Combat.weapon/1` 判空手（同 chilian-shenzhang/lian）；
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

  @perform_id "dashou-yin/yin"
  @move_name "「金刚印」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "dashou-yin")
    # LPC: ap = me->query_skill("hand") + me->query_skill("lamaism", 1);
    ap = Stats.skill(stats, "hand") + Stats.skill(stats, "lamaism")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(character),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_mapped(character),
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

  # LPC: if (! me->is_fighting(target))
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
    if Stats.skill(character.meta.stats, "dashou-yin") < 100 do
      {:error, "你的大手印修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_resources(character) do
    if character.meta.vitals.neili < 150 do
      {:error, "你的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("hand") != "dashou-yin")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "hand") == "dashou-yin" do
      :ok
    else
      {:error, "你没有激发大手印，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill_prepared("hand") != "dashou-yin")
  defp check_prepared(character) do
    case Stats.prepared_perform(character.meta.stats, "hand") do
      nil ->
        {:error, "你没有准备大手印，难以施展#{@move_name}。\n"}

      value ->
        if String.split(value, "/") |> hd() == "dashou-yin" do
          :ok
        else
          {:error, "你没有准备大手印，难以施展#{@move_name}。\n"}
        end
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
    # LPC: msg = HIY "$N" HIY "面容庄重，单手携着劲风朝$n" HIY "猛然拍出，正"
    #            "是密宗绝学「金刚印」。\n" NOR;
    #      message_combatd(msg, me, target);
    # 命中/伤害在目标侧结算（dp 需目标 parry）。
    conn
    |> Broadcast.publish(
      "$N面容庄重，单手携着劲风朝$n猛然拍出，正是密宗绝学「金刚印」。\n",
      n1: character.name,
      n2: target.name
    )
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

    # LPC: dp = target->query_skill("parry"); if (dp < 1) dp = 1;
    dp = max(Stats.skill(stats, "parry"), 1)

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = ap / 2 + random(ap);
      #      do_damage(..., UNARMED_ATTACK, damage, 40, ...) → qi 伤 + 40% 创伤
      damage = div(ap, 2) + Engine.rand(rng, ap)

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 40, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: me->add("neili", -100); me->start_busy(2);
      Performs.feedback(attacker, 100, 2)

      # LPC: msg += HIR "结果$p" HIR "招架不及，被$P" HIR "这一下打得七窍生烟，吐血连连。\n" NOR;
      conn
      |> Broadcast.publish(
        Messages.interpolate("结果$p招架不及，被$P这一下打得七窍生烟，吐血连连。\n", bindings)
      )
      |> put_character(character)
    else
      # LPC: me->add("neili", -40); me->start_busy(3);
      Performs.feedback(attacker, 40, 3)

      # LPC: msg += CYN "可是$p" CYN "不慌不忙，巧妙的架开了$P" CYN "的金刚印。\n" NOR;
      conn
      |> Broadcast.publish(
        Messages.interpolate("可是$p不慌不忙，巧妙的架开了$P的金刚印。\n", bindings)
      )
      |> put_character(character)
    end
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define YIN "「" HIY "金刚印" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int skill, ap, dp, damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/dashou-yin/yin"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! me->is_fighting(target))
  #                 return notify_fail(YIN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(YIN "只能空手施展。\n");
  # 
  #         skill = me->query_skill("dashou-yin", 1);
  # 
  #         if (skill < 100)
  #                 return notify_fail("你的大手印修为不够，难以施展" YIN "。\n");
  # 
  #         if (me->query("neili") < 150)
  #                 return notify_fail("你的真气不够，难以施展" YIN "。\n");
  # 
  #         if (me->query_skill_mapped("hand") != "dashou-yin")
  #                 return notify_fail("你没有激发大手印，难以施展" YIN "。\n");
  # 
  #         if (me->query_skill_prepared("hand") != "dashou-yin")
  #                 return notify_fail("你没有准备大手印，难以施展" YIN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "面容庄重，单手携着劲风朝$n" HIY "猛然拍出，正"
  #               "是密宗绝学「金刚印」。\n" NOR;
  # 
  #         ap = me->query_skill("hand") + me->query_skill("lamaism", 1);
  #         dp = target->query_skill("parry");
  #         if (dp < 1) dp = 1;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 me->add("neili", -100);
  #                 me->start_busy(2);
  #                 damage = ap / 2 + random(ap);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 40,
  #                                            HIR "结果$p" HIR "招架不及，被$P" HIR
  #                                            "这一下打得七窍生烟，吐血连连。\n" NOR);
  #         } else
  #         {
  #                 me->add("neili",-40);
  #                 msg += CYN "可是$p" CYN "不慌不忙，巧妙的架开了$P"
  #                        CYN "的金刚印。\n" NOR;
  #                 me->start_busy(3);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
