defmodule ExKantele.World.Item.Qianzhumiji do
  @moduledoc """
  Qianzhumiji (Thousand Spiders Ten Thousand Poisons Manual)
  Source: lpc_example/item/item_wudu_qianzhumiji.c

  Full migration: research/du/yanjiu verbs unlock 3 performs sequentially.
  Requires qianzhu-wandushou skill progression.
  Framework requirements in FRAMEWORK_REQUIREMENTS.md.
  """

  alias ExKantele.World.{Player, Skill, Item}

  @techniques %{
    "suck" => [
      name: "Absorb Poison Cultivation",
      skill: "qianzhu-wandushou",
      min_skill: 100,
      min_hand: 100,
      min_poison: 100,
      min_force: 150,
      min_neili: 1000,
      success_rate: 5,    # 5% base
      max_success: 100,   # cap at 100%
      cost_potential: 1,
      cost_jing: 30,
      cost_qi: 30,
      busy: 2
    ],
    "zhugu" => [
      name: "Spider Gu Decision",
      skill: "qianzhu-wandushou",
      min_skill: 130,
      min_hand: 130,
      min_poison: 130,
      min_force: 200,
      min_neili: 1500,
      success_rate: 5,
      max_success: 100,
      cost_potential: 1,
      cost_jing: 30,
      cost_qi: 30,
      busy: 2
    ],
    "wan" => [
      name: "Ten Thousand Gu Devour Heaven",
      skill: "qianzhu-wandushou",
      min_skill: 220,
      min_hand: 220,
      min_poison: 200,
      min_force: 300,
      min_neili: 3500,
      success_rate: 5,
      max_success: 100,
      cost_potential: 1,
      cost_jing: 30,
      cost_qi: 30,
      busy: 2
    ]
  }

  @order ["suck", "zhugu", "wan"]

  def init_item do
    %{
      id: "qianzhu_miji",
      name: "Qianzhumiji",
      type: "secret_manual",
      weight: 500,
      value: 0,
      no_sell: true,
      verbs: ["yanjiu", "research", "du"],
      description: "Lost manual of Thousand Spiders Ten Thousand Poisons Hand. Research to unlock techniques."
    }
  end

  def can_read?(player) do
    Skill.has?(player, "literate")
  end

  def execute(_context, %{player: player, args: args}) do
    verb = extract_verb(args)
    technique = extract_technique(args)

    with :ok <- check_literate(player),
         :ok <- check_verb(verb),
         :ok <- check_technique(technique),
         technique_data <- get_technique(technique),
         :ok <- check_prerequisites(player, technique_data),
         :ok <- check_resources(player, technique_data) do

      consume_resources(player, technique_data)
      apply_busy(player, technique_data)

      case attempt_unlock(player, technique, technique_data) do
        :success -> grant_perform(player, technique)
        :fail -> {:error, "Research failed. Keep studying."}
      end
    end
  end

  # --- Public API for different verbs ---

  def yanjiu(context, params), do: execute(context, params)
  def research(context, params), do: execute(context, params)
  def du(context, params), do: execute(context, params)

  # --- Checks ---

  defp extract_verb(args) do
    case args do
      %{verb: v} -> v
      _ -> "yanjiu"
    end
  end

  defp extract_technique(args) do
    case args do
      %{technique: t} -> t
      %{target: t} -> t
      _ -> next_locked_technique(nil)
    end
  end

  defp check_literate(player) do
    if Skill.has?(player, "literate") do
      :ok
    else
      {:error, "You are illiterate. Learn to read first."}
    end
  end

  defp check_verb(verb) do
    if verb in ["yanjiu", "research", "du"] do
      :ok
    else
      {:error, "Invalid research verb. Use: yanjiu, research, or du."}
    end
  end

  defp check_technique(technique) do
    if technique in @order do
      :ok
    else
      {:error, "Unknown technique: #{technique}. Available: #{inspect(@order)}"}
    end
  end

  defp get_technique(name) do
    @techniques[name]
  end

  defp next_locked_technique(player) do
    Enum.find(@order, fn tech ->
      not Player.has_perform?(player, "qianzhu-wandushou/#{tech}")
    end)
  end

  defp check_prerequisites(player, tech) do
    cond do
      not Skill.has?(player, tech.skill) ->
        {:error, "You haven't learned #{tech.skill}."}

      Skill.get_level(player, tech.skill) < tech.min_skill ->
        {:error, "Your #{tech.skill} is insufficient (need #{tech.min_skill})."}

      Skill.get_level(player, "hand") < tech.min_hand ->
        {:error, "Your basic hand technique is insufficient (need #{tech.min_hand})."}

      Skill.get_level(player, "poison") < tech.min_poison ->
        {:error, "Your poison technique is insufficient (need #{tech.min_poison})."}

      Skill.get_level(player, "force") < tech.min_force ->
        {:error, "Your internal force cultivation is insufficient (need #{tech.min_force})."}

      Player.max_neili(player) < tech.min_neili ->
        {:error, "Your max neili is insufficient (need #{tech.min_neili})."}

      Player.has_perform?(player, "qianzhu-wandushou/#{tech_name(tech)}") ->
        {:error, "You have already mastered this technique."}

      true -> :ok
    end
  end

  defp check_resources(player, tech) do
    if Player.potential(player) >= tech.cost_potential and
       Player.jing(player) >= tech.cost_jing and
       Player.qi(player) >= tech.cost_qi do
      :ok
    else
      {:error, "Insufficient potential/jing/qi for research."}
    end
  end

  defp consume_resources(player, tech) do
    Player.add_potential(player, -tech.cost_potential)
    Player.add_jing(player, -tech.cost_jing)
    Player.add_qi(player, -tech.cost_qi)
  end

  defp apply_busy(player, tech) do
    Player.start_busy(player, tech.busy)
  end

  defp attempt_unlock(player, _name, tech) do
    base = tech.success_rate
    bonus = div(Skill.get_level(player, tech.skill) - tech.min_skill, 10) * 2
    chance = min(base + bonus, tech.max_success)

    if :rand.uniform(100) <= chance do
      :success
    else
      :fail
    end
  end

  defp grant_perform(player, name) do
    perform_key = "qianzhu-wandushou/#{name}"
    Player.grant_perform(player, perform_key)
    Skill.improve(player, "qianzhu-wandushou", 5_000_000)
    Skill.improve(player, "poison", 5_000_000)

    {:ok, %{technique: name, name: tech_name(name), message: "You mastered #{tech_name(name)}!"}}
  end

  defp tech_name(%{name: name}), do: name
  defp tech_name(name), do: @techniques[name].name
end