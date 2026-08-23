defmodule Kantele.World.Loader do
  @moduledoc """
  Load the world from data files
  """

  alias Kalevala.Character
  alias Kalevala.World.Item
  alias Kalevala.World.Room.Feature
  alias Kantele.World.Room
  alias Kantele.World.Zone

  @paths %{
    brains_path: "data/brains",
    help_path: "data/help",
    verbs_path: "data/verbs.ucl",
    world_path: "data/world"
  }

  @doc """
  Load zone files into Kalevala structs
  """
  def load(paths \\ %{}) do
    paths = Map.merge(@paths, paths)

    world_data = load_folder(paths.world_path, ".ucl", &merge_world_data/1)
    brain_data = Kantele.Brain.load_all(paths.brains_path)

    verbs = parse_verbs(Elias.parse(File.read!(paths.verbs_path)))

    context = %{
      verbs: verbs,
      brains: brain_data
    }

    zones = Enum.map(world_data, &parse_zone(&1, context))

    zones
    |> Enum.map(&parse_exits(&1, world_data, zones))
    |> Enum.map(&parse_characters(&1, world_data, zones))
    |> Enum.map(&parse_items(&1, world_data, zones))
    |> Enum.map(&zone_items_to_list/1)
    |> Enum.map(&zone_rooms_to_list/1)
    |> Enum.map(&generate_minimap/1)
    |> parse_world()
  end

  defp load_folder(path, file_extension, merge_fun) do
    File.ls!(path)
    |> Enum.filter(fn file ->
      String.ends_with?(file, file_extension)
    end)
    |> Enum.map(fn file ->
      File.read!(Path.join(path, file))
    end)
    |> Enum.map(&Elias.parse/1)
    |> Enum.flat_map(merge_fun)
    |> Enum.into(%{})
  end

  defp merge_world_data(zone_data) do
    [key] = Map.keys(zone_data.zones)
    [{to_string(key), zone_data}]
  end

  defp zone_items_to_list(zone) do
    items = Map.values(zone.items)
    %{zone | items: items}
  end

  defp zone_rooms_to_list(zone) do
    rooms = Map.values(zone.rooms)
    %{zone | rooms: rooms}
  end

  @doc """
  Load help files
  """
  def load_help(path \\ @paths.help_path) do
    File.ls!(path)
    |> Enum.map(fn file ->
      File.read!(Path.join(path, file))
    end)
    |> Enum.map(fn text ->
      [ucl, content] = String.split(text, "---")

      help_topic =
        ucl
        |> Elias.parse()
        |> Map.put(:content, String.trim(content))

      struct(Kalevala.Help.HelpTopic, help_topic)
    end)
  end

  @doc """
  Parse verb data into structs
  """
  def parse_verbs(%{verbs: verbs}) do
    verbs
    |> Enum.map(fn {key, verb} ->
      {key, Map.put(verb, :key, key)}
    end)
    |> Enum.map(fn {key, verb} ->
      conditions = struct(Kalevala.Verb.Conditions, verb.conditions)
      {key, Map.put(verb, :conditions, conditions)}
    end)
    |> Enum.map(fn {key, verb} ->
      {key, struct(Kalevala.Verb, verb)}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Parse a zone

  Loads basic data and rooms
  """
  def parse_zone({key, zone_data}, context) do
    zone = %Zone{}
    seed? = Map.get(zone_data, :seed, "true") == "true"

    name = get_in(zone_data.zones, [String.to_atom(key), :name])
    zone = %{zone | id: to_string(key), name: name, seed?: seed?}

    rooms = Map.get(zone_data, :rooms, [])

    rooms =
      Enum.into(rooms, %{}, fn {key, room_data} ->
        parse_room(zone, key, room_data, zone_data)
      end)

    characters = Map.get(zone_data, :characters, [])

    characters =
      Enum.into(characters, %{}, fn {key, character_data} ->
        parse_character(zone, key, character_data, context.brains)
      end)

    items = Map.get(zone_data, :items, [])

    items =
      Enum.into(items, %{}, fn {key, item_data} ->
        parse_item(zone, key, item_data, context.verbs)
      end)

    %{zone | rooms: rooms, characters: characters, items: items}
  end

  @doc """
  Parse room data

  ID is the zone's id concatenated with the room's key
  """
  def parse_room(zone, key, room_data, zone_data) do
    room = %Room{
      id: "#{zone.id}:#{key}",
      key: to_string(key),
      zone_id: zone.id,
      name: room_data.name,
      description: room_data.description,
      map_color: Map.get(room_data, :map_color),
      map_icon: Map.get(room_data, :map_icon),
      x: room_data.x,
      y: room_data.y,
      z: room_data.z,
      features: parse_features(room_data, zone_data)
    }

    {key, room}
  end

  def parse_features(%{features: features}, zone_data) when is_list(features) do
    Enum.map(features, fn feature ->
      parse_feature(feature, zone_data)
    end)
  end

  def parse_features(_room, _zone_data), do: []

  defp parse_feature(%{ref: "features." <> ref}, zone_data) do
    feature = Map.get(zone_data.features, String.to_atom(ref))
    parse_feature(feature, zone_data)
  end

  defp parse_feature(feature, _zone_data) do
    %Feature{
      id: feature.keyword,
      keyword: feature.keyword,
      short_description: feature.short,
      description: feature.long
    }
  end

  @doc """
  Parse character data

  ID is the zone's id concatenated with the character's key

  支持可选的 `combat {}` 块描述武侠战斗属性：

      characters "heihu" {
        name = "黑虎"
        combat = {
          attitude = "aggressive"
          max_qi = 900
          str = 30
          combat_exp = 8000
          skills = { unarmed = 80, dodge = 70 }
          map_skill = { sword = "liuxin-jian" }
          apply = { attack = 45, damage = 35, armor = 20 }
        }
      }
  """
  def parse_character(zone, key, character_data, brains) do
    character = %Character{
      id: "#{zone.id}:#{key}",
      name: character_data.name,
      description: character_data.description,
      brain: Kantele.Brain.process(Map.get(character_data, :brain), brains),
      meta: %Kantele.Character.NonPlayerMeta{
        zone_id: zone.id,
        initial_events: parse_initial_events(character_data),
        vitals: npc_vitals(Map.get(character_data, :combat)),
        stats: npc_stats(Map.get(character_data, :combat)),
        combat_config: npc_combat_config(Map.get(character_data, :combat)),
        combat: Kantele.Character.Combat.new()
      }
    }

    character = attach_npc_applies(character, Map.get(character_data, :combat))

    {key, character}
  end

  defp npc_vitals(nil), do: Kantele.Character.Vitals.new()

  defp npc_vitals(combat) do
    base = Kantele.Character.Vitals.new()

    %Kantele.Character.Vitals{
      qi: Map.get(combat, :max_qi, base.qi),
      max_qi: Map.get(combat, :max_qi, base.max_qi),
      base_qi: Map.get(combat, :max_qi, base.max_qi),
      jing: Map.get(combat, :max_jing, base.jing),
      max_jing: Map.get(combat, :max_jing, base.max_jing),
      base_jing: Map.get(combat, :max_jing, base.max_jing),
      neili: Map.get(combat, :max_neili, base.neili),
      max_neili: Map.get(combat, :max_neili, base.max_neili),
      base_neili: Map.get(combat, :max_neili, base.max_neili)
    }
  end

  defp npc_stats(nil), do: Kantele.Character.Stats.new()

  defp npc_stats(combat) do
    %Kantele.Character.Stats{
      str: Map.get(combat, :str, 20),
      dex: Map.get(combat, :dex, 20),
      con: Map.get(combat, :con, 20),
      int: Map.get(combat, :int, 20),
      combat_exp: Map.get(combat, :combat_exp, 0),
      potential: Map.get(combat, :potential, 0),
      skills: skill_keys(Map.get(combat, :skills, %{})),
      mapped: skill_keys(Map.get(combat, :map_skill, %{})),
      performs: MapSet.new()
    }
  end

  # UCL 键名不支持横线，约定用下划线书写（liuxin_jian -> liuxin-jian）
  defp skill_keys(map) do
    Enum.into(map, %{}, fn {key, value} ->
      {String.replace(to_string(key), "_", "-"), value}
    end)
  end

  defp npc_combat_config(combat) when combat != nil do
    %Kantele.Character.NPCConfig{
      attitude: Map.get(combat, :attitude),
      no_kill: Map.get(combat, :no_kill) in [true, "true"],
      spawn_room_id: nil,
      apply: Kantele.Character.Combat.new().temp
      |> Map.merge(stringify_apply(Map.get(combat, :apply, %{})))
    }
  end

  defp npc_combat_config(_), do: Kantele.Character.NPCConfig.new()

  defp attach_npc_applies(character, combat) when combat != nil do
    apply = stringify_apply(Map.get(combat, :apply, %{}))

    # 空手攻击读取 unarmed_damage：未单独配置时沿用 damage（LPC NPC 惯例）
    apply =
      case Map.get(apply, :damage) do
        nil -> apply
        dmg -> Map.put_new(apply, :unarmed_damage, dmg)
      end

    combat_state = Kantele.Character.Combat.apply_temp(character.meta.combat, apply)
    meta = Map.put(character.meta, :combat, combat_state)

    %{character | meta: meta}
  end

  defp attach_npc_applies(character, _), do: character

  defp stringify_map(map) do
    Enum.into(map, %{}, fn {key, value} -> {to_string(key), value} end)
  end

  defp stringify_apply(apply) do
    apply
    |> stringify_map()
    |> Enum.into(%{}, fn {key, value} ->
      {String.to_atom(key), value}
    end)
  end

  defp parse_initial_events(%{initial_events: initial_events}) do
    Enum.map(initial_events, fn initial_event ->
      %Kantele.Character.InitialEvent{
        data: initial_event.data,
        delay: initial_event.delay,
        topic: initial_event.topic
      }
    end)
  end

  defp parse_initial_events(_), do: []

  @doc """
  Parse item data

  ID is the zone's id concatenated with the item's key

  支持可选的 `meta = {}` 块描述战斗属性（damage/skill_type/armor/value）
  """
  def parse_item(zone, key, item_data, verbs) do
    item_verbs =
      item_data.verbs
      |> Enum.map(&String.to_atom/1)
      |> Enum.map(fn verb ->
        Map.get(verbs, verb)
      end)

    item = %Item{
      id: "#{zone.id}:#{key}",
      name: item_data.name,
      description: item_data.description,
      verbs: item_verbs,
      callback_module: Kantele.World.Item,
      meta: parse_item_meta(Map.get(item_data, :meta))
    }

    {key, item}
  end

  defp parse_item_meta(nil), do: %Kantele.World.Item.Meta{}

  defp parse_item_meta(meta) do
    %Kantele.World.Item.Meta{
      damage: Map.get(meta, :damage),
      skill_type: Map.get(meta, :skill_type),
      armor: Map.get(meta, :armor),
      value: Map.get(meta, :value)
    }
  end

  @doc """
  Parse exits for zones

  Dereferences the exit exit_names, creates structs for each exit_name,
  and attaches them to the matching room.
  """
  def parse_exits(zone, data, zones) do
    zone_data = Map.get(data, zone.id)

    room_exits = Map.get(zone_data, :room_exits, [])

    exits =
      Enum.flat_map(room_exits, fn {_key, room_exit} ->
        room_exit =
          Enum.into(room_exit, %{}, fn {key, value} ->
            {key, dereference(zones, zone, value)}
          end)

        room_id = room_exit.room_id
        room_exit = Map.delete(room_exit, :room_id)

        Enum.map(room_exit, fn {key, value} ->
          %Kalevala.World.Exit{
            id: "#{room_id}:#{key}",
            exit_name: to_string(key),
            start_room_id: room_id,
            end_room_id: value
          }
        end)
      end)

    Enum.reduce(exits, zone, fn exit, zone ->
      {room_key, room} =
        Enum.find(zone.rooms, fn {_key, room} ->
          room.id == exit.start_room_id
        end)

      room = %{room | exits: [exit | room.exits]}

      rooms = Map.put(zone.rooms, room_key, room)
      %{zone | rooms: rooms}
    end)
  end

  @doc """
  Parse characters for zones

  Dereferences the world characters, creates structs and attachs them to the
  matching room.
  """
  def parse_characters(zone, data, zones) do
    zone_data = Map.get(data, zone.id)

    room_characters = Map.get(zone_data, :room_characters, [])

    characters =
      Enum.flat_map(room_characters, fn {_key, room_character} ->
        room_id = dereference(zones, zone, room_character.room_id)

        room_character.characters
        |> Enum.with_index()
        |> Enum.map(fn {character_data, index} ->
          character_id = dereference(zones, zone, character_data.id)

          {_key, character} = Enum.find(zone.characters, &match_character(&1, character_id))

          meta = character.meta
          combat_config = Map.get(meta, :combat_config)

          combat_config =
            case combat_config do
              %Kantele.Character.NPCConfig{} ->
                %{combat_config | spawn_room_id: room_id}

              _ ->
                combat_config
            end

          meta = %{meta | combat_config: combat_config}

          %Character{
            character
            | id: "#{room_id}:#{character.id}:#{index}",
              name: Map.get(character_data, :name, character.name),
              room_id: room_id,
              meta: meta
          }
        end)
      end)

    Enum.reduce(characters, zone, fn character, zone ->
      {room_key, room} =
        Enum.find(zone.rooms, fn {_key, room} ->
          room.id == character.room_id
        end)

      characters = Map.get(room, :characters, [])
      character = %{character | id: Character.generate_id()}
      room = Map.put(room, :characters, [character | characters])

      rooms = Map.put(zone.rooms, room_key, room)
      %{zone | rooms: rooms}
    end)
  end

  defp match_character({_key, character}, character_id), do: character.id == character_id

  @doc """
  Parse items for zones

  Dereferences the world items, creates structs and attachs them to the
  matching room.
  """
  def parse_items(zone, data, zones) do
    zone_data = Map.get(data, zone.id)

    room_items = Map.get(zone_data, :room_items, [])

    Enum.reduce(room_items, zone, fn {_key, room_item}, zone ->
      room_id = dereference(zones, zone, room_item.room_id)

      Enum.reduce(room_item.items, zone, fn item_data, zone ->
        item_id = dereference(zones, zone, item_data.id)
        parse_room_item(zone, room_id, item_id)
      end)
    end)
  end

  defp parse_room_item(zone, room_id, item_id) do
    instance = %Item.Instance{
      id: Item.Instance.generate_id(),
      item_id: item_id,
      created_at: DateTime.utc_now()
    }

    {room_key, room} =
      Enum.find(zone.rooms, fn {_key, room} ->
        room.id == room_id
      end)

    item_instances = Map.get(room, :item_instances, [])
    room = Map.put(room, :item_instances, [instance | item_instances])

    rooms = Map.put(zone.rooms, room_key, room)
    %{zone | rooms: rooms}
  end

  @doc """
  Strip a zone of extra information that Kalevala doesn't care about
  """
  def strip_zone(zone) do
    zone
    |> Map.put(:characters, [])
    |> Map.put(:items, [])
    |> Map.put(:rooms, [])
  end

  @doc """
  Dereference a variable to it's value

  If a known key is found, use the current zone
  """
  def dereference(zones, zone, reference) do
    [key | reference] = String.split(reference, ".")

    case key in ["characters", "rooms", "items"] do
      true ->
        zone
        |> flatten_characters()
        |> flatten_items()
        |> flatten_rooms()
        |> dereference([key | reference])

      false ->
        zone =
          Enum.find(zones, fn z ->
            z.id == key
          end)

        zone
        |> flatten_characters()
        |> flatten_items()
        |> flatten_rooms()
        |> dereference(reference)
    end
  end

  defp flatten_characters(zone) do
    characters = Map.values(zone.characters)
    Map.put(zone, :characters, characters)
  end

  defp flatten_items(zone) do
    items = Map.values(zone.items)
    Map.put(zone, :items, items)
  end

  defp flatten_rooms(zone) do
    rooms = Map.values(zone.rooms)
    Map.put(zone, :rooms, rooms)
  end

  @doc """
  Convert zones into a world struct
  """
  def parse_world(zones) do
    world = %Kantele.World{
      zones: zones
    }

    world
    |> split_out_rooms()
    |> split_out_characters()
    |> split_out_items()
  end

  defp split_out_rooms(world) do
    Enum.reduce(world.zones, world, fn zone, world ->
      rooms =
        Enum.map(zone.rooms, fn room ->
          Map.delete(room, :characters)
        end)

      Map.put(world, :rooms, rooms ++ world.rooms)
    end)
  end

  defp split_out_characters(world) do
    Enum.reduce(world.zones, world, fn zone, world ->
      characters =
        Enum.flat_map(zone.rooms, fn room ->
          Map.get(room, :characters, [])
        end)

      Map.put(world, :characters, characters ++ world.characters)
    end)
  end

  defp split_out_items(world) do
    Enum.reduce(world.zones, world, fn zone, world ->
      Map.put(world, :items, zone.items ++ world.items)
    end)
  end

  def generate_minimap(zone) do
    mini_map = %Kantele.MiniMap{id: zone.id}

    cells =
      Enum.map(zone.rooms, fn room ->
        %Kantele.MiniMap.Cell{
          id: room.id,
          map_color: room.map_color,
          map_icon: room.map_icon,
          name: room.name,
          x: room.x,
          y: room.y,
          z: room.z,
          connections: %Kantele.MiniMap.Connections{
            north: exit_id(room.exits, :north),
            south: exit_id(room.exits, :south),
            east: exit_id(room.exits, :east),
            west: exit_id(room.exits, :west),
            up: exit_id(room.exits, :up),
            down: exit_id(room.exits, :down)
          }
        }
      end)

    mini_map =
      Enum.reduce(cells, mini_map, fn cell, mini_map ->
        cells = Map.put(mini_map.cells, {cell.x, cell.y, cell.z}, cell)
        %{mini_map | cells: cells}
      end)

    %{zone | mini_map: mini_map}
  end

  defp exit_id(exits, direction) do
    room_exit =
      Enum.find(exits, fn room_exit ->
        room_exit.exit_name == to_string(direction)
      end)

    case room_exit != nil do
      true ->
        room_exit.end_room_id

      false ->
        nil
    end
  end

  @doc """
  Dereference a variable for a specific zone
  """
  def dereference(zone, reference) when is_list(reference) do
    case reference do
      ["characters" | character] ->
        [character_name, character_key] = character

        zone.characters
        |> find_character(zone, character_name)
        |> Map.get(String.to_atom(character_key))

      ["items" | item] ->
        [item_name, item_key] = item

        zone.items
        |> find_item(zone, item_name)
        |> Map.get(String.to_atom(item_key))

      ["rooms" | room] ->
        [room_name, room_key] = room

        zone.rooms
        |> find_room(zone, room_name)
        |> Map.get(String.to_atom(room_key))
    end
  end

  defp find_character(characters, zone, character_name) do
    Enum.find(characters, fn character ->
      character.id == "#{zone.id}:#{character_name}"
    end)
  end

  defp find_item(items, zone, item_name) do
    Enum.find(items, fn item ->
      item.id == "#{zone.id}:#{item_name}"
    end)
  end

  defp find_room(rooms, zone, room_name) do
    Enum.find(rooms, fn room ->
      room.id == "#{zone.id}:#{room_name}"
    end)
  end
end
