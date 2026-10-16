defmodule Kantele.Combat.Skills.Performs.HanwangQingdao.Ying do
  @moduledoc """
  刀影重重「ying」（对照 `kungfu/skill/hanwang-qingdao/ying.c`）

  汉王清刀攻击绝招：持刀（blade）、force>=120、hanwang-qingdao>=80、neili>=100、
  blade 已激发映射 hanwang-qingdao、目标存活且战斗中。
  命中判定 `ap/2 + random(ap) > dp`（ap=blade，dp=目标 parry）：
  命中则创伤 `ap/3 + random(ap/3)`、扣内力 80、忙乱 1；落空扣内力 40、忙乱 3。
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

  @perform_id "hanwang-qingdao/ying"
  @move_name "「刀影重重」"

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
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "blade" do
      {:ok, Map.get(weapon, :name)}
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 120 do
      {:error, "你的内功的修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "hanwang-qingdao") < 80 do
      {:error, "你的韩王青刀修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你目前的内力不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "blade") == "hanwang-qingdao" do
      :ok
    else
      {:error, "你没有激发韩王青刀，难以施展#{@move_name}。\n"}
    end
  end

  defp check_target_alive(target) do
    if dead?(target), do: {:error, "对方都已经这样了，用不着这么费力吧？\n"}, else: :ok
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_perform(conn, character, target, stats, weapon_name) do
    # LPC: msg = HIC "霎时只见$N" HIC "手中" + weapon->name() +
    #           HIC "一振，顿时幻出重重刀影，将$n" HIC "团团裹住！\n" NOR;
    start_msg = "霎时只见$N手中" <> (weapon_name || "") <> "一振，顿时幻出重重刀影，将$n团团裹住！\n"

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: Stats.skill(stats, "blade"),
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
    dp = Stats.skill(character.meta.stats, "parry")
    bindings = [n1: attacker.name, n2: character.name]

    if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp do
      damage = div(ap, 3) + Engine.rand(rng, max(div(ap, 3), 1))
      vitals = Vitals.wound(character.meta.vitals, :qi, damage)
      character = %{character | meta: %{character.meta | vitals: vitals}}

      conn = Broadcast.publish(conn, "只听$p一声惨嚎，一股血柱自血色刀影中激射而出！\n", bindings)

      Performs.feedback(attacker, 80, 1)

      put_character(conn, character)
    else
      conn = Broadcast.publish(conn, "可是$n淡淡一笑，浑然不将$N重重刀影放在眼中，随意将之架开。\n", bindings)

      Performs.feedback(attacker, 40, 3)

      conn
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
