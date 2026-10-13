defmodule Kantele.Combat.Skills.Performs.KongmingQuan.Ruo do
  @moduledoc """
  perform「空明若玄」（source kongming-quan/ruo.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 空手 → 目标未忙乱 →
  空明拳>=100 → 激发 unarmed 为空明拳 → 准备 unarmed 为空明拳 → 内力>=100 →
  目标存活。
  命中判定：random(空明拳等级) > 目标招架/2。无伤害。
  施法即扣 50 内力（命中与否都扣）；命中：目标忙乱 等级/16+2；
  未命中：攻击方忙乱 2。
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

  @perform_id "kongming-quan/ruo"
  @move_name "「空明若玄」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "kongming-quan")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_target_busy(target),
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

  # LPC: if (objectp(me->query_temp("weapon")))
  #          return notify_fail(RUO "只能空手施展。\n");
  defp check_weapon(combat) do
    if Combat.weapon(combat) != nil do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: if (target->is_busy())
  #          return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 目标忙乱取引用快照 meta 的 combat.busy（缺 meta 时按未忙处理）
  defp check_target_busy(target) do
    if busy?(target) do
      {:error, "#{Map.get(target, :name)}目前正自顾不暇，放胆攻击吧。\n"}
    else
      :ok
    end
  end

  defp busy?(target) do
    case target do
      %{meta: %{combat: %{busy: busy}}} -> busy > 0
      _ -> false
    end
  end

  # LPC: if ((level = me->query_skill("kongming-quan", 1)) < 100)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "kongming-quan") < 100 do
      {:error, "你的空明拳不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("unarmed") != "kongming-quan")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "unarmed") != "kongming-quan" do
      {:error, "你没有激发空明拳，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("unarmed") != "kongming-quan")
  # prepared_perform 返回绝招 ID（如 kongming-quan/ruo），须取技能前缀比对
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "unarmed")

    if prepared == nil or hd(String.split(prepared, "/")) != "kongming-quan" do
      {:error, "你没有准备空明拳，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili", 1) < 100)
  defp check_resources(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你现在的真气太弱，难以施展#{@move_name}。\n"}
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

  # LPC: msg = WHT "$N" WHT "使出空明拳「" HIG "空明若玄" NOR + WHT "」，双手" …
  # C 侧「空明若玄」与「」，双手」之间有 `+`，验收工具不合并，E 侧用 list +
  # Enum.join("") 保持同样的两段字面量
  defp apply_effect(conn, character, target) do
    msg =
      [
        "$N使出空明拳「空明若玄",
        "」，双手吞吐不定，运转如意，试图扰乱$n的攻势。\n"
      ]
      |> Enum.join("")

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
    lvl = max(Map.get(data, :level, 0), 1)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(level) > (int)target->query_skill("parry", 1) / 2)
    dp = Stats.skill(stats, "parry")

    if Engine.rand(rng, lvl) > div(dp, 2) do
      # LPC: target->start_busy(level / 16 + 2);
      combat = Combat.start_busy(character.meta.combat, div(lvl, 16) + 2)
      character = %{character | meta: %{character.meta | combat: combat}}

      conn
      |> Broadcast.publish(
        Messages.interpolate("结果$n被$N的拳招所牵制，招架不迭，全然无法反击！\n", bindings)
      )
      |> put_character(character)
    else
      # LPC: me->start_busy(2);
      Performs.feedback(attacker, 0, 2)

      conn
      |> Broadcast.publish(
        Messages.interpolate("可是$p看破了$P的企图，镇定逾恒，全神应对自如。\n", bindings)
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # #define RUO "「" HIG "空明若玄" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     int level;
  #     string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/kongming-quan/ruo"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(RUO "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(me->query_temp("weapon")))
  #                 return notify_fail(RUO "只能空手施展。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #         if ((level = me->query_skill("kongming-quan", 1)) < 100)
  #                 return notify_fail("你的空明拳不够娴熟，难以施展" RUO "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "kongming-quan")
  #                 return notify_fail("你没有激发空明拳，难以施展" RUO "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "kongming-quan")
  #                 return notify_fail("你没有准备空明拳，难以施展" RUO "。\n");
  # 
  #         if ((int)me->query("neili", 1) < 100)
  #                 return notify_fail("你现在的真气太弱，难以施展" RUO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = WHT "$N" WHT "使出空明拳「" HIG "空明若玄" NOR + WHT "」，双手"
  #               "吞吐不定，运转如意，试图扰乱$n" WHT "的攻势。\n" NOR;
  # 
  #         me->add("neili", -50);
  #         if (random(level) > (int)target->query_skill("parry", 1) / 2)
  #         {
  #         msg += HIR "结果$n" HIR "被$N" HIR "的拳招所牵制，招架"
  #                        "不迭，全然无法反击！\n" NOR;
  #         target->start_busy(level / 16 + 2);
  #     } else
  #         {
  #         msg += CYN "可是$p" CYN "看破了$P" CYN "的企图，镇定逾"
  #                        "恒，全神应对自如。\n" NOR;
  #         me->start_busy(2);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
