defmodule Kantele.Combat.Skills.Performs.HanmeiJian.Leng do
  @moduledoc """
  冷剑决「leng」（对照 `kungfu/skill/hanmei-jian/leng.c`）

  寒梅剑法攻击绝招：持剑（sword）、force>=50、hanmei-jian>=40、neili>=50、
  sword 已激发映射 hanmei-jian、目标存活且战斗中。
  命中判定 `ap/2 + random(ap) > dp`（ap=sword，dp=目标 force）：
  命中则创伤 `ap/2 + random(ap/3)`、扣内力 30、忙乱 2；落空扣内力 10、忙乱 3。
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

  @perform_id "hanmei-jian/leng"
  @move_name "「冷剑决」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon_name} <- check_weapon(combat),
         :ok <- check_force(stats),
         :ok <- check_skill_level(stats),
         :ok <- check_neili(character),
         :ok <- check_mapped(stats),
         :ok <- check_target_alive(target) do
      apply_perform(conn, character, target, stats, weapon_name)
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

  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      {:ok, Map.get(weapon, :name)}
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 50 do
      {:error, "你的内功的修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "hanmei-jian") < 40 do
      {:error, "你的寒梅剑法修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 50 do
      {:error, "你的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "hanmei-jian" do
      :ok
    else
      {:error, "你没有激发寒梅剑法，难以施展#{@move_name}。\n"}
    end
  end

  defp check_target_alive(target) do
    if dead?(target), do: {:error, "对方都已经这样了，用不着这么费力吧？\n"}, else: :ok
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_perform(conn, character, target, stats, weapon_name) do
    # LPC: msg = HIW "$N" HIW "轻吁一声，飞身一跃而起，手中" + weapon->name() +
    #           HIW "携着阴寒之劲刺向$n" HIW "！\n" NOR;
    start_msg = "$N轻吁一声，飞身一跃而起，手中" <> (weapon_name || "") <> "携着阴寒之劲刺向$n！\n"

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: Stats.skill(stats, "sword"),
        rng: &:rand.uniform/1
      }
    })

    conn
    |> put_character(character)
    |> Broadcast.publish(start_msg, n1: character.name, n2: target.name)
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
    ap = max(Map.get(data, :ap, 0), 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    dp = Stats.skill(character.meta.stats, "force")
    bindings = [n1: attacker.name, n2: character.name]

    if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp do
      damage = div(ap, 2) + Engine.rand(rng, max(div(ap, 3), 1))
      vitals = Vitals.wound(character.meta.vitals, :qi, damage)
      character = %{character | meta: %{character.meta | vitals: vitals}}

      conn = Broadcast.publish(conn, "结果$n一个不慎，顿被$N一剑划出道寸许长的伤口！\n", bindings)

      Performs.feedback(attacker, 30, 2)

      put_character(conn, character)
    else
      conn = Broadcast.publish(conn, "可是$p并不慌乱，收敛心神，轻轻格挡开了$P的剑招。\n", bindings)

      Performs.feedback(attacker, 10, 3)

      conn
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
