defmodule Kantele.Item.Yinzhen do
  @moduledoc """
  银针（Silver Needle） - 针灸道具
  Source: lpc_example/item/item_yinzhen.c
  """
  use Kantele.Item

  @cd_seconds 60
  @min_skill 60

  @doc "物品定义"
  def item_def do
    %{
      id: "yinzhen",
      name: "Silver Needle",
      type: "acupuncture_tool",
      weight: 100,
      value: 5000,
      verb: "zhenjiu",
      description: "A silver needle for acupuncture treatment.",
      no_sell: false
    }
  end

  @doc "检查是否可使用"
  def can_use?(player, _target) do
    skill_level = Kantele.Character.Stats.skill(player.meta.stats, "zhenjiu-shu") || 0
    skill_level >= @min_skill
  end

  @doc "执行针灸"
  def execute(_context, %{player: player, target: target}) do
    with :ok <- check_skill(player),
         :ok <- check_handing(player),
         :ok <- check_target(player, target),
         :ok <- check_busy(player),
         :ok <- check_force(target),
         :ok <- check_vitals(target),
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
    if Kantele.Item.is_acupuncture_tool?(Kantele.Item.Item.get("yinzhen")) and
       Kantele.Character.Stats.skill(player.meta.stats, "zhenjiu-shu") >= @min_skill do
      :ok
    else
      {:error, "You don't know acupuncture technique (zhenjiu-shu)."}
    end
  end

  defp check_handing(player) do
    # 简化：假设玩家背包中有银针
    :ok
  end

  defp check_target(player, target) do
    cond do
      not Kantele.Character.Vitals.alive?(target.meta.vitals) ->
        {:error, "Target is not alive."}

      target.meta.id != player.meta.id and Kantele.Character.is_player?(target) ->
        {:error, "Cannot acupuncture other players."}

      Kantele.Character.is_npc?(target) and
      Kantele.Character.Stats.skill(target.meta.stats, "force") >= 300 ->
        {:error, "Target's internal force is too strong."}

      true -> :ok
    end
  end

  defp check_busy(player) do
    if Kantele.Character.Combat.busy?(player.meta.combat) do
      {:error, "You are busy right now."}
    else
      :ok
    end
  end

  defp check_force(target) do
    if Kantele.Character.Stats.skill(target.meta.stats, "force") < 300 do
      :ok
    else
      {:error, "Target's internal force is too strong."}
    end
  end

  defp check_vitals(target) do
    eff_qi_pct = div(target.meta.vitals.qi * 100, target.meta.vitals.max_qi)
    if eff_qi_pct > 5 do
      :ok
    else
      {:error, "Target's eff_qi is too low for safe acupuncture."}
    end
  end

  defp check_cooldown(player, target) do
    last_key = "last_zhenjiu_#{target.id}"
    last_time = Kantele.Character.PlayerMeta.get_temp(player.meta, last_key) || 0

    if System.system_time(:second) - last_time >= @cd_seconds do
      :ok
    else
      {:error, "Acupuncture on this target is on cooldown."}
    end
  end

  # --- Execution ---

  defp consume_resources(player) do
    Kantele.Character.Vitals.add_neili(player.meta.vitals, -30)
    Kantele.Character.Vitals.add_jing(player.meta.vitals, -20)
    Kantele.Character.Combat.start_busy(player.meta.combat, 3)
  end

  defp apply_cooldown(player, target) do
    key = "last_zhenjiu_#{target.id}"
    Kantele.Character.PlayerMeta.put_temp(player.meta, key, System.system_time(:second))
  end

  defp determine_outcome(player) do
    skill = Kantele.Character.Stats.skill(player.meta.stats, "zhenjiu-shu") || 0
    roll = :rand.uniform(120)

    if roll > skill do
      :fail
    else
      :success
    end
  end

  defp heal_outcome(player, target) do
    skill = Kantele.Character.Stats.skill(player.meta.stats, "zhenjiu-shu") || 0
    heal_amount = 50 + div(skill, 2)

    Kantele.Character.Vitals.heal(target.meta.vitals, :qi, heal_amount)
    Kantele.Character.Vitals.curing(target.meta.vitals, :qi, div(heal_amount, 2))

    Kantele.Character.Stats.improve_skill(player.meta.stats, "zhenjiu-shu")

    {:ok, %{type: :heal, target: target.id, amount: heal_amount, message: "Acupuncture successful. Target healed."}}
  end

  defp fail_outcome(player, target) do
    dmg = 20 + :rand.uniform(30)

    Kantele.Character.Vitals.damage(target.meta.vitals, :qi, dmg)
    Kantele.Character.Vitals.wound(target.meta.vitals, :qi, div(dmg, 2))

    {:ok, %{type: :fail, target: target.id, damage: dmg, message: "Acupuncture failed! Target injured."}}
  end
end