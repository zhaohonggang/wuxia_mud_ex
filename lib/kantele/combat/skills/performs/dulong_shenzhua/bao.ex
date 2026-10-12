defmodule Kantele.Combat.Skills.Performs.DulongShenzhua.Bao do
  @moduledoc """
  perform「蛟龙抱」（source dulong-shenzhua/bao.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 空手 → 目标未忙乱 →
  毒龙神爪功>=80 → 激发 `claw` 为毒龙神爪功 → 准备毒龙神爪功 → 轻功>=150 →
  真气>=200 → 目标存活。

  对抗：`ap = 毒龙神爪功 + 轻功/2`，目标 `dp = 目标 dodge`。
  - `random(ap) > dp/2`：目标"心神惧裂"，目标忙乱 `ap/36 + 1`，
    攻击方扣 160 真气、忙乱 1；
  - 否则：目标"看破…大胆反攻"，攻击方扣 60 真气、忙乱 2。

  差异（TODO(migrate)）：
  - 命中判定依赖目标 `dodge`、且结果作用于目标忙乱，故起手广播与结算整体在
    目标侧 `resolve_incoming/4` 完成；攻击方的真气/忙乱经
    `combat/perform-feedback` 回执补记；
  - 目标忙乱门槛（`target->is_busy()`）在攻击方进程无目标忙乱快照
    （敌人引用仅 `%{id,pid,name,room_id}`），若引用带 `meta` 则照常判定，
    否则跳过（同 canhe-zhi/zhi）；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧死亡检查兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs

  @perform_id "dulong-shenzhua/bao"
  @move_name "「蛟龙抱」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    level = Stats.skill(stats, "dulong-shenzhua")
    # LPC: ap = me->query_skill("dulong-shenzhua", 1) + me->query_skill("dodge", 1) / 2;
    ap = level + div(Stats.skill(stats, "dodge"), 2)

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(character),
         :ok <- check_not_busy(target),
         :ok <- check_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_prepared(stats),
         :ok <- check_dodge(stats),
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

      # 命中判定依赖目标 dodge、结算作用于目标忙乱，故整体在目标侧完成。
      assign(conn, :prompt, false)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/dulong-shenzhua/bao"))
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

  # LPC: if (target->is_busy())
  #         return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 敌人引用无忙乱快照，若带 meta 则照常判定，否则跳过（同 canhe-zhi/zhi）。
  defp check_not_busy(target) do
    if busy?(target) do
      {:error, "#{Map.get(target, :name)}目前正自顾不暇，放胆攻击吧。\n"}
    else
      :ok
    end
  end

  defp busy?(%{meta: %{combat: %{busy: busy}}}), do: busy > 0
  defp busy?(_), do: false

  # LPC: if ((int)me->query_skill("dulong-shenzhua", 1) < 80)
  defp check_level(stats) do
    if Stats.skill(stats, "dulong-shenzhua") < 80 do
      {:error, "你毒龙神爪功不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("claw") != "dulong-shenzhua")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "claw") != "dulong-shenzhua" do
      {:error, "你没有毒龙神爪功，难以施展#{@move_name}。\n"}
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

  # LPC: if (me->query_skill("dodge") < 150)
  defp check_dodge(stats) do
    if Stats.skill(stats, "dodge") < 150 do
      {:error, "你的轻功修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 200)
  defp check_neili(character) do
    if character.meta.vitals.neili < 200 do
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

    # LPC: dp = target->query_skill("dodge");
    dp = Stats.skill(stats, "dodge")

    # LPC: msg = HIC "\n$N" HIC "尖啸一声，双爪齐出，施出绝招「" HIW "蛟龙抱" HIC "」，"
    #            "双爪犹如蛟龙般将$n" HIC "缠住。\n" NOR;  message_sort(msg, me, target);
    conn =
      Broadcast.publish(
        conn,
        "\n$N尖啸一声，双爪齐出，施出绝招「蛟龙抱」，双爪犹如蛟龙般将$n缠住。\n",
        bindings
      )

    # LPC: if (random(ap) > dp / 2)
    if Engine.rand(rng, ap) > div(dp, 2) do
      # LPC: msg = HIR "$n" HIR "心神惧裂，一时间竟无从应对。\n" NOR;
      #      target->start_busy(ap / 36 + 1); me->start_busy(1); me->add("neili", -160);
      combat = Combat.start_busy(character.meta.combat, div(ap, 36) + 1)
      character = %{character | meta: %{character.meta | combat: combat}}

      Performs.feedback(attacker, 160, 1)

      conn
      |> Broadcast.publish("$n心神惧裂，一时间竟无从应对。\n", bindings)
      |> put_character(character)
    else
      # LPC: msg = CYN "$n" CYN "看破$N" CYN "毫无攻击之意，于"
      #            "是大胆反攻，将$N" CYN "这招尽数化解。\n" NOR;
      #      me->start_busy(2); me->add("neili", -60);
      Performs.feedback(attacker, 60, 2)

      Broadcast.publish(
        conn,
        "$n看破$N毫无攻击之意，于是大胆反攻，将$N这招尽数化解。\n",
        bindings
      )
    end
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define BAO "「" HIW "蛟龙抱" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/dulong-shenzhua/bao"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(BAO "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(BAO "只能空手施展。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #         if ((int)me->query_skill("dulong-shenzhua", 1) < 80)
  #                 return notify_fail("你毒龙神爪功不够娴熟，难以施展" BAO "。\n");
  # 
  #         if (me->query_skill_mapped("claw") != "dulong-shenzhua")
  #                 return notify_fail("你没有毒龙神爪功，难以施展" BAO "。\n");
  # 
  #         if (me->query_skill_prepared("claw") != "dulong-shenzhua")
  #                 return notify_fail("你没有准备毒龙神爪功，难以施展" BAO "。\n");
  # 
  #         if (me->query_skill("dodge") < 150)
  #                 return notify_fail("你的轻功修为不够，难以施展" BAO "。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不够，难以施展" BAO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         ap = me->query_skill("dulong-shenzhua", 1) +
  #              me->query_skill("dodge", 1) / 2;
  # 
  #         dp = target->query_skill("dodge");
  # 
  #         msg = HIC "\n$N" HIC "尖啸一声，双爪齐出，施出绝招「" HIW "蛟龙抱" HIC "」，"
  #               "双爪犹如蛟龙般将$n" HIC "缠住。\n" NOR;
  # 
  #         message_sort(msg, me, target);
  # 
  #         if (random(ap) > dp / 2)
  #         {
  #         msg = HIR "$n" HIR "心神惧裂，一时间竟无从应对。\n" NOR;
  #                 target->start_busy(ap / 36 + 1);
  #                    me->start_busy(1);
  #                 me->add("neili", -160);
  #         } else
  #         {
  #                 msg = CYN "$n" CYN "看破$N" CYN "毫无攻击之意，于"
  #                       "是大胆反攻，将$N" CYN "这招尽数化解。\n" NOR;
  # 
  #                 me->start_busy(2);
  #                 me->add("neili", -60);
  #         }
  #         message_vision(msg, me, target);
  # 
  #         return 1;
  # }
end
