defmodule ExKantele.World.Npc.Horseboss do
  @moduledoc """
  Pet Shop Owner (Horseboss) - Mount Creation Guide
  Source: lpc_example/npc/npc_horseboss.c

  Full migration: Multi-stage pet creation wizard (choose species -> gender -> ID -> name -> description).
  Generates random mount stats, creates persistent mount instance for player.
  Framework requirements in FRAMEWORK_REQUIREMENTS.md.
  """

  alias ExKantele.World.{Player, Item, Character, Skill}

  @species %{
    horse: %{name: "Horse", id_suffix: "ma", unit: "match", base_stats: %{str: 30, con: 25, dex: 20, int: 10}},
    donkey: %{name: "Donkey", id_suffix: "lv", unit: "head", base_stats: %{str: 25, con: 30, dex: 15, int: 10}},
    mule: %{name: "Mule", id_suffix: "luo", unit: "head", base_stats: %{str: 35, con: 35, dex: 10, int: 10}},
    camel: %{name: "Camel", id_suffix: "tuo", unit: "head", base_stats: %{str: 40, con: 40, dex: 10, int: 10}},
    ox: %{name: "Ox", id_suffix: "niu", unit: "head", base_stats: %{str: 45, con: 45, dex: 5, int: 10}},
    elephant: %{name: "Elephant", id_suffix: "xiang", unit: "head", base_stats: %{str: 60, con: 50, dex: 5, int: 15}},
    lion: %{name: "Lion", id_suffix: "shi", unit: "head", base_stats: %{str: 50, con: 40, dex: 30, int: 15}},
    tiger: %{name: "Tiger", id_suffix: "hu", unit: "head", base_stats: %{str: 55, con: 40, dex: 35, int: 15}},
    leopard: %{name: "Leopard", id_suffix: "bao", unit: "head", base_stats: %{str: 45, con: 35, dex: 40, int: 15}},
    deer: %{name: "Deer", id_suffix: "lu", unit: "head", base_stats: %{str: 25, con: 30, dex: 45, int: 15}},
    crane: %{name: "Crane", id_suffix: "he", unit: "head", base_stats: %{str: 20, con: 25, dex: 50, int: 20}},
    eagle: %{name: "Eagle", id_suffix: "diao", unit: "head", base_stats: %{str: 30, con: 25, dex: 55, int: 20}},
    goat: %{name: "Goat", id_suffix: "yang", unit: "head", base_stats: %{str: 20, con: 25, dex: 30, int: 10}},
    monkey: %{name: "Monkey", id_suffix: "hou", unit: "head", base_stats: %{str: 25, con: 25, dex: 50, int: 25}},
    bear: %{name: "Bear", id_suffix: "xiong", unit: "head", base_stats: %{str: 55, con: 50, dex: 15, int: 10}},
    wolf: %{name: "Wolf", id_suffix: "lang", unit: "head", base_stats: %{str: 40, con: 35, dex: 40, int: 15}},
    fox: %{name: "Fox", id_suffix: "hu", unit: "head", base_stats: %{str: 30, con: 30, dex: 45, int: 20}},
    marten: %{name: "Marten", id_suffix: "diao", unit: "head", base_stats: %{str: 20, con: 25, dex: 50, int: 20}},
    foal: %{name: "Foal", id_suffix: "ju", unit: "match", base_stats: %{str: 15, con: 15, dex: 20, int: 10}},
    beast: %{name: "Beast", id_suffix: "shou", unit: "head", base_stats: %{str: 50, con: 50, dex: 20, int: 10}}
  }

  @price 1000000  # 100 gold in copper

  @training_req 30

  def init_npc do
    %{
      id: "horseboss",
      name: "Pet Shop Owner",
      title: "Mount Merchant",
      race: "human",
      gender: "male",
      age: 32,
      attitude: "peaceful",
      level: 20,
      stats: %{str: 25, int: 25, con: 25, dex: 25},
      skills: %{"training" => 400},
      inventory: [],
      greetings: [
        "Welcome to the Grand Pet Emporium! Finest mounts in the realm!",
        "Looking for a loyal companion? You've come to the right place!",
        "Fine steeds, exotic beasts - all under one roof!",
        "Welcome! A good mount makes all the difference on the road."
      ]
    }
  end

  def greet(player) do
    if Skill.get_level(player, "training") < @training_req do
      {:ok, %{message: "Your training skill is too low (need #{@training_req}). Come back later.", can_buy: false}}
    else
      greeting = Enum.random(["Welcome! Looking for a mount?", "Fine steeds for sale!", "Welcome to the best pet shop in the realm!"])
      {:ok, %{message: greeting, can_buy: true, price: @price, training_req: @training_req}}
    end
  end

  def start_purchase(player) do
    if Skill.get_level(player, "training") < @training_req do
      {:error, "Training skill too low (need #{@training_req})."}
    else
      {:ok, %{step: :choose_species, species_list: species_list(), price: @price}}
    end
  end

  def choose_species(_player, species_key) do
    if species_key in Map.keys(@species) do
      {:ok, %{step: :choose_gender, species: species_key, species_data: @species[species_key]}}
    else
      {:error, "Invalid species. Choose from: #{inspect(Map.keys(@species))}"}
    end
  end

  def choose_gender(_player, gender) do
    gender = String.downcase(gender)
    if gender in ["male", "female", "m", "f"] do
      gender = if gender in ["m", "male"], do: "male", else: "female"
      {:ok, %{step: :choose_id, gender: gender}}
    else
      {:error, "Gender must be 'male' or 'female'."}
    end
  end

  def choose_id(player, id_input) do
    id_input = String.trim(id_input)
    cond do
      String.length(id_input) < 3 or String.length(id_input) > 20 ->
        {:error, "ID must be 3-20 characters."}
      not Regex.match?(~r/^[a-z_]+$/, id_input) ->
        {:error, "ID can only contain lowercase letters and underscores."}
      Player.item_exists?("#{id_input} #{suffix_for_species(player)}") ->
        {:error, "This ID is already taken."}
      true ->
        {:ok, %{step: :choose_name, pet_id: id_input}}
    end
  end

  def choose_name(_player, name_input) do
    name_input = String.trim(name_input)
    cond do
      String.length(name_input) < 2 or String.length(name_input) > 12 ->
        {:error, "Name must be 2-12 characters."}
      not is_chinese?(name_input) ->
        {:error, "Name must contain Chinese characters."}
      true ->
        {:ok, %{step: :choose_desc, pet_name: name_input}}
    end
  end

  def choose_desc(player, desc_input) do
    desc_input = String.trim(desc_input)
    cond do
      String.length(desc_input) > 60 ->
        {:error, "Description too long (max 60 chars)."}
      true ->
        build_pet(player, desc_input)
    end
  end

  # --- Construction ---

  defp build_pet(player, desc) do
    species_key = player.temp[:chosen_species]
    gender = player.temp[:pet_gender]
    id_base = player.temp[:pet_id]
    name = player.temp[:pet_name]
    species = @species[species_key]
    suffix = species.id_suffix
    full_id = "#{id_base} #{suffix}"
    full_name = "#{name}#{species.name}"

    stats = generate_random_stats(species.base_stats)
    mount = create_mount(full_id, full_name, gender, species, stats, desc, player)

    Player.give_mount(player, mount)
    Player.delete_temp(:chosen_species)
    Player.delete_temp(:pet_gender)
    Player.delete_temp(:pet_id)
    Player.delete_temp(:pet_name)

    {:ok, %{mount: mount, message: "Your new #{species.name} #{name}#{species.name} is ready! Use 'whistle #{full_id}' to summon."}}
  end

  defp generate_random_stats(base) do
    Enum.reduce(base, %{}, fn {k, v}, acc ->
      variance = :rand.uniform(20) - 10  # -10 to +10
      Map.put(acc, k, max(1, v + variance))
    end)
  end

  defp create_mount(id, name, gender, species, stats, desc, owner) do
    %{
      id: id,
      name: name,
      type: "mount",
      species: species.name,
      gender: gender,
      unit: species.unit,
      stats: stats,
      description: desc <> "\nIt belongs to #{owner.name}.",
      owner: owner.id,
      owner_name: owner.name,
      summon_id: id,
      rideable: true,
      trained: true
    }
  end

  # --- Helpers ---

  defp species_list do
    Enum.map(@species, fn {key, data} ->
      %{key: key, name: data.name, base_stats: data.base_stats}
    end)
  end

  defp suffix_for_species(player) do
    species_key = player.temp[:chosen_species]
    @species[species_key].id_suffix
  end

  defp is_chinese?(str) do
    # Match any CJK Unified Ideograph (U+4E00..U+9FFF) by codepoint,
    # since PCRE in this Elixir version does not support the \\p{Han} property.
    Enum.any?(String.to_charlist(str), fn cp -> cp in 0x4E00..0x9FFF end)
  end

  def species_info do
    Enum.map(@species, fn {key, data} ->
      %{key: key, name: data.name, unit: data.unit, base_stats: data.base_stats}
    end)
  end
end