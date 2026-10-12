defmodule Kantele.Combat.Skills.Performs.DulongShenzhua.Ju do
  @moduledoc """
  perform「真龙聚」（source dulong-shenzhua/ju.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 空手 → 毒龙神爪功>=130 →
  激发 `claw` 为毒龙神爪功 → 准备毒龙神爪功 → 内功>=180 → 真气>=300 →
  目标存活。

  对抗：`ap = 爪法 + 内功`，目标 `dp = 目标招架 + 目标内功`。
  - `ap/2 + random(ap) > dp`：命中，`damage = ap + random(ap/2)`（qi 伤 + 65% 创伤），
    攻击方扣 220 真气、忙乱 3；
  - 否则：目标奋力招架化解，攻击方扣 100 真气、忙乱 4。

  差异（TODO(migrate)）：
  - `.c` 把起手与分支文案拼成一条 `message_sort`，本版同样在目标侧
    `resolve_incoming/4` 合并为一条广播（`dp` 需目标 parry/force）；
    攻击方的真气/忙乱经 `combat/perform-feedback` 回执补记；
  - `do_damage(..., UNARMED_ATTACK, damage, 65, ...)` 折算为
    `Vitals.damage(:qi, damage)` + `Vitals.wound(:qi, div(damage * 65, 100))`；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧死亡检查兜底。
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

  @perform_id "dulong-shenzhua/ju"
  @move_name "「真龙聚」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    level = Stats.skill(stats, "dulong-shenzhua")
    # LPC: ap = me->query_skill("claw") + me->query_skill("force");
    ap = Stats.skill(stats, "claw") + Stats.skill(stats, "force")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(character),
         :ok <- check_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_prepared(stats),
         :ok <- check_force(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: level,
          skill: level,
          ap: ap,
          rng: rng
        }
      })

      # 命中判定依赖目标 parry/force，故起手文案与结算整体在目标侧完成。
      assign(conn, :prompt, false)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/dulong-shenzhua/ju"))
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

  # LPC: if ((int)me->query_skill("dulong-shenzhua", 1) < 130)
  defp check_level(stats) do
    if Stats.skill(stats, "dulong-shenzhua") < 130 do
      {:error, "你毒龙神爪功不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("claw") != "dulong-shenzhua")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "claw") != "dulong-shenzhua" do
      {:error, "你没有激发毒龙神爪功，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("claw") != "dulong-shenzhua")
  defp check_prepared(stats) do
    case Stats.prepared_perform(stats, "claw") do
      nil ->
        {:error, "你没有准备毒龙神爪功，难以施展#{@move_name}。\n"}

      value ->
        if String.split(value, "/") |> hd() == "dulong-shenzhua" do
          :ok
        else
          {:error, "你没有准备毒龙神爪功，难以施展#{@move_name}。\n"}
        end
    end
  end

  # LPC: if (me->query_skill("force") < 180)
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 180 do
      {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 300)
  defp check_neili(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
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

  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活。
  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

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

    # LPC: dp = target->query_skill("parry") + target->query_skill("force");
    dp = Stats.skill(stats, "parry") + Stats.skill(stats, "force")

    # LPC: msg = HIC "\n$N" HIC "运转真气，将体内真气积聚于双爪间，猛然间双爪凌"
    #            "空而下，犹如神龙般划向$n" HIC "，这招正是玄冥谷绝学「" HIM "真"
    #            "龙聚" HIC "」。\n" NOR;
    opening =
      "\n$N运转真气，将体内真气积聚于双爪间，猛然间双爪凌空而下，犹如神龙般划向$n，这招正是玄冥谷绝学「真龙聚」。\n"

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = ap + random(ap / 2);
      damage = ap + Engine.rand(rng, div(ap, 2))

      # LPC: msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 65, HIR "但见$N" HIR
      #            "双爪划过，$n" HIR "已闪避不及，胸口被$N" HIR "抓出十条血痕。\n" NOR);
      #      me->start_busy(3); me->add("neili", -220);
      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 65, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      Performs.feedback(attacker, 220, 3)

      conn
      |> Broadcast.publish(
        opening <> "但见$N双爪划过，$n已闪避不及，胸口被$N抓出十条血痕。\n",
        bindings
      )
      |> put_character(character)
    else
      # LPC: msg += CYN "$n" CYN "奋力招架，竟将$N" CYN "这招化解。\n" NOR;
      #      me->start_busy(4); me->add("neili", -100);
      Performs.feedback(attacker, 100, 4)

      Broadcast.publish(conn, opening <> "$n奋力招架，竟将$N这招化解。\n", bindings)
    end
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define JU "「" HIM "真龙聚" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/dulong-shenzhua/ju"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(JU "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(JU "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("dulong-shenzhua", 1) < 130)
  #                 return notify_fail("你毒龙神爪功不够娴熟，难以施展" JU "。\n");
  # 
  #         if (me->query_skill_mapped("claw") != "dulong-shenzhua")
  #                 return notify_fail("你没有激发毒龙神爪功，难以施展" JU "。\n");
  # 
  #         if (me->query_skill_prepared("claw") != "dulong-shenzhua")
  #                 return notify_fail("你没有准备毒龙神爪功，难以施展" JU "。\n");
  # 
  #         if (me->query_skill("force") < 180)
  #                 return notify_fail("你的内功修为不够，难以施展" JU "。\n");
  # 
  #         if ((int)me->query("neili") < 300)
  #                 return notify_fail("你现在的真气不够，难以施展" JU "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         ap = me->query_skill("claw") + me->query_skill("force");
  #         dp = target->query_skill("parry") + target->query_skill("force");
  # 
  #         msg = HIC "\n$N" HIC "运转真气，将体内真气积聚于双爪间，猛然间双爪凌"
  #               "空而下，犹如神龙般划向$n" HIC "，这招正是玄冥谷绝学「" HIM "真"
  #               "龙聚" HIC "」。\n" NOR;
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 2);
  #                 
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 65,
  #                                            HIR "但见$N" HIR "双爪划过，$n" HIR "已闪避不及，胸口被$N" HIR
  #                                            "抓出十条血痕。\n" NOR);
  # 
  #                 me->start_busy(3);
  #                 me->add("neili", -220);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "奋力招架，竟将$N" CYN "这招化解。\n" NOR;
  # 
  #                 me->start_busy(4);
  #                 me->add("neili", -100);
  #         }
  #         message_sort(msg, me, target);
  #         return 1;
  # }
end
