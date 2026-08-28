defmodule ExKantele.World.Item.Yinzhen do
  @moduledoc """
  Silver Needle (Yinzhen) - Acupuncture item
  Source: lpc_example/item/item_yinzhen.c

  Full migration with acupuncture logic (zhenjiu verb).
  Requires framework capabilities documented in FRAMEWORK_REQUIREMENTS.md.
  """

  alias ExKantele.World.{Player, Item, Skill}

  @cd_seconds 60
  @min_skill 60

  def init_item do
    %{
      id: "yinzhen",
      name: "Silver Needle",
      type: "acupuncture_tool",
      weight: 100,
      value: 5000,
      verb: "zhenjiu",
      description: "A silver needle for acupuncture treatment."
    }
  end

  def can_use?(player, _target) do
    skill_level = Skill.get_level(player, "zhenjiu-shu") || 0
    skill_level >= @min_skill
  end

  def execute(_context, %{player: player, target: target}) do
    with :ok <- check_skill(player),
         :ok <- check_handing(player),
         :ok <- check_target(player, target),
         :ok <- check_busy(player),
         :ok <- check_force(player, target),
         :ok <- check_vitals(player, target),
         :ok <- check_cooldown(player, target) do

      consume_resources(player)
      apply_cooldown(player, target)

      case determine_outcome(player) do
        :success -> heal_outcome(player, target)
        :fail -> fail_outcome(player, target)
      end
    end
  end

  # --- Checks ---

  defp check_skill(player) do
    if Skill.has?(player, "zhenjiu-shu") do
      :ok
    else
      {:error, "You don't know acupuncture technique (zhenjiu-shu)."}
    end
  end

  defp check_handing(player) do
    if Item.is_handing?(player, "yinzhen") do
      :ok
    else
      {:error, "You must be holding the silver needle."}
    end
  end

  defp check_target(player, target) do
    cond do
      not Player.alive?(target) ->
        {:error, "Target is not alive."}

      Player.is_player?(target) and target != player ->
        {:error, "Cannot acupuncture other players."}

      Player.is_npc?(target) and Skill.get_level(target, "force") >= 300 ->
        {:error, "Target's internal force is too strong."}

      true -> :ok
    end
  end

  defp check_busy(player) do
    if Player.busy?(player) do
      {:error, "You are busy right now."}
    else
      :ok
    end
  end

  defp check_force(_player, target) do
    if Skill.get_level(target, "force") < 300 do
      :ok
    else
      {:error, "Target's internal force is too strong."}
    end
  end

  defp check_vitals(_player, target) do
    eff_qi_pct = Player.eff_qi_pct(target) * 100
    if eff_qi_pct > 5 do
      :ok
    else
      {:error, "Target's eff_qi is too low for safe acupuncture."}
    end
  end

  defp check_cooldown(player, target) do
    last_key = "last_zhenjiu_#{target.id}"
    last_time = Player.get_temp(player, last_key) || 0

    if System.monotonic_time(:second) - last_time >= @cd_seconds do
      :ok
    else
      {:error, "Acupuncture on this target is on cooldown."}
    end
  end

  # --- Execution ---

  defp consume_resources(player) do
    Player.add_neili(player, -30)
    Player.add_jing(player, -20)
    Player.start_busy(player, 3)
  end

  defp apply_cooldown(player, target) do
    key = "last_zhenjiu_#{target.id}"
    Player.put_temp(player, key, System.monotonic_time(:second))
  end

  defp determine_outcome(player) do
    skill = Skill.get_level(player, "zhenjiu-shu") || 0
    roll = :rand.uniform(120)

    if roll > skill do
      :fail
    else
      :success
    end
  end

  defp heal_outcome(player, target) do
    skill = Skill.get_level(player, "zhenjiu-shu") || 0
    heal_amount = 50 + div(skill, 2)

    Player.heal_qi(target, heal_amount)
    Player.add_eff_qi(target, div(heal_amount, 2))

    Skill.improve(player, "zhenjiu-shu", 100)

    {:ok, %{type: :heal, target: target.id, amount: heal_amount, message: "Acupuncture successful. Target healed."}}
  end

  defp fail_outcome(player, target) do
    dmg = 20 + :rand.uniform(30)

    Player.receive_wound(target, "qi", dmg, player)
    Player.receive_wound(target, "eff_qi", div(dmg, 2), player)

    {:ok, %{type: :fail, target: target.id, damage: dmg, message: "Acupuncture failed! Target injured."}}
  end
end