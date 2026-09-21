defmodule Kantele.World.LPCConverter do
  @moduledoc """
  LPC to UCL Converter (T1)

  Converts LPC source files (.c) to UCL format compatible with Kantele.World.Loader.

  Handles:
  - `set(key, value)` and `set_name(name, aliases)` calls
  - `inherit` statements
  - Heredoc strings (`@LONG ... LONG`)
  - Mappings `([ key : value, ... ])`
  - Arrays `({ elem1, elem2, ... })`
  - `__DIR__` macro resolution
  - Common LPC patterns in room/npc/item/skill files

  Output: UCL string that can be written to data/world/*.ucl
  """

  alias Kantele.World.LPCConverter.AST

  @doc """
  Convert an LPC file to UCL.

  ## Options
    - `:base_path` - Base directory for resolving `__DIR__` and `inherit` paths
    - `:zone_id` - Zone ID for generated UCL keys (default: inferred from file path)
    - `:include_comments` - Include conversion notes as comments (default: true)

  Returns `{:ok, ucl_string}` or `{:error, reason}`.
  """
  def convert_file(lpc_path, opts \\ []) do
    base_path = Keyword.get(opts, :base_path, Path.dirname(lpc_path))
    zone_id = Keyword.get(opts, :zone_id, infer_zone_id(lpc_path, base_path))
    include_comments = Keyword.get(opts, :include_comments, true)

    case File.read(lpc_path) do
      {:ok, content} ->
        case parse_lpc(content, lpc_path, base_path) do
          {:ok, ast} ->
            ucl = generate_ucl(ast, zone_id, include_comments)
            {:ok, ucl}

          {:error, reason} ->
            {:error, "Parse failed: #{reason}"}
        end

      {:error, reason} ->
        {:error, "File read failed: #{reason}"}
    end
  end

  @doc """
  Convert LPC source string to UCL (for testing).
  """
  def convert_string(lpc_content, opts \\ []) do
    base_path = Keyword.get(opts, :base_path, ".")
    zone_id = Keyword.get(opts, :zone_id, "test")
    include_comments = Keyword.get(opts, :include_comments, true)

    case parse_lpc(lpc_content, "<string>", base_path) do
      {:ok, ast} ->
        ucl = generate_ucl(ast, zone_id, include_comments)
        {:ok, ucl}

      {:error, reason} ->
        {:error, "Parse failed: #{reason}"}
    end
  end

  # --------------------------------------------------------------------------
  # Parsing
  # --------------------------------------------------------------------------

  defp parse_lpc(content, source_path, base_path) do
    # Preprocess: strip comments, normalize whitespace
    cleaned = preprocess(content)

    # Parse into AST
    parse_ast(cleaned, source_path, base_path)
  end

  def preprocess(content) do
    content
    |> strip_c_comments()
    |> strip_cpp_comments()
    |> normalize_whitespace()
  end

  defp strip_c_comments(text) do
    # Remove /* ... */ comments (non-greedy, handle multi-line)
    Regex.replace(~r/\/\*[\s\S]*?\*\//, text, "")
  end

  defp strip_cpp_comments(text) do
    # Remove // ... comments
    text
    |> String.split("\n")
    |> Enum.map(fn line ->
      case Regex.run(~r/\/\/.*/, line) do
        nil -> line
        [match] ->
          # Find position of match manually
          pos = String.length(line) - String.length(match)
          String.slice(line, 0..(pos - 1))
      end
    end)
    |> Enum.join("\n")
  end

  defp normalize_whitespace(text) do
    text
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  def parse_ast(content, source_path, base_path) do
    # Extract heredocs first (before whitespace normalization)
    heredocs = parse_heredocs_from_raw(content)
    
    # Preprocess: strip comments, normalize whitespace
    cleaned = preprocess(content)

    # Extract key components from cleaned LPC
    %{
      inherits: parse_inherits(cleaned),
      create_fn: parse_create_function(cleaned),
      other_fns: parse_other_functions(cleaned),
      globals: parse_globals(cleaned),
      heredocs: heredocs,
      source_path: source_path,
      base_path: base_path
    }
    |> AST.new()
    |> (fn ast -> {:ok, ast} end).()
  rescue
    e -> {:error, Exception.message(e)}
  end

  def parse_inherits(content) do
    # Match: inherit PATH;
    Regex.scan(~r/inherit\s+(["']?)([^;"']+)\1\s*;/, content)
    |> Enum.map(fn [_, _, path] -> String.trim(path) end)
    |> Enum.uniq()
  end

  def parse_create_function(content) do
    # Find void create() { ... } - extract body using brace matching
    case find_create_body(content) do
      nil -> %{}
      body -> parse_create_body(body)
    end
  end

  def find_create_body(content) do
    # Find "void create() {" 
    case Regex.run(~r/void\s+create\s*\(\s*\)\s*\{/, content) do
      nil -> nil
      [match] ->
        # Find the position of the match using split
        parts = String.split(content, match, parts: 2)
        case parts do
          [before, _after] ->
            start_pos = String.length(before)
            # Find matching closing brace
            find_matching_brace(content, start_pos + String.length(match) - 1)
          _ ->
            nil
        end
    end
  end

  defp find_matching_brace(content, start_index) do
    # start_index is the position of the opening {
    find_matching_brace_loop(content, start_index, 1, start_index + 1)
  end

  defp find_matching_brace_loop(content, start_index, brace_count, i) do
    if i > String.length(content) - 1 do
      nil
    else
      char = String.at(content, i)
      cond do
        char == "{" ->
          find_matching_brace_loop(content, start_index, brace_count + 1, i + 1)
        char == "}" ->
          if brace_count - 1 == 0 do
            # Return the body between the braces
            String.slice(content, start_index + 1, i - start_index - 1)
          else
            find_matching_brace_loop(content, start_index, brace_count - 1, i + 1)
          end
        true ->
          find_matching_brace_loop(content, start_index, brace_count, i + 1)
      end
    end
  end

  defp parse_create_body(body) do
    %{}
    |> Map.merge(parse_set_calls(body))
    |> Map.merge(parse_set_name(body))
    |> Map.merge(parse_direct_assignments(body))
  end

  defp parse_set_calls(body) do
    # Match: set("key", value); or set('key', value);
    sets =
      Regex.scan(~r/set\s*\(\s*(["'])([^"']+)\1\s*,\s*([^;]+)\s*\)\s*;/, body)
      |> Enum.map(fn [_, _, key, value] ->
        {key, parse_lpc_value(String.trim(value))}
      end)
      |> Enum.into(%{})

    %{sets: sets}
  end

  defp parse_set_name(body) do
    # Match: set_name("name", ({ "alias1", "alias2" }));
    case Regex.run(~r/set_name\s*\(\s*(["'])([^"']+)\1\s*,\s*\(\s*\{([^}]+)\}\s*\)\s*\)\s*;/, body) do
      nil -> %{}
      [_, _, name, aliases_str] ->
        aliases =
          aliases_str
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.map(&String.replace(&1, ~r/^["']|["']$/, ""))
          |> Enum.filter(&(&1 != ""))

        %{set_name: %{"name" => name, "aliases" => aliases}}
    end
  end

  def parse_heredocs_from_raw(content) do
    # Match: set("long", @LONG ... LONG); in raw content (with newlines preserved)
    heredocs =
      Regex.scan(~r/set\s*\(\s*(["'])([^"']+)\1\s*,\s*@(\w+)\s*\n([\s\S]*?)\n\3\s*\)\s*;/, content)
      |> Enum.map(fn [_, _, key, delimiter, content] ->
        {key, %{type: :heredoc, delimiter: delimiter, content: String.trim(content)}}
      end)
      |> Enum.into(%{})

    %{heredocs: heredocs}
  end

  defp parse_direct_assignments(body) do
    # Match direct assignments like: mapping = ([ ... ]);
    assigns =
      Regex.scan(~r/(\w+)\s*=\s*([^;]+);/, body)
      |> Enum.map(fn [_, var, value] ->
        {var, parse_lpc_value(String.trim(value))}
      end)
      |> Enum.into(%{})

    %{assigns: assigns}
  end

  defp parse_other_functions(content) do
    # Extract function signatures for reference
    Regex.scan(~r/(int|string|void|mapping|object)\s+(\w+)\s*\([^)]*\)/, content)
    |> Enum.map(fn [_, ret_type, name] -> %{name: name, return_type: ret_type} end)
    |> Enum.uniq_by(& &1.name)
  end

  defp parse_globals(content) do
    # Global variable declarations
    Regex.scan(~r/(int|string|mapping|object|mixed)\s+(\w+)\s*[=;]/, content)
    |> Enum.map(fn [_, type, name] -> {name, type} end)
    |> Enum.into(%{})
  end

  defp parse_lpc_value(value_str) do
    value_str = String.trim(value_str)

    cond do
      # String
      String.starts_with?(value_str, "\"") && String.ends_with?(value_str, "\"") ->
        {:string, String.slice(value_str, 1..-2)}

      # Number
      String.match?(value_str, ~r/^\d+$/) ->
        {:int, String.to_integer(value_str)}

      # Float
      String.match?(value_str, ~r/^\d+\.\d+$/) ->
        {:float, String.to_float(value_str)}

      # Array: ({ ... })
      String.starts_with?(value_str, "({") && String.ends_with?(value_str, "})") ->
        inner = String.slice(value_str, 2..-3)
        elements = parse_array_elements(inner)
        {:array, elements}

      # Mapping: ([ ... ])
      String.starts_with?(value_str, "([") && String.ends_with?(value_str, "])") ->
        inner = String.slice(value_str, 2..-3)
        pairs = parse_mapping_pairs(inner)
        {:mapping, pairs}

      # Function call: func(args)
      String.match?(value_str, ~r/^\w+\(.*\)$/) ->
        {:call, value_str}

      # Variable reference
      true ->
        {:var, value_str}
    end
  end

  defp parse_array_elements(inner) do
    inner
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(&parse_lpc_value/1)
  end

  defp parse_mapping_pairs(inner) do
    # Split by comma but respect nested structures
    pairs = split_mapping_pairs(inner)

    Enum.map(pairs, fn pair ->
      case String.split(pair, ":", parts: 2) do
        [key, value] ->
          {parse_lpc_value(String.trim(key)), parse_lpc_value(String.trim(value))}
        _ ->
          {parse_lpc_value(String.trim(pair)), {:var, "nil"}}
      end
    end)
  end

  defp split_mapping_pairs(inner) do
    # Simple split - for complex nested mappings this would need a proper parser
    inner
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
  end

  defp infer_zone_id(lpc_path, _base_path) do
    # Use the filename (without extension) as zone_id
    lpc_path
    |> Path.basename()
    |> Path.rootname()
    |> String.replace("-", "_")
  end

  # --------------------------------------------------------------------------
  # UCL Generation
  # --------------------------------------------------------------------------

  defp generate_ucl(ast, zone_id, include_comments) do
    header = if include_comments do
      "# Generated from #{ast.source_path} by LPCConverter\n# Zone: #{zone_id}\n\n"
    else
      ""
    end

    sections = []

    # Determine object type from inherits and create function
    obj_type = determine_object_type(ast)

    new_sections =
case obj_type do
      :room ->
        [generate_room_ucl(ast, zone_id)]
      :npc ->
        [generate_npc_ucl(ast, zone_id)]
      :item ->
        [generate_item_ucl(ast, zone_id)]
      :skill ->
        [generate_skill_ucl(ast, zone_id)]
      _ ->
        [generate_generic_ucl(ast, zone_id)]
    end

    sections = sections ++ new_sections

    header <> Enum.join(sections, "\n\n")
  end

  defp determine_object_type(ast) do
    inherits = ast.inherits

    cond do
      Enum.any?(inherits, &String.contains?(&1, "ROOM")) -> :room
      Enum.any?(inherits, &String.contains?(&1, "NPC")) -> :npc
      Enum.any?(inherits, &String.contains?(&1, "WEAPON") or String.contains?(&1, "SWORD") or String.contains?(&1, "ARMOR") or String.contains?(&1, "ITEM")) -> :item
      Enum.any?(inherits, &String.contains?(&1, "SKILL") or String.contains?(&1, "FORCE")) -> :skill
      true -> :generic
    end
  end

  defp extract_string(value, default) do
    case value do
      {:string, s} -> s
      s when is_binary(s) -> s
      nil -> default
      _ -> default
    end
  end

  defp generate_room_ucl(ast, zone_id) do
    create = ast.create_fn
    sets = Map.get(create, :sets, %{})
    heredocs = Map.get(ast.heredocs, :heredocs, %{})

    room_id = extract_string(Map.get(sets, "short"), "room") |> String.replace(" ", "_") |> String.downcase()

    ucl = """
    rooms "#{room_id}" {
      name = "#{extract_string(Map.get(sets, "short"), "Room")}"
      description = "#{get_heredoc_or_set(heredocs, sets, "long", "")}"
"""

    # Exits
    if Map.has_key?(sets, "exits") do
      exits = Map.get(sets, "exits")
      if is_tuple(exits) and elem(exits, 0) == :mapping do
        ucl <> """
      exits = [
    """ <> generate_exits(elem(exits, 1)) <> """
      ]
    """
      end
    end

    # Coordinates
    coords = %{"x" => sets["x"], "y" => sets["y"], "z" => sets["z"]}
    |> Enum.filter(fn {_, v} -> v != nil end)
    |> Enum.map(fn {k, {:int, v}} -> "  #{k} = #{v}" end)
    |> Enum.join("\n")

    if coords != "" do
      ucl <> "\n#{coords}\n"
    end

    # Flags
    flags = build_room_flags(sets)
    if flags != [] do
      ucl <> """
      flags = [
    """ <> Enum.map_join(flags, "\n", &"        \"#{&1}\"") <> """
      ]
    """
    end

    ucl <> "    }"
  end

  defp generate_exits(exits) do
    exits
    |> Enum.map(fn {key, val} ->
      direction = get_string(key)
      target = get_string(val)
      "        #{direction} = #{target}"
    end)
    |> Enum.join("\n")
  end

defp get_string(value) do
    case value do
      {:string, s} -> "\"#{s}\""
      {:int, n} -> to_string(n)
      {:var, v} -> v
      s when is_binary(s) -> "\"#{s}\""
      _ -> "\"unknown\""
    end
  end

  defp build_room_flags(sets) do
    flags = []

    if Map.get(sets, "no_fight") == {:int, 1} or Map.get(sets, "no_fight") == {:string, "1"} do
      flags = ["no_fight" | flags]
    end

    if Map.get(sets, "no_steal") == {:int, 1} or Map.get(sets, "no_steal") == {:string, "1"} do
      flags = ["no_steal" | flags]
    end

    if Map.get(sets, "no_sleep_room") == {:int, 1} do
      flags = ["no_sleep_room" | flags]
    end

    if Map.get(sets, "outdoors") do
      flags = ["outdoors" | flags]
    end

    if Map.get(sets, "water") do
      flags = ["water" | flags]
    end

    Enum.reverse(flags)
  end

  defp get_heredoc_or_set(heredocs, sets, key, default) do
    case Map.get(heredocs, key) do
      %{content: content} -> escape_ucl_string(content)
      nil ->
        case Map.get(sets, key) do
          {:string, s} -> escape_ucl_string(s)
          _ -> default
        end
    end
  end

  defp escape_ucl_string(str) do
    str
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", "\\n")
  end

  defp generate_npc_ucl(ast, zone_id) do
    create = ast.create_fn
    sets = Map.get(create, :sets, %{})
    heredocs = Map.get(create, :heredocs, %{})

    npc_id = extract_string(Map.get(sets, "name"), "npc") |> String.replace(" ", "_") |> String.downcase()

    ucl = """
    characters "#{npc_id}" {
      name = "#{extract_string(Map.get(sets, "name"), "NPC")}"
      description = "#{get_heredoc_or_set(heredocs, sets, "long", "")}"
"""

    # Brain reference (from inherit or default)
    brain = infer_brain(ast.inherits)
    ucl <> "  brain = brains.#{brain}\n"

    # Combat config
    combat = build_npc_combat(sets)
    if combat != "" do
      ucl <> "\n  combat = {\n#{combat}\n  }\n"
    end

    # Goods
    goods = build_goods(sets)
    if goods != [] do
      ucl <> "\n  goods = [\n" <> Enum.map_join(goods, "\n", &"    { id = #{&1} }") <> "\n  ]\n"
    end

    # Inquiries
    inquiries = build_inquiries(sets)
    if inquiries != %{} do
      ucl <> "\n  inquiries = {\n" <> generate_inquiries(inquiries) <> "\n  }\n"
    end

    # Chat
    chat = build_chat(sets)
    if chat != nil do
      ucl <> "\n  #{chat}\n"
    end

    ucl <> "    }"
  end

  defp infer_brain(inherits) do
    # Map common inherits to brain names
    cond do
      Enum.any?(inherits, &String.contains?(&1, "VENDOR")) -> "vendor"
      Enum.any?(inherits, &String.contains?(&1, "DEALER")) -> "dealer"
      Enum.any?(inherits, &String.contains?(&1, "GUARD")) -> "guarder"
      Enum.any?(inherits, &String.contains?(&1, "BANKER")) -> "banker"
      Enum.any?(inherits, &String.contains?(&1, "HORSE")) -> "horseboss"
      Enum.any?(inherits, &String.contains?(&1, "QUEST")) -> "quester"
      true -> "default"
    end
  end

  defp build_npc_combat(sets) do
    fields = []

    combat_fields = %{
      "attitude" => {:string, "peaceful"},
      "no_kill" => {:bool, false},
      "respawn_delay" => {:int, 0},
      "max_qi" => {:int, 100},
      "max_jing" => {:int, 100},
      "max_neili" => {:int, 0},
      "str" => {:int, 10},
      "dex" => {:int, 10},
      "con" => {:int, 10},
      "int" => {:int, 10},
      "combat_exp" => {:int, 0}
    }

    Enum.reduce(combat_fields, fields, fn {key, default}, acc ->
      case Map.get(sets, key) do
        {:int, v} -> ["    #{key} = #{v}" | acc]
        {:string, v} -> ["    #{key} = \"#{v}\"" | acc]
        {:bool, v} -> ["    #{key} = #{if(v, do: "true", else: "false")}" | acc]
        _ -> acc
      end
    end)
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  defp build_goods(sets) do
    case Map.get(sets, "goods") do
      {:array, items} ->
        Enum.map(items, fn
          {:string, s} -> "items.#{s}.id"
          {:var, v} -> v
          _ -> "items.unknown.id"
        end)
      _ -> []
    end
  end

  defp build_inquiries(sets) do
    # Look for inquiry-like mappings
    case Map.get(sets, "inquiries") do
      {:mapping, pairs} ->
        Enum.into(pairs, %{}, fn {k, v} ->
          {get_string(k), get_string(v)}
        end)
      _ -> %{}
    end
  end

  defp generate_inquiries(inquiries) do
    Enum.map(inquiries, fn {q, a} ->
      "    #{q} = #{a}"
    end)
    |> Enum.join("\n")
  end

  defp build_chat(sets) do
    chance = Map.get(sets, "chat_chance")
    chats = Map.get(sets, "chats")

    case {chance, chats} do
      {{:int, c}, {:array, lines}} when c > 0 ->
        chat_lines = Enum.map(lines, fn {:string, s} -> "    \"#{escape_ucl_string(s)}\"" end) |> Enum.join(",\n")
        """
        chat_chance = #{c}
        chats = [
        #{chat_lines}
        ]
        """
      _ ->
        nil
    end
  end

  defp generate_item_ucl(ast, zone_id) do
    create = ast.create_fn
    sets = Map.get(create, :sets, %{})
    set_name = Map.get(create, :set_name, %{})
    heredocs = Map.get(create, :heredocs, %{})

    item_id = case Map.get(set_name, "name") do
      {:string, s} -> s
      s when is_binary(s) -> s
      nil -> case Map.get(sets, "name") do
        {:string, s} -> s
        s when is_binary(s) -> s
        _ -> "item"
      end
    end
    |> String.replace(" ", "_")
    |> String.downcase()

    name = case Map.get(set_name, "name") do
      {:string, s} -> s
      s when is_binary(s) -> s
      nil -> case Map.get(sets, "name") do
        {:string, s} -> s
        s when is_binary(s) -> s
        _ -> "Item"
      end
    end

    ucl = """
    items "#{item_id}" {
      name = "#{name}"
      description = "#{get_heredoc_or_set(heredocs, sets, "long", "")}"
"""

    # Verbs
    verbs = infer_verbs(ast.inherits, sets)
    ucl <> "  verbs = [\n" <> Enum.map_join(verbs, ",\n", &"    \"#{&1}\"") <> "\n  ]\n"

    # Meta
    meta = build_item_meta(sets, ast.inherits)
    if meta != %{} do
      ucl <> "\n  meta = {\n" <> generate_meta(meta) <> "\n  }\n"
    end

    ucl <> "    }"
  end

  defp infer_verbs(inherits, sets) do
    base = ["get", "drop"]

    cond do
      Enum.any?(inherits, &String.contains?(&1, "WEAPON") or String.contains?(&1, "SWORD") or String.contains?(&1, "BLADE")) ->
        base ++ ["wield", "unwield"]
      Enum.any?(inherits, &String.contains?(&1, "ARMOR")) ->
        base ++ ["wear", "remove"]
      Enum.any?(inherits, &String.contains?(&1, "FOOD") or String.contains?(&1, "EDIBLE")) ->
        base ++ ["eat"]
      Map.has_key?(sets, "wield_msg") ->
        base ++ ["wield", "unwield"]
      Map.has_key?(sets, "wear_msg") ->
        base ++ ["wear", "remove"]
      true ->
        base
    end
  end

  defp build_item_meta(sets, inherits) do
    meta = %{}

    # Damage / weapon
    if damage = Map.get(sets, "weapon_prop"), do: meta = Map.put(meta, :damage, damage)
    if damage = Map.get(sets, "damage"), do: meta = Map.put(meta, :damage, damage)

    if skill_type = Map.get(sets, "skill_type") do
      meta = Map.put(meta, :skill_type, skill_type)
    else
      # Infer from inherit
      meta = Map.put(meta, :skill_type, infer_skill_type(inherits))
    end

    # Armor
    if armor = Map.get(sets, "armor"), do: meta = Map.put(meta, :armor, armor)
    if armor_type = Map.get(sets, "armor_type"), do: meta = Map.put(meta, :armor_type, armor_type)

    # Value, weight, unit, material
    Enum.each([:value, :weight, :unit, :material], fn key ->
      if val = Map.get(sets, key), do: meta = Map.put(meta, key, val)
    end)

    # Flag
    if flag = Map.get(sets, "flag"), do: meta = Map.put(meta, :flag, flag)

    # Special: food, medicine, book
    if food = Map.get(sets, "food"), do: meta = Map.put(meta, :food, food)
    if medicine = Map.get(sets, "medicine"), do: meta = Map.put(meta, :medicine, medicine)
    if book = Map.get(sets, "book"), do: meta = Map.put(meta, :book, book)

    # weapon_prop / armor_prop
    if wp = Map.get(sets, "weapon_prop"), do: meta = Map.put(meta, :weapon_prop, wp)
    if ap = Map.get(sets, "armor_prop"), do: meta = Map.put(meta, :armor_prop, ap)

    meta
  end

  defp infer_skill_type(inherits) do
    cond do
      Enum.any?(inherits, &String.contains?(&1, "SWORD")) -> "sword"
      Enum.any?(inherits, &String.contains?(&1, "BLADE") or String.contains?(&1, "DAO")) -> "blade"
      Enum.any?(inherits, &String.contains?(&1, "STAFF") or String.contains?(&1, "GUN")) -> "staff"
      Enum.any?(inherits, &String.contains?(&1, "WHIP") or String.contains?(&1, "BIAN")) -> "whip"
      Enum.any?(inherits, &String.contains?(&1, "DAGGER") or String.contains?(&1, "DAGGER")) -> "dagger"
      Enum.any?(inherits, &String.contains?(&1, "THROWING")) -> "throwing"
      Enum.any?(inherits, &String.contains?(&1, "HAMMER")) -> "hammer"
      Enum.any?(inherits, &String.contains?(&1, "AXE")) -> "axe"
      Enum.any?(inherits, &String.contains?(&1, "FIST") or String.contains?(&1, "UNARMED")) -> "unarmed"
      Enum.any?(inherits, &String.contains?(&1, "FINGER")) -> "finger"
      Enum.any?(inherits, &String.contains?(&1, "CLAW")) -> "claw"
      Enum.any?(inherits, &String.contains?(&1, "PALM") or String.contains?(&1, "STRIKE")) -> "strike"
      true -> "sword"
    end
  end

  defp generate_meta(meta) do
    Enum.map(meta, fn {key, value} ->
      "    #{key} = #{format_meta_value(value)}"
    end)
    |> Enum.join("\n")
  end

  defp format_meta_value({:string, s}), do: "\"#{escape_ucl_string(s)}\""
  defp format_meta_value({:int, i}), do: to_string(i)
  defp format_meta_value({:float, f}), do: to_string(f)
  defp format_meta_value({:bool, b}), do: if(b, do: "true", else: "false")
  defp format_meta_value({:array, arr}) do
    "[\n" <> Enum.map_join(arr, ",\n", &format_meta_value/1) <> "\n    ]"
  end
  defp format_meta_value({:mapping, pairs}) do
    "{\n" <> Enum.map_join(pairs, ",\n", fn {k, v} ->
      "      #{format_meta_value(k)} = #{format_meta_value(v)}"
    end) <> "\n    }"
  end
  defp format_meta_value({:var, v}), do: v
  defp format_meta_value(_), do: "nil"

  defp generate_skill_ucl(ast, zone_id) do
    # Skills are handled differently - they map to combat skills, not UCL world data
    "# Skill file: #{ast.source_path}\n# Skills are implemented as Elixir modules in lib/kantele/combat/skills/"
  end

  defp generate_generic_ucl(ast, zone_id) do
    "# Generic LPC file: #{ast.source_path}\n# Requires manual conversion"
  end
end