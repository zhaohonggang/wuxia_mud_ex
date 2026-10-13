defmodule Kantele.Combat.Skills.Performs.JueqingZhang.Wan do
  @moduledoc """
  perform「万念俱灰」（source jueqing-zhang/wan.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 空手（主副兵器均不可）→
  目标未忙乱 → 绝情掌>=100 → 激发 strike 为绝情掌 → 准备 strike 为绝情掌 →
  轻功>=150 → 内力>=200 → 目标存活。
  ap = 绝情掌 + 轻功/2；dp = 目标轻功（dodge）。
  命中判定：random(ap) > dp/2。无伤害。
  命中：目标忙乱 ap/40+1，攻击方扣 80 内力、忙乱 1；
  未命中：攻击方扣 30 内力、忙乱 2。
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

  @perform_id "jueqing-zhang/wan"
  @move_name "「万念俱灰」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jueqing-zhang")
    ap = Stats.skill(stats, "jueqing-zhang") + div(Stats.skill(stats, "dodge"), 2)

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

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #          return notify_fail(WAN "只能空手施展。\n");
  # 框架无副兵器槽，仅检查主兵器
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

  # LPC: if (me->query_skill("jueqing-zhang", 1) < 100) …
  #     if (me->query_skill("dodge") < 150) …
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "jueqing-zhang") < 100 ->
        {:error, "你绝情掌不够娴熟，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "dodge") < 150 ->
        {:error, "你的轻功修为不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "jueqing-zhang")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "strike") != "jueqing-zhang" do
      {:error, "你没有激发绝情掌，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "jueqing-zhang")
  # prepared_perform 返回绝招 ID（如 jueqing-zhang/wan），须取技能前缀比对
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "strike")

    if prepared == nil or hd(String.split(prepared, "/")) != "jueqing-zhang" do
      {:error, "你没有准备绝情掌，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 200)
  defp check_resources(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
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

  # LPC: msg = HIC "\n$N" HIC "一声长啸，……但内中却隐藏无限杀机。\n" NOR;
  # （C 侧各段字面量仅由颜色宏/空白分隔，合并为同一条文案）
  defp apply_effect(conn, character, target) do
    msg =
      "\n$N一声长啸，声音震耳欲聋，悲痛欲绝，顿感万念俱灰，猛然间双掌疯狂般的拍向$n，看似杂乱无章，但内中却隐藏无限杀机。\n"

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
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("dodge");
    dp = Stats.skill(stats, "dodge")

    # LPC: if (random(ap) > dp / 2)
    if Engine.rand(rng, ap) > div(dp, 2) do
      # LPC: target->start_busy(ap / 40 + 1); me->start_busy(1); me->add("neili", -80);
      combat = Combat.start_busy(character.meta.combat, div(ap, 40) + 1)
      character = %{character | meta: %{character.meta | combat: combat}}
      Performs.feedback(attacker, 80, 1)

      conn
      |> Broadcast.publish(
        Messages.interpolate("$n心神惧裂，一时间竟无从应对，竟被困在$N的掌风之中。\n", bindings)
      )
      |> put_character(character)
    else
      # LPC: me->start_busy(2); me->add("neili", -30);
      Performs.feedback(attacker, 30, 2)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "$n看破$N毫无攻击之意，于是大胆反攻，将$N这招尽数化解。\n",
          bindings
        )
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define WAN "「" HIW "万念俱灰" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/jueqing-zhang/wan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(WAN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(WAN "只能空手施展。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #         if ((int)me->query_skill("jueqing-zhang", 1) < 100)
  #                 return notify_fail("你绝情掌不够娴熟，难以施展" WAN "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "jueqing-zhang")
  #                 return notify_fail("你没有激发绝情掌，难以施展" WAN "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "jueqing-zhang")
  #                 return notify_fail("你没有准备绝情掌，难以施展" WAN "。\n");
  # 
  #         if (me->query_skill("dodge") < 150)
  #                 return notify_fail("你的轻功修为不够，难以施展" WAN "。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不够，难以施展" WAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         ap = me->query_skill("jueqing-zhang", 1) +
  #              me->query_skill("dodge", 1) / 2;
  # 
  #         dp = target->query_skill("dodge");
  # 
  #         msg = HIC "\n$N" HIC "一声长啸，声音震耳欲聋，悲痛欲绝，顿"
  #               "感万念俱灰，猛然间双掌疯狂般的拍向$n，看似杂乱无章，"
  #               "但内中却隐藏无限杀机。\n" NOR;
  #         message_sort(msg, me, target);
  # 
  #         if (random(ap) > dp / 2)
  #         {
  #         msg = HIR "$n" HIR "心神惧裂，一时间竟无从应对，"
  #                       "竟被困在$N" HIR "的掌风之中。\n" NOR;
  # 
  #                 target->start_busy(ap / 40 + 1);
  #                    me->start_busy(1);
  #                 me->add("neili", -80);
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
