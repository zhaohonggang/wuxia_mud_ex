defmodule Kantele.Item.Qianzhumiji do
  @moduledoc """
  千蛛千珠秘籍 - 秘籍道具
  Source: lpc_example/item/item_wudu_qianzhumiji.c
  """
  use Kantele.Item

  @techniques %{
    "suck" => %{
      name: "吸毒大法",
      skill: "qianzhu-wandushou",
      min_skill: 100,
      min_hand: 100,
      min_poison: 100,
      min_force: 150,
      min_neili: 1000,
      cost_potential: 1,
      cost_jing: 30,
      cost_qi: 30,
      busy_seconds: 2
    },
    "zhugu" => %{
      name: "蛛蛊大法",
      skill: "qianzhu-wandushou",
      min_skill: 130,
      min_hand: 130,
      min_poison: 130,
      min_force: 200,
      min_neili: 1500,
      cost_potential: 1,
      cost_jing: 30,
      cost_qi: 30,
      busy_seconds: 2
    },
    "wan" => %{
      name: "万蛊噬天",
      skill: "qianzhu-wandushou",
      min_skill: 220,
      min_hand: 220,
      min_poison: 200,
      min_force: 300,
      min_neili: 3500,
      cost_potential: 1,
      cost_jing: 30,
      cost_qi: 30,
      busy_seconds: 2
    }
  }

  @order ["suck", "zhugu", "wan"]

  @doc "物品定义"
  def item_def do
    %{
      id: "qianzhu_miji",
      name: "千蛛千珠秘籍",
      type: "secret_manual",
      weight: 500,
      value: 50000,
      verb: "yanjiu",
      description: "A secret manual containing poison techniques.",
      no_sell: true
    }
  end

  @doc "检查是否可读"
  def can_read?(player) do
    if Kantele.Character.Stats.skill(player.meta.stats, "literate") > 0 do
      :ok
    else
      {:error, "You are illiterate and cannot read this manual."}
    end
  end

  @doc "执行研习"
  def execute(_context, %{player: player, technique: technique}) do
    with :ok <- check_verb(player),
         :ok <- check_technique(technique),
         {:ok, tech} <- get_technique(technique),
         :ok <- check_prerequisites(player, tech),
         :ok <- check_resources(player, tech),
         :ok <- check_cooldown(player) do

    consume_resources(player, tech)
    apply_busy(player, tech)

    case attempt_unlock(player, tech) do
      :success ->
        grant_perform(player, tech)
        {:ok, %{type: :unlock, technique: tech.name, message: "Technique unlocked!"}}

      :fail ->
        {:ok, %{type: :fail, technique: tech.name, message: "Research failed."}}
    end
    end
  end

  # --- Checks ---

  defp check_verb(player) do
    # 简化：假设玩家输入了正确的动词
    :ok
  end

  defp check_technique(technique) do
    if Map.has_key?(@techniques, technique) do
      :ok
    else
      {:error, "Unknown technique: #{technique}"}
    end
  end

  defp get_technique(technique) do
    Map.fetch(@techniques, technique)
  end

  defp check_prerequisites(player, tech) do
    cond do
      Kantele.Character.Stats.skill(player.meta.stats, "literate") < 1 ->
        {:error, "You are illiterate and cannot understand this manual."}

      Kantele.Character.Stats.skill(player.meta.stats, "qianzhu-wandushou") < tech.min_skill ->
        {:error, "Your qianzhu-wandushou skill is too low."}

      Kantele.Character.Stats.skill(player.meta.stats, "hand") < tech.min_hand ->
        {:error, "Your hand technique is insufficient."}

      Kantele.Character.Stats.skill(player.meta.stats, "poison") < tech.min_poison ->
        {:error, "Your poison skill is insufficient."}

      Kantele.Character.Stats.skill(player.meta.stats, "force") < tech.min_force ->
        {:error, "Your internal force is insufficient."}

      Kantele.Character.Stats.skill(player.meta.stats, "neili") < tech.min_neili ->
        {:error, "Your internal energy is insufficient."}

      Kantele.Character.Stats.perform_known?(player.meta.stats, "qianzhu-wandushou/#{tech.name}") ->
        {:error, "You have already learned this technique."}

      true -> :ok
    end
  end

  defp check_resources(player, tech) do
    cond do
      Kantele.Character.Stats.potential(player.meta.stats) < tech.cost_potential ->
        {:error, "Insufficient potential."}

      player.meta.vitals.jing < tech.cost_jing ->
        {:error, "Insufficient jing."}

      player.meta.vitals.qi < tech.cost_qi ->
        {:error, "Insufficient qi."}

      true -> :ok
    end
  end

  defp check_cooldown(player) do
    # 简化：无冷却限制
    :ok
  end

  # --- Execution ---

  defp consume_resources(player, tech) do
    Kantele.Character.Stats.add_potential(player.meta.stats, -tech.cost_potential)
    Kantele.Character.Vitals.add_jing(player.meta.vitals, -tech.cost_jing)
    Kantele.Character.Vitals.add_qi(player.meta.vitals, -tech.cost_qi)
  end

  defp apply_busy(player, tech) do
    Kantele.Character.Combat.start_busy(player.meta.combat, tech.busy_seconds)
  end

  defp attempt_unlock(player, tech) do
    skill = Kantele.Character.Stats.skill(player.meta.stats, "qianzhu-wandushou") || 0
    base_rate = 5
    bonus = div(max(skill - tech.min_skill, 0), 10) * 2
    chance = min(base_rate + bonus, 100)
    roll = :rand.uniform(100)

    if roll <= chance do
      :success
    else
      :fail
    end
  end

  defp grant_perform(player, tech) do
    Kantele.Character.Stats.learn_perform(player.meta.stats, "qianzhu-wandushou/#{tech.name}")
    Kantele.Character.Stats.improve_skill(player.meta.stats, "qianzhu-wandushou")
  end
end