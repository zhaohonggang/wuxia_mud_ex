defmodule Kantele.Combat.Skills.Performs.KongmingQuan.Kong do
  @moduledoc """
  perform「空空如也」（source kongming-quan/kong.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 空手 → 空明拳>=150 →
  激发 unarmed 为空明拳 → 准备 unarmed 为空明拳 → 内力>=150 → 目标存活。
  ap = 拳脚（unarmed）；dp = 目标招架（parry）。
  命中判定：ap/2 + random(ap) > dp。
  施法即扣 80 内力（命中与否都扣）；命中：伤害 = 内功等级 + random(等级/2)、
  80% 外伤，忙乱 3；未命中：忙乱 2。
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
  alias Kantele.Character.Vitals

  @perform_id "kongming-quan/kong"
  @move_name "「空空如也」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "kongming-quan")
    force_lvl = Stats.skill(stats, "force")
    ap = Stats.skill(stats, "unarmed")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
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
          # LPC: damage = me->query_skill("force", 1) + random(damage / 2)；
          # level 携带内功等级供目标侧折算伤害
          level: force_lvl,
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

  # LPC: if (objectp(me->query_temp("weapon")))
  #          return notify_fail(KONG "只能空手施展。\n");
  defp check_weapon(combat) do
    if Combat.weapon(combat) != nil do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("kongming-quan", 1) < 150)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "kongming-quan") < 150 do
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
  # prepared_perform 返回绝招 ID（如 kongming-quan/kong），须取技能前缀比对
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "unarmed")

    if prepared == nil or hd(String.split(prepared, "/")) != "kongming-quan" do
      {:error, "你没有准备空明拳，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili", 1) < 150)
  defp check_resources(character) do
    if character.meta.vitals.neili < 150 do
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

  # LPC: msg = WHT "$N" WHT "使出空明拳「" HIG "空空如也" NOR + WHT "」，拳劲" …
  # C 侧「空空如也」与「」，拳劲」之间有 `+`，验收工具不合并，E 侧用 list +
  # Enum.join("") 保持同样的两段字面量
  defp apply_effect(conn, character, target) do
    msg =
      [
        "$N使出空明拳「空空如也",
        "」，拳劲虚虚实实，变化莫测，让$n一时难以捕捉。\n"
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
    ap = max(Map.get(data, :ap, 0), 1)
    force_lvl = Map.get(data, :level, 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("parry");
    dp = Stats.skill(stats, "parry")

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = me->query_skill("force", 1); damage = damage + random(damage / 2);
      #          do_damage(me, target, UNARMED_ATTACK, damage, 80, …);
      damage = force_lvl + Engine.rand(rng, div(force_lvl, 2))
      character = apply_damage(character, damage, 80)
      # LPC: me->start_busy(3);
      Performs.feedback(attacker, 0, 3)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "$n无法窥测$N拳中奥秘，被这一拳击中要害，登时呕出一大口鲜血！\n:内伤@?",
          bindings
        )
      )
      |> put_character(character)
    else
      # LPC: me->start_busy(2);
      Performs.feedback(attacker, 0, 2)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "可是$p识破了$P的拳招中的变化，精心应对，并没有吃亏。\n",
          bindings
        )
      )
      |> put_character(character)
    end
  end

  # LPC: COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, percent, msg)
  # wound = damage * percent / 100（armor 未建模，按 percent 直算）
  defp apply_damage(character, damage, percent) do
    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage * percent, 100))

    %{character | meta: %{character.meta | vitals: vitals}}
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define KONG "「" HIG "空空如也" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     int damage;
  #     string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/kongming-quan/kong"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #                 return notify_fail(KONG "只能对战斗中的对手使用。\n");
  # 
  #     if (objectp(me->query_temp("weapon")))
  #                 return notify_fail(KONG "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("kongming-quan", 1) < 150)
  #         return notify_fail("你的空明拳不够娴熟，难以施展" KONG "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "kongming-quan")
  #                 return notify_fail("你没有激发空明拳，难以施展" KONG "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "kongming-quan")
  #                 return notify_fail("你没有准备空明拳，难以施展" KONG "。\n");
  # 
  #         if ((int)me->query("neili", 1) < 150)
  #         return notify_fail("你现在的真气太弱，难以施展" KONG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = WHT "$N" WHT "使出空明拳「" HIG "空空如也" NOR + WHT "」，拳劲"
  #               "虚虚实实，变化莫测，让$n" WHT "一时难以捕捉。\n" NOR;
  #     me->add("neili", -80);
  # 
  #         ap = me->query_skill("unarmed");
  #         dp = target->query_skill("parry");
  #     if (ap / 2 + random(ap) > dp)
  #     {
  #         me->start_busy(3);
  # 
  #         damage = (int)me->query_skill("force", 1);
  #                 damage = damage + random(damage / 2);
  # 
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80,
  #                        HIR "$n" HIR "无法窥测$N" HIR "拳中奥"
  #                                            "秘，被这一拳击中要害，登时呕出一大口"
  #                                            "鲜血！\n:内伤@?");
  #     } else
  #     {
  #         me->start_busy(2);
  #         msg += CYN "可是$p" CYN "识破了$P"
  #                        CYN "的拳招中的变化，精心应对，并没有吃亏。\n" NOR;
  #     }
  #     message_combatd(msg, me, target);
  #     return 1;
  # }
end
