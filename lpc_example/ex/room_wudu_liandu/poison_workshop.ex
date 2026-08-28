defmodule ExKantele.World.Room.WuduLiandu do
  @moduledoc """
  Poison Crafting Room (Five Poisons Sect)
  Source: lpc_example/room/room_wudu_liandu.c

  Full migration: 6 poison recipes with ingredient checks, timed callback, skill-based success.
  Framework requirements in FRAMEWORK_REQUIREMENTS.md.
  """

  alias ExKantele.World.{Player, Item, Skill}

  @recipes %{
    "heding hong" => %{name: "Crane Top Red", ingredients: ["du nang", "shexin zi", "qianri zui"], skill_req: 60, product: "hedinghong", duration: 15, level_bonus: 0},
    "furou gao" => %{name: "Rotting Flesh Paste", ingredients: ["du nang", "fugu cao", "chuanxin lian"], skill_req: 60, product: "furougao", duration: 15, level_bonus: 0},
    "kongque dan" => %{name: "Peacock Gall", ingredients: ["du nang", "fugu cao", "qianri zui"], skill_req: 60, product: "kongquedan", duration: 15, level_bonus: 0},
    "chixie fen" => %{name: "Scorpion Powder", ingredients: ["du nang", "shexin zi", "duanchang cao"], skill_req: 60, product: "chixiefen", duration: 15, level_bonus: 0},
    "duanchang san" => %{name: "Intestine Breaking Powder", ingredients: ["du nang", "duanchang cao", "chuanxin lian"], skill_req: 60, product: "duanchangsan", duration: 15, level_bonus: 0},
    "wusheng san" => %{name: "Five Saints Powder", ingredients: ["du nang", "heding hong", "duanchang san", "furou gao", "chixie fen", "kongque dan", "jinshe duye"], skill_req: 60, product: "wushengsan", duration: 25, level_bonus: 20}
  }

  @min_skill 60
  @min_jing 80
  @min_qi 80
  @base_time_min 15
  @base_time_max 15
  @failure_roll_max 3

  def init_room do
    %{
      id: "liandu_shi",
      name: "Poison Crafting Room",
      short: "Poison Lab",
      description: "Five Poisons Sect poison crafting room. Contains alchemy furnace and tools.",
      exits: %{"north" => "nanyuan"},
      no_fight: true,
      npcs: ["daoren"]
    }
  end

  def start_crafting(player, recipe_name) do
    with :ok <- check_faction(player),
         :ok <- check_not_crafting(player),
         :ok <- check_not_busy(player),
         :ok <- check_skill_level(player),
         :ok <- check_vitals(player),
         recipe when not is_nil(recipe) <- get_recipe(recipe_name),
         :ok <- check_ingredients(player, recipe) do

      consume_ingredients(player, recipe)
      Player.put_temp(player, "liandu/recipe", recipe.product)
      Player.put_temp(player, "liandu/level_bonus", recipe.level_bonus)
      Player.put_temp(player, "liandu/duration", recipe.duration)

      time = @base_time_min + :rand.uniform(@base_time_max)
      Player.start_busy(player, div(time, 2) + 1)
      # Framework should provide: schedule_callback(:liandu_callback, time * 1000, player)
      {:ok, %{message: "You start crafting #{recipe.name}. It will take #{time} seconds.", time: time}}
    end
  end

  def liandu_callback(player) do
    if Player.get_temp(player, "liandu/recipe") == nil do
      :ok
    else
      if Player.environment_id(player) != "liandu_shi" do
        Player.delete_temp(player, "liandu/recipe")
        :ok
      else
        do_liandu_success(player)
      end
    end
  end

  defp do_liandu_success(player) do
    Player.receive_damage(player, "jing", 50 + :rand.uniform(30))
    Player.receive_damage(player, "qi", 50 + :rand.uniform(30))

    skill = Skill.get_level(player, "wudu-qishu") || 0
    lvl = div(Skill.get_level(player, "poison") || 0, 2) + skill + 10

    recipe_key = Player.get_temp(player, "liandu/recipe")
    level_bonus = Player.get_temp(player, "liandu/level_bonus") || 0

    if :rand.uniform(skill) < 50 and :rand.uniform(@failure_roll_max) == 1 do
      Player.delete_temp(player, "liandu/recipe")
      {:ok, %{message: "Crafting failed! Foul smell rises from the furnace."}}
    else
      product = create_poison(recipe_key, lvl + level_bonus, Player.get_temp(player, "liandu/duration"), player.id)
      Player.give_item(player, product)
      Player.delete_temp(player, "liandu/recipe")

      exp = 300 + :rand.uniform(300)
      pot_gain = 100 + :rand.uniform(200)
      sco = 100 + :rand.uniform(100)

      Player.add_exp(player, exp)
      Player.add_score(player, sco)
      pot_gain = if Player.potential(player) > Player.potential_limit(player) do
        1
      else
        pot_gain
      end
      Player.improve_potential(player, pot_gain)

      Skill.improve(player, "poison", 50 + Player.int(player))
      if Skill.can_improve?(player, "wudu-qishu") do
        Skill.improve(player, "wudu-qishu", 50 + Player.int(player))
      end

      {:ok, %{
        message: "Crafting successful! You obtained #{product.name}.",
        product: product.name,
        exp: exp,
        pot: pot_gain,
        score: sco
      }}
    end
  end

  defp check_faction(player) do
    if Player.faction(player) == "Five Poisons Sect" do
      :ok
    else
      {:error, "You don't know how to start."}
    end
  end

  defp check_not_crafting(player) do
    if Player.get_temp(player, "liandu/recipe") do
      {:error, "You are already crafting. Don't get distracted."}
    else
      :ok
    end
  end

  defp check_not_busy(player) do
    if Player.busy?(player) do
      {:error, "You are busy right now."}
    else
      :ok
    end
  end

  defp check_skill_level(player) do
    if Skill.get_level(player, "wudu-qishu") >= @min_skill do
      :ok
    else
      {:error, "Your Five Poisons Art is not proficient enough."}
    end
  end

  defp check_vitals(player) do
    if Player.jing(player) >= @min_jing and Player.qi(player) >= @min_qi do
      :ok
    else
      {:error, "Your mental/physical condition is poor."}
    end
  end

  defp get_recipe(name) do
    @recipes[name]
  end

  defp check_ingredients(player, recipe) do
    missing = Enum.find(recipe.ingredients, fn ing -> not Item.has?(player, ing) end)
    case missing do
      nil -> :ok
      ing -> {:error, "Missing ingredient: #{ing}."}
    end
  end

  defp consume_ingredients(player, recipe) do
    Enum.each(recipe.ingredients, fn ing ->
      Item.take(player, ing) |> Item.destroy()
    end)
  end

  defp create_poison(name, level, duration, owner_id) do
    %{
      id: name,
      name: poison_name(name),
      type: "poison",
      poison: %{
        level: level,
        id: owner_id,
        name: poison_chinese_name(name),
        duration: duration
      }
    }
  end

  defp poison_name("hedinghong"), do: "Heding Hong"
  defp poison_name("furougao"), do: "Furou Gao"
  defp poison_name("kongquedan"), do: "Kongque Dan"
  defp poison_name("chixiefen"), do: "Chixie Fen"
  defp poison_name("duanchangsan"), do: "Duanchang San"
  defp poison_name("wushengsan"), do: "Wusheng San"

  defp poison_chinese_name("hedinghong"), do: "Crane Top Red Poison"
  defp poison_chinese_name("furougao"), do: "Rotting Flesh Paste Poison"
  defp poison_chinese_name("kongquedan"), do: "Peacock Gall Poison"
  defp poison_chinese_name("chixiefen"), do: "Scorpion Powder Poison"
  defp poison_chinese_name("duanchangsan"), do: "Intestine Breaking Powder Poison"
  defp poison_chinese_name("wushengsan"), do: "Five Saints Powder Poison"
end