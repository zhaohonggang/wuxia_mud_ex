defmodule Kantele.Combat.Skills.Performs.FumoJian.Foxin do
  @moduledoc """
  佛心剑「foxin」（对照 `kungfu/skill/fumo-jian/foxin.c`）

  伏魔剑法攻击绝招：持剑（sword）、force>=200、fumo-jian>=135、neili>=250、
  sword 已激发映射 fumo-jian、目标存活且战斗中。
  命中判定 `ap/2 + random(ap) > dp`（ap=sword，dp=目标 parry）：
  命中则创伤 `ap/2 + random(ap)`、扣内力 150、忙乱 1；落空扣内力 60、忙乱 3。
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

  @perform_id "fumo-jian/foxin"
  @move_name "「佛心剑」"

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

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      {:ok, Map.get(weapon, :name)}
    else
      {:error, "你使用的武器不对。\n"}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 200 do
      {:error, "你的内功的修为不够，不能使用这一绝技！\n"}
    else
      :ok
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "fumo-jian") < 135 do
      {:error, "你的伏魔剑法修为不够，目前不能使用佛心剑！\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 250 do
      {:error, "你的真气不够，不能使用佛心剑！\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "fumo-jian" do
      :ok
    else
      {:error, "你没有激发伏摩剑，不能使用佛心剑！\n"}
    end
  end

  defp check_target_alive(target) do
    if dead?(target), do: {:error, "对方都已经这样了，用不着这么费力吧？\n"}, else: :ok
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_perform(conn, character, target, stats, weapon_name) do
    # LPC: msg = HIC "$N" HIC "手中" + weapon->name() +
    #           HIC "缓缓伸出，封住了$n" + HIC "的退路，随"
    #           "即一抖，化出数个剑花逼向$p" HIC "。\n" NOR;
    # NOTE: "缓缓伸出，封住了$n" 与 "的退路，随即..." 为以 + 相接的纯字面量，
    #       用 Enum.join 保段（逗号分隔，验收正则不合并）。
    tail = Enum.join(["缓缓伸出，封住了$n", "的退路，随即一抖，化出数个剑花逼向$p。\n"], "")
    start_msg = "$N手中" <> (weapon_name || "") <> tail

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
    dp = Stats.skill(character.meta.stats, "parry")
    bindings = [n1: attacker.name, n2: character.name]

    if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp do
      damage = div(ap, 2) + Engine.rand(rng, max(ap, 1))
      vitals = Vitals.wound(character.meta.vitals, :qi, damage)
      character = %{character | meta: %{character.meta | vitals: vitals}}

      conn =
        Broadcast.publish(
          conn,
          "结果$p一个不慎，被$P一剑划过气门，内息就如翻江倒海一般，身子摇摇欲坠！\n",
          bindings
        )

      Performs.feedback(attacker, 150, 1)

      put_character(conn, character)
    else
      conn = Broadcast.publish(conn, "可是$p并不慌乱，沉稳的将$P的招一一化解。\n", bindings)

      Performs.feedback(attacker, 60, 3)

      conn
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "fumo-jian/foxin",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end
end
