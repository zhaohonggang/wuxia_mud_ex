defmodule Kantele.Combat.Skills.Performs.GuyueChan.Jing do
  @moduledoc """
  皓月惊空「jing」（对照 `kungfu/skill/guyue-chan/jing.c`，inherit F_SSERVER）

  孤月铲法（铲 staff）攻击绝招：要求真气 >= 200、max_neili >= 600、
  内功 force >= 100、guyue-chan >= 80、铲已激发映射；按 staff 与
  dodge 判定命中（外伤 30%）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "guyue-chan/jing"
  @move_name "「皓月惊空 」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_skill_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_force(stats),
         :ok <- check_max_neili(character),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      apply_perform(conn, character, target, stats)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "staff" do
      :ok
    else
      {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "guyue-chan") < 80 do
      {:error, "你孤月铲法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "staff") == "guyue-chan" do
      :ok
    else
      {:error, "你没有激发孤月铲法，难以施展#{@move_name}。\n"}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 100 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 600 do
      {:error, "你的内力修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_perform(conn, character, target, stats) do
    combat = character.meta.combat
    weapon = Combat.weapon(combat)
    weapon_name = weapon && Map.get(weapon, :name)

    # LPC: msg = HIW "$N" HIW "怒喝一声，将手中的" + wn + HIW "挥舞得呼呼做响，"
    #            "猛然间向$n" HIW "砸去。\n" NOR;
    # NOTE: wn (= weapon->name()) 将起始文案拆成两段字面量。
    p1 = "$N怒喝一声，将手中的"
    p2 = "挥舞得呼呼做响，猛然间向$n砸去。"
    start_msg = p1 <> (weapon_name || "") <> p2
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    ap = Stats.skill(stats, "staff")
    dp = Stats.skill(target.meta.stats, "dodge")

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: ap,
        dp: dp,
        weapon_name: weapon_name,
        rng: &:rand.uniform/1
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
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
    ap = Map.get(data, :ap, 0)
    dp = Map.get(data, :dp, 0)
    weapon_name = Map.get(data, :weapon_name)
    rng = Map.get(data, :rng, &:rand.uniform/1)

    if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp do
      # LPC: damage = ap / 2 + random(ap / 2);
      #      damage += random(damage / 3);
      #      msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 30,
      #        HIR "$n" HIR "只觉眼花缭乱，想闪避已不及，"
      #        "被" + wn + HIR "打中胸口，顿时喷出一口鲜"
      #        "血。\n" NOR);
      #      me->start_busy(3); me->add("neili", -80);
      damage = div(ap, 2) + Engine.rand(rng, max(div(ap, 2), 1))
      damage = damage + Engine.rand(rng, max(div(damage, 3), 1))
      vitals = Vitals.damage(character.meta.vitals, :qi, damage)
      vitals = Vitals.wound(vitals, :qi, div(damage * 30, 100))
      character = %{character | meta: %{character.meta | vitals: vitals}}

      hit_part1 = "$n只觉眼花缭乱，想闪避已不及，被"
      hit_part2 = "打中胸口，顿时喷出一口鲜血。"
      hit_msg = hit_part1 <> (weapon_name || "") <> hit_part2
      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 80, 3)

      conn
      |> put_character(character)
    else
      # LPC: msg += CYN "$n" CYN "见$N" CYN "这招刚猛无比，不敢硬接，只得\n"
      #            "侧身一跳才躲过这招。\n"NOR;
      #      me->start_busy(4); me->add("neili", -200);
      miss_msg = "$n见$N这招刚猛无比，不敢硬接，只得\n侧身一跳才躲过这招。\n"
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 200, 4)

      conn
      |> put_character(character)
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
