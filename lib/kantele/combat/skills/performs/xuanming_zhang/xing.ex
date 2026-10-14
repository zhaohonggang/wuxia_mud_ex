defmodule Kantele.Combat.Skills.Performs.XuanmingZhang.Xing do
  @moduledoc """
  perform「玄冥双行」（source xuanming-zhang/xing.c，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
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

  @perform_id "xuanming-zhang/xing"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "xuanming-zhang")
    ap = Stats.skill(stats, "strike") + Stats.skill(stats, "force")
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "force")

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
          dp: dp,
          rng: rng
        }
      })

      apply_effect(conn, character)
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

  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对
  defp check_gates(character) do
    with :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_resources(character),
         :ok <- check_weapon(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "xuanming-shengong") < 220 -> {:error, "你的玄冥神功火候不够，无法施展「玄冥双行」。\n"}
      Stats.skill(stats, "xuanming-zhang") < 220 -> {:error, "你的玄冥神掌不够熟练，无法施展「玄冥双行」。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "force") != "xuanming-shengong" ->
        {:error, "你没有激发玄冥神功为内功，无法施展「玄冥双行」。\n"}

      Stats.prepared_perform(stats, "strike") == nil or
        String.split(Stats.prepared_perform(stats, "strike"), "/") |> hd() != "xuanming-zhang" ->
        {:error, "你没有准备玄冥神掌，无法施展「玄冥双行」。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 4000 -> {:error, "你的内力修为不足，无法施展「玄冥双行」。\n"}
      vitals.neili < 800 -> {:error, "你的真气不够，无法施展「玄冥双行」。\n"}
      true -> :ok
    end
  end

  defp check_weapon(character) do
    combat = character.meta.combat

    cond do
      Combat.weapon(combat) != nil -> {:error, "「玄冥双行」只能空手施展。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # LPC: me->add("neili", -400); me->start_busy(4)
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 400}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 4)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    # LPC: msg = HIW "\n$N" HIW "默运玄冥神功，展出绝招「" HIR "玄冥双行" HIW "」，猛然间欺身向前，双掌齐出，掌风阴寒无比，掌未到，风先至，瞬息间双掌已拍向$n" HIW "。\n" NOR;
    conn = Broadcast.publish(conn,
      "\n$N默运玄冥神功，展出绝招「玄冥双行」，猛然间欺身向前，双掌齐出，掌风阴寒无比，掌未到，风先至，瞬息间双掌已拍向$n。\n",
      n1: character.name
    )

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「玄冥双行」只能对战斗中的对手使用。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？", n1: attacker.name, n2: character.name)
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    stats = character.meta.stats
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "force")
    hit? = div(ap * 3, 5) + Engine.rand(rng, max(ap, 1)) > dp

    Performs.feedback(attacker, 400, 3)

    vitals =
      if hit? do
        Vitals.damage(character.meta.vitals, :qi, div(ap, 2) + Engine.rand(rng, max(div(ap, 2), 1)))
      else
        character.meta.vitals
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # Stage 1: First palm strike
    msg1 =
      if hit? do
        "面对$N这排山倒海般的攻势，完全无法抵挡，招架散乱，连连退后。\n"
      else
        "那些$p看破了$P的企图，轻轻一跃，跳了开去。\n"
      end

    # Stage 1 message (attacker side)
    msg_stage1 = "\n$N右掌向内一转，忽又向前，猛然间直袭$n面门。\n"

    conn = Broadcast.publish(Messages.interpolate(
      "\n$N右掌向内一转，忽又向前，猛然间直袭$n面门。\n" <> 
      (if hit? do
        "面对$N这排山倒海般的攻势，完全无法抵挡，招架散乱，连连退后。\n"
      else
        "那些$p看破了$P的企图，轻轻一跃，跳了开去。\n"
      end),
      n1: attacker.name, n2: character.name
    ), n1: attacker.name, n2: character.name)

    # Stage 2: Second palm
    msg_stage2 = "\n$N长舒一口气，左掌紧跟而出，风到掌到，正拍向$n胸口。\n"

    # Second palm resolution
    dp2 = Stats.skill(character.meta.stats, "dodge") + Stats.skill(stats, "force")
    hit2? = div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp

    msg2 =
      if hit? do
        "长舒一口气，左掌紧跟而出，风到掌到，正拍向$n胸口。\n" <>
        "只见$n一声惨叫，接连退了数步，“哇”的呕出一大口鲜血。\n"
      else
        "那些$p看破了$P的企图，轻轻一跃，跳了开去。\n"
      end

    # Publish stage 1
    conn = Broadcast.publish(Messages.interpolate(
      "\n$N右掌向内一转，忽又向前，猛然间直袭$n面门。\n" <> 
      (if hit? do
        "面对$N这排山倒海般的攻势，完全无法抵挡，招架散乱，连连退后。\n"
      else
        "那些$p看破了$P的企图，轻轻一跃，跳了开去。\n"
      end),
      n1: attacker.name, n2: character.name
    ), n1: attacker.name, n2: character.name)

    # Second stage
    conn = Broadcast.publish(Messages.interpolate(
      "\n$N长舒一口气，左掌紧跟而出，风到掌到，正拍向$n胸口。\n" <>
      (if hit? do
        "只见$n一声惨叫，接连退了数步，“哇”的呕出一大口鲜血。\n"
      else
        "那些$p看破了$P的企图，轻轻一跃，跳了开去。\n"
      end),
      n1: attacker.name, n2: character.name
    ), n1: attacker.name, n2: character.name)

    Performs.feedback(attacker, 400, 3)

    vitals =
      if hit? do
        Vitals.damage(character.meta.vitals, :qi, div(ap, 2) + Engine.rand(rng, max(div(ap, 2), 1)))
      else
        character.meta.vitals
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn
    |> Broadcast.publish(Messages.interpolate(
      "\n$N右掌向内一转，忽又向前，猛然间直袭$n面门。\n" <>
      (if hit? do
        "面对$N这排山倒海般的攻势，完全无法抵挡，招架散乱，连连退后。\n"
      else
        "那些$p看破了$P的企图，轻轻一跃，跳了开去。\n"
      end),
      n1: attacker.name, n2: character.name
    ), n1: attacker.name, n2: character.name)
    |> Broadcast.publish(Messages.interpolate(
      "\n$N长舒一口气，左掌紧跟而出，风到掌到，正拍向$n胸口。\n" <>
      (if hit? do
        "只见$n一声惨叫，接连退了数步，“哇”的呕出一大口鲜血。\n"
      else
        "那些$p看破了$P的企图，轻轻一跃，跳了开去。\n"
      end),
      n1: attacker.name, n2: character.name
    ), n1: attacker.name, n2: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「玄冥双行」只能对战斗中的对手使用。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-150"}, {"neili", "-200"}, {"neili", "-300"}], "affect_by": ["xuanming_poison"], "assign_refs": [{"ap", "strike"}, {"dp", "dodge"}], "busy_lines": ["me->start_busy(4);"], "level_gates": [{"xuanming-shengong", "220"}, {"xuanming-zhang", "220"}], "map_gates": [{"force", "xuanming-shengong"}, {"strike", "xuanming-zhang"}], "prepared_gates": [{"strike", "xuanming-zhang"}], "remote_damage": true, "resource_gates": [{"max_neili", "4000"}, {"neili", "800"}], "var_gates": [{"damage", "0"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // 终极绝招，待完善……
  # #include <ansi.h>
  # #include <combat.h>
  #
  # #define LANG "「" HIR "玄冥双行" NOR "」"
  #
  # inherit F_SSERVER;
  #
  # string final1(object me, object target, int lvl);
  # string final2(object me, object target, int lvl);
  #
  # int perform(object me, object target)
  # {
  #         // ... (full LPC source as reference)
  # }
  #
  # string final1(object me, object target, int lvl)
  # {
  #         // ...
  # }
  #
  # string final2(object me, object target, int lvl)
  # {
  #         // ...
  # }
  #
  # int perform(object me, object target)
  # {
  #         // ... (full LPC source as reference)
  # }
end