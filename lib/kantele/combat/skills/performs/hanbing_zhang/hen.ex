defmodule Kantele.Combat.Skills.Performs.HanbingZhang.Hen do
  @moduledoc """
  perform「踏雪无痕」（source hanbing-zhang/hen.c，inherit F_SSERVER）

  门槛（按 `.c` 顺序）：已学此招 → 目标在战斗中 → 空手（主/副兵器皆无）→
  目标未忙乱 → 寒冰掌>=100 → 准备寒冰掌 → 轻功>=150 → 真气>=400 → 目标存活。
  起手广播后按 `random(ap) > 目标 dodge/2`
  （`ap = 寒冰掌 + 轻功/2`）判定：命中则目标忙乱 `ap/40 + 2`、
  攻击方忙乱 1 扣 100 真气；失手则攻击方忙乱 2、扣 30 真气。

  差异（TODO(migrate)）：
  - `.c` 的 `target->is_busy()` 门槛读的是目标忙乱；敌人列表只存引用快照
    （%{id,pid,name,room_id}）时无 busy 可查，此处保守恒判未忙乱（文案照留）；
  - `.c` 的分支费用/忙乱依赖目标属性，故由目标侧 `Performs.feedback/3` 回执；
  - `.c` 的 `message_sort` / `message_vision` 均折算为房间广播；
  - `.c` 未列「是否已学此招」门槛（`can_perform`），本引擎以框架层
    `perform_known?/2` 统一把关（多出的文案不影响对齐）；
  - `living(target)` 门槛在攻击方无 meta 可查，此处保守恒判存活，
    由目标侧 `combat/perform-incoming` 的死亡检查兜底。
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

  @perform_id "hanbing-zhang/hen"
  @move_name "「踏雪无痕」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "hanbing-zhang")
    # LPC: ap = me->query_skill("hanbing-zhang", 1) + me->query_skill("dodge", 1) / 2;
    ap = lvl + div(Stats.skill(stats, "dodge"), 2)

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_empty_handed(character),
         :ok <- check_target_busy(target),
         :ok <- check_level(stats),
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

  # 框架层「是否已学此招」门槛（.c 未列 `can_perform`，见 moduledoc 差异说明）。
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
  defp check_empty_handed(character) do
    combat = character.meta.combat

    if Combat.occupied?(combat, :weapon) or Combat.occupied?(combat, :secondary_weapon) do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: if (target->is_busy())
  #        return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 敌人引用无 busy 快照时保守恒判未忙乱（文案照留）。
  defp check_target_busy(target) do
    if busy?(target) do
      {:error, "#{Map.get(target, :name)}目前正自顾不暇，放胆攻击吧。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("hanbing-zhang", 1) < 100)
  defp check_level(stats) do
    if Stats.skill(stats, "hanbing-zhang") < 100 do
      {:error, "你寒冰掌不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "hanbing-zhang")
  defp check_prepared(stats) do
    prepared = Stats.prepared_perform(stats, "strike")

    if is_binary(prepared) and prepared |> String.split("/") |> hd() == "hanbing-zhang" do
      :ok
    else
      {:error, "你没有准备寒冰掌，难以施展#{@move_name}。\n"}
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

  # LPC: if ((int)me->query("neili") < 400)
  defp check_neili(character) do
    if character.meta.vitals.neili < 400 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target))
  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活，
  # 由目标侧 combat/perform-incoming 的死亡检查兜底。
  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp busy?(%{meta: %{combat: %{busy: busy}}}), do: busy > 0
  defp busy?(_), do: false

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIC "\n$N" HIC "怒喝一声，施出绝招「" HIG "踏雪无痕" HIC
    #            "」刹时间，寒意袭卷漫天，但见$N" HIC "双掌连续反转，不断"
    #            "拍向$n" HIC "，竟将$n" HIC "困在掌风之下。\n" NOR;
    #      message_sort(msg, me, target);
    Broadcast.publish(
      conn,
      "\n$N怒喝一声，施出绝招#{@move_name}刹时间，寒意袭卷漫天，但见$N双掌连续反转，不断拍向$n，竟将$n困在掌风之下。\n",
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

    # LPC: dp = target->query_skill("dodge");
    #      if (random(ap) > dp / 2) { msg = 命中文案; target->start_busy(ap / 40 + 2);
    #            me->start_busy(1); me->add("neili", -100); }
    #      else { msg = 化解文案; me->start_busy(2); me->add("neili", -30); }
    #      message_vision(msg, me, target);
    if Engine.rand(rng, ap) > div(Stats.skill(stats, "dodge"), 2) do
      combat = Combat.start_busy(character.meta.combat, div(ap, 40) + 2)
      character = %{character | meta: %{character.meta | combat: combat}}
      Performs.feedback(attacker, 100, 1)

      conn
      |> Broadcast.publish("$n心中一惊，一时间竟无从应对，竟被困在$N的掌风之中。\n", bindings)
      |> put_character(character)
    else
      Performs.feedback(attacker, 30, 2)

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
  # #define HENG "「" HIG "踏雪无痕" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/hanbing-zhang/hen"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(HENG "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(HENG "只能空手施展。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #         if ((int)me->query_skill("hanbing-zhang", 1) < 100)
  #                 return notify_fail("你寒冰掌不够娴熟，难以施展" HENG "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "hanbing-zhang")
  #                 return notify_fail("你没有准备寒冰掌，难以施展" HENG "。\n");
  # 
  #         if (me->query_skill("dodge") < 150)
  #                 return notify_fail("你的轻功修为不够，难以施展" HENG "。\n");
  # 
  #         if ((int)me->query("neili") < 400)
  #                 return notify_fail("你现在的真气不够，难以施展" HENG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         ap = me->query_skill("hanbing-zhang", 1) +
  #              me->query_skill("dodge", 1) / 2;
  # 
  #         dp = target->query_skill("dodge");
  # 
  #         msg = HIC "\n$N" HIC "怒喝一声，施出绝招「" HIG "踏雪无痕" HIC
  #               "」刹时间，寒意袭卷漫天，但见$N" HIC "双掌连续反转，不断"
  #               "拍向$n" HIC "，竟将$n" HIC "困在掌风之下。\n" NOR;
  #         message_sort(msg, me, target);
  # 
  #         if (random(ap) > dp / 2)
  #         {
  #         msg = HIR "$n" HIR "心中一惊，一时间竟无从应对，"
  #                       "竟被困在$N" HIR "的掌风之中。\n" NOR;
  # 
  #                 target->start_busy(ap / 40 + 2);
  #                    me->start_busy(1);
  #                 me->add("neili", -100);
  #         } else
  #         {
  #                 msg = CYN "$n" CYN "看破$N" CYN "毫无攻击之意，于"
  #                       "是大胆反攻，将$N" CYN "这招尽数化解。\n" NOR;
  # 
  #                 me->start_busy(2);
  #                 me->add("neili", -30);
  #         }
  #         message_vision(msg, me, target);
  # 
  #         return 1;
  # }
end
