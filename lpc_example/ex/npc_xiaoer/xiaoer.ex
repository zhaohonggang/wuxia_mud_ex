defmodule ExKantele.World.Npc.Xiaoer do
  @moduledoc """
  Waiter NPC (Xiaoer) - Restaurant/Inn Service
  Source: lpc_example/npc/npc_xiaoer.c

  Full migration: greeting, accept_object (money/corpse), do_drop (corpse handling),
  do_exchange (points redemption), heart_beat (full-room cleanup).
  Framework requirements in FRAMEWORK_REQUIREMENTS.md.
  """

  alias ExKantele.World.{Player, Item, Room}

  @greetings [
    "Welcome! What would you like to order?",
    "Good to see you! The usual?",
    "Come in, come in! Best food in town!",
    "Hey there! Hungry? Thirsty?"
  ]

  @exchange_items %{
    "blood_bodhi" => %{cost: 5, item: "pill/puti1", name: "Blood Bodhi"},
    "sarira" => %{cost: 5, item: "pill/sheli1", name: "Sarira"},
    "haotian_fruit" => %{cost: 5, item: "pill/linghui1", name: "Haotian Fruit"},
    "bone_strength" => %{cost: 5, item: "gift/con1", name: "Bone Strength Powder"},
    "longevity_paste" => %{cost: 5, item: "gift/dex1", name: "Longevity Paste"},
    "wisdom_pill" => %{cost: 5, item: "gift/int1", name: "Wisdom Pill"},
    "strength_pill" => %{cost: 5, item: "gift/str1", name: "Strength Pill"},
    "rebirth_pill" => %{cost: 50, item: "gift/con3", name: "Rebirth Pill"}
  }

  def init_npc do
    %{
      id: "xiaoer",
      name: "Waiter",
      title: "Inn Waiter",
      race: "human",
      gender: "male",
      age: 30,
      attitude: "peaceful",
      level: 10,
      stats: %{str: 20, int: 20, con: 20, dex: 20},
      skills: %{
        "cooking" => 100,
        "service" => 100
      },
      inventory: [],
      greetings: @greetings
    }
  end

  # --- Interaction Handlers ---

  def greet(_player) do
    greeting = Enum.random(@greetings)
    {:ok, %{message: greeting, speaker: "xiaoer"}}
  end

  def accept_object(player, item) do
    cond do
      Item.is_currency?(item) ->
        handle_money(player, item)

      Item.is_corpse?(item) ->
        handle_corpse(player, item)

      true ->
        {:error, "I don't need this item."}
    end
  end

  def handle_money(player, money) do
    amount = Item.currency_amount(money)
    Player.add_temp(player, "rent_paid", amount)
    {:ok, %{message: "Thanks for the #{amount} coins! Your stay is covered.", money_received: amount}}
  end

  def handle_corpse(_player, corpse) do
    Room.move_object(corpse, "discard_room")
    {:ok, %{message: "Disposed of the corpse.", corpse_disposed: true}}
  end

  def handle_drop(_player, item) do
    if Item.is_corpse?(item) do
      Room.move_object(item, "discard_room")
      {:ok, %{message: "The waiter quickly removes the corpse.", corpse_removed: true}}
    else
      {:error, "You can't leave that here."}
    end
  end

  def exchange(player, item_name) do
    with item_data when not is_nil(item_data) <- @exchange_items[item_name],
         :ok <- check_points(player, item_data.cost) do

      player = Player.add_points(player, -item_data.cost)
      item = Item.create(item_data.item)
      player = Player.give_item(player, item)

      {:ok, %{item: item_data.name, cost: item_data.cost, remaining_points: Player.points(player)}}
    end
  end

  def list_exchange do
    Enum.map(@exchange_items, fn {name, data} ->
      %{name: name, cost: data.cost, item: data.item}
    end)
  end

  def heart_beat do
    Enum.each(Room.get_objects("main_hall"), fn obj ->
      if Player.is_player?(obj) and Player.is_idle?(obj) do
        Room.move_object(obj, "outside_inn")
      end
    end)

    :ok
  end

  # --- Helper Functions ---

  defp check_points(player, cost) do
    if Player.points(player) >= cost do
      :ok
    else
      {:error, "Insufficient points. You have #{Player.points(player)}, need #{cost}."}
    end
  end
end