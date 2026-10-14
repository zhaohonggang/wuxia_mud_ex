defmodule Kantele.Combat.Skills.Performs.XuanmingZhang.Xing do
  @moduledoc """
  perform「玄冥双行」（source xuanming-zhang/xing.c，inherit F_SSERVER）

  两掌连击：第一掌 `ap*3/5+random(ap)>dp`，第二掌 `ap/2+random(ap)>dp`；
  攻击方扣内气 / 忙乱由目标侧经 `combat/perform-feedback` 回执。
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

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
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
          Stats.prepared_perform(stats, "strike") |> String.split("/") |> hd() != "xuanming-zhang" ->
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
    # 前置广播：攻击方文案；内力消耗/忙乱由目标侧结算后经 perform-feedback 回执。
    # LPC: msg = HIW "\n$N" HIW "默运玄冥神功，展出绝招「" HIR "玄冥双行" HIW "」，…已拍向$n" HIW "！\n" NOR;
    conn =
      Broadcast.publish(
        conn,
        "\n$N默运玄冥神功，展出绝招「玄冥双行」，猛然间欺身向前，双掌齐出，掌风阴寒无比，掌未到，风先至，瞬息间双掌已拍向$n！\n",
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

    conn = first_strike(conn, character, attacker, ap, dp, rng)
    character = conn.character
    second_strike(conn, character, attacker, ap, dp, rng)
  end

  # 第一掌
  defp first_strike(conn, character, attacker, ap, dp, rng) do
    hit? = div(ap * 3, 5) + Engine.rand(rng, max(ap, 1)) > dp

    {conn, character} =
      if hit? do
        Performs.feedback(attacker, 200, 4)
        damage = div(ap, 2) + Engine.rand(rng, max(ap, 1))
        vitals = Vitals.damage(character.meta.vitals, :qi, damage)
        character = %{character | meta: %{character.meta | vitals: vitals}}
        {conn, character}
      else
        Performs.feedback(attacker, 100, 4)
        {conn, character}
      end

    msg =
      if hit? do
        "$n正欲闪躲，却见$N突然绕到$p身后，$n心中一惊，背后中掌，顿觉脊梁处一股寒气升起，尽损三焦六脉。\n"
      else
        "$n看见$N来势汹涌，急忙提气跃开。\n"
      end

    body =
      Messages.interpolate(
        "\n$N右掌向内一转，忽又向前，猛然间直袭$n面门。\n" <> msg,
        n1: attacker.name,
        n2: character.name
      )

    conn = Broadcast.publish(conn, body)

    {conn, character}
  end

  # 第二掌
  defp second_strike(conn, character, attacker, ap, dp, rng) do
    hit? = div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp

    character =
      if hit? do
        Performs.feedback(attacker, 300, 4)
        damage = div(ap * 3, 5) + Engine.rand(rng, max(ap, 1))
        vitals = Vitals.damage(character.meta.vitals, :qi, damage)
        %{character | meta: %{character.meta | vitals: vitals}}
      else
        Performs.feedback(attacker, 150, 4)
        character
      end

    msg =
      if hit? do
        "$n但见$N右掌已攻出，正欲反击。突然间胸口一震，不禁暗暗叫苦，顿感胸口处一股寒气升起，尽损三焦六脉。\n"
      else
        "$n看见$N来势汹涌，急忙提气跃开。\n"
      end

    body =
      Messages.interpolate(
        "\n$N长舒一口气，左掌紧跟而出，风到掌到，正拍向$n胸口。\n" <> msg,
        n1: attacker.name,
        n2: character.name
      )

    conn
    |> Broadcast.publish(body)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-150"}, {"neili", "-200"}, {"neili", "-300"}], "affect_by": ["xuanming_poison"], "assign_refs": [{"ap", "strike"}, {"dp", "dodge"}], "busy_lines": ["me->start_busy(4);"], "level_gates": [{"xuanming-shengong", "220"}, {"xuanming-zhang", "220"}], "map_gates": [{"force", "xuanming-shengong"}, {"strike", "xuanming-zhang"}], "prepared_gates": [{"strike", "xuanming-zhang"}], "remote_damage": true, "resource_gates": [{"max_neili", "4000"}, {"neili", "800"}]}
end
