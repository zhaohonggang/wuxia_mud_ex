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
    # Extract heredocs and create body from RAW content (before whitespace normalization)
    heredocs = parse_heredocs_from_raw(content)
    create_body = extract_create_body(content)

    # Preprocess: strip comments, normalize whitespace
    cleaned = preprocess(content)

    # Parse into AST
    parse_ast(cleaned, source_path, base_path, heredocs, create_body)
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
    heredocs = parse_heredocs_from_raw(content)
    create_body = extract_create_body(content)
    build_ast(content, source_path, base_path, heredocs, create_body)
  end

  def parse_ast(content, source_path, base_path, heredocs, create_body) do
    build_ast(content, source_path, base_path, heredocs, create_body)
  end

  defp build_ast(content, source_path, base_path, heredocs, create_body) do
    # Extract key components from cleaned LPC
    %{
      inherits: parse_inherits(content),
      create_fn: parse_create_function(content, create_body),
      other_fns: parse_other_functions(content),
      globals: parse_globals(content),
      heredocs: heredocs,
      source_path: source_path,
      base_path: base_path
    }
    |> AST.new()
    |> (fn ast -> {:ok, ast} end).()
  rescue
    e -> {:error, Exception.message(e)}
  end

  def extract_create_body(content) do
    # Find void create() { ... } and extract the body
    case Regex.run(~r/void\s+create\s*\(\s*\)\s*\{/, content) do
      nil -> ""
      [match] ->
        parts = String.split(content, match, parts: 2)
        case parts do
          [before, _rest] ->
            open_brace_pos = String.length(before) + String.length(match) - 1
            find_matching_brace(content, open_brace_pos)
          _ ->
            ""
        end
    end
  end

  def parse_inherits(content) do
    # Match: inherit PATH;
    Regex.scan(~r/inherit\s+(["']?)([^;"']+)\1\s*;/, content)
    |> Enum.map(fn [_, _, path] -> String.trim(path) end)
    |> Enum.uniq()
  end

  def parse_create_function(content, create_body \\ nil) do
    body = create_body || find_create_body(content)
    case body do
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
        char == "\"" ->
          case find_quote_end(content, i + 1) do
            nil -> nil
            new_i -> find_matching_brace_loop(content, start_index, brace_count, new_i)
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
    # Match set("key", value); or set('key', value); - handle multi-line values
    # Use regex with [\s\S]*? to match across newlines
    sets =
      Regex.scan(~r/set\s*\(\s*(["'])([^"']+)\1\s*,\s*([\s\S]*?)\s*\)\s*;/m, body)
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
      # String (possibly concatenated "a" "b")
      String.starts_with?(value_str, "\"") && String.ends_with?(value_str, "\"") ->
        {:string, parse_lpc_string(value_str)}

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

  defp parse_lpc_string(value_str) do
    # Handle "a" "b" concatenation. value_str starts and ends with a quote.
    # Extract each "..." segment (respecting \" escapes) and join them.
    segments =
      Regex.scan(~r/"((?:\\.|[^"\\])*)"/, value_str)
      |> Enum.map(fn [_, seg] -> seg end)

    Enum.join(segments)
  end

  defp skip_quoted_string(body, index) do
    if index >= String.length(body) do
      nil
    else
      find_quote_end(body, index)
    end
  end

  defp find_quote_end(body, i) do
    if i >= String.length(body) do
      nil
    else
      char = String.at(body, i)
      cond do
        char == "\\" -> find_quote_end(body, i + 2)
        char == "\"" -> i + 1
        true -> find_quote_end(body, i + 1)
      end
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

    header <> Enum.join(new_sections, "\n\n")
  end

  defp determine_object_type(ast) do
    inherits = ast.inherits

    cond do
      Enum.any?(inherits, &String.contains?(&1, "ROOM")) -> :room
      Enum.any?(inherits, &String.contains?(&1, "NPC")) -> :npc
      Enum.any?(inherits, &is_item_inherit?(&1)) -> :item
      Enum.any?(inherits, &String.contains?(&1, "SKILL") or String.contains?(&1, "FORCE")) -> :skill
      item_like?(ast) -> :item
      true -> :generic
    end
  end

  # 常见武器/防具/杂物类型的继承名；命中即视为物品。
  # 真实 corpus 里的类型五花八门，因此这里只列已知大类，其余走 item_like? 兜底。
  defp is_item_inherit?(inherit) do
    Enum.any?(
      ["WEAPON", "SWORD", "BLADE", "DAGGER", "STAFF", "CLUB", "HAMMER", "AXE",
       "THROWING", "WHIP", "FORCE ?", "ARMOR", "CLOTH", "BOOTS", "FINGER",
       "HANDS", "HEAD", "HELMET", "NECK", "RING", "SHIELD", "SURCOAT",
       "WAIST", "WRIST", "ARMOR ?", "ITEM", "MONEY", "CONTAINER", "FOOD",
       "MEDICINE", "BOOK", "GOLD", "SILVER"],
      fn kw -> String.contains?(inherit, kw) end
    )
  end

  # 兜底：obj 目录下的文件，具备 set_name/set_weight 等物品特征即视为物品
  defp item_like?(ast) do
    source = ast.source_path

    cond do
      String.contains?(source, "obj" <> "/") or String.contains?(source, Path.join("obj", "")) ->
        item_features?(ast)

      true ->
        false
    end
  end

  defp item_features?(ast) do
    create = ast.create_fn
    sets = Map.get(create, :sets, %{})
    set_name = Map.get(create, :set_name, %{})

    Map.has_key?(sets, "material") or Map.has_key?(sets, "unit") or
      Map.has_key?(sets, "value") or Map.has_key?(sets, "weight") or
      Map.has_key?(set_name, "name")
  end

  defp extract_string(value, default) do
    case value do
      {:string, s} -> s
      s when is_binary(s) -> s
      nil -> default
      _ -> default
    end
  end

  defp generate_room_ucl(ast, _zone_id) do
    create = ast.create_fn
    sets = Map.get(create, :sets, %{})
    heredocs = Map.get(ast.heredocs, :heredocs, %{})

    room_id =
      ast.source_path
      |> Path.basename()
      |> Path.rootname()
      |> String.replace("-", "_")

    room_block = """
    rooms "#{room_id}" {
      name = "#{extract_string(Map.get(sets, "short"), "Room")}"
      description = "#{get_heredoc_or_set(heredocs, sets, "long", "")}"
"""

    # Coordinates (default to origin; Loader requires x/y/z)
    coords_block = """
  x = #{coord_of(sets["x"])}
  y = #{coord_of(sets["y"])}
  z = #{coord_of(sets["z"])}
"""

    # Flags
    flags = build_room_flags(sets)
    flags_block =
      if flags != [] do
        """
          flags = [
        """ <> Enum.map_join(flags, "\n", &"            \"#{&1}\"") <> """
          ]
        """
      else
        ""
      end

    room_block = room_block <> coords_block <> flags_block <> "    }"

    # Exits -> room_exits block
    exits_block =
      case Map.get(sets, "exits") do
        {:mapping, exits} ->
          exit_lines =
            Enum.map_join(exits, "\n", fn {key, val} ->
              direction = exit_key(key)
              target = resolve_exit_target(val)
              "  #{direction} = #{target}"
            end)

          """
          room_exits "#{room_id}" {
            room_id = rooms.#{room_id}.id
        """ <> exit_lines <> """
          }
        """
        _ ->
          ""
      end

    objects_block = generate_room_objects(room_id, Map.get(sets, "objects"))

    Enum.join([room_block, exits_block, objects_block], "\n")
  end

  # --------------------------------------------------------------------------
  # set("objects", ([ __DIR__"npc/x" : n, __DIR__"obj/y" : 1 ]))
  #   -> room_characters "room" { room_id = ...; characters = [{ id = ... }, ...] }
  #   -> room_items      "room" { room_id = ...; items = [{ id = ... }, ...] }
  # --------------------------------------------------------------------------

  defp generate_room_objects(_room_id, nil), do: ""

  defp generate_room_objects(room_id, {:mapping, pairs}) do
    {char_links, item_links} =
      Enum.reduce(pairs, {[], []}, fn {key, count}, {chars, items} ->
        path = extract_key_path(key)
        id = object_id(path)

        if contains_npc?(path) do
          n = count_or_one(count)
          links = List.duplicate("      { id = characters.#{id}.id }", n)
          {chars ++ links, items}
        else
          {chars, items ++ ["      { id = items.#{id}.id }"]}
        end
      end)

    char_block =
      if char_links != [] do
        """
          room_characters "#{room_id}" {
            room_id = rooms.#{room_id}.id
            characters = [
        """ <>
          Enum.join(char_links, ",\n") <>
          """
            ]
          }
        """
      else
        ""
      end

    item_block =
      if item_links != [] do
        """
          room_items "#{room_id}" {
            room_id = rooms.#{room_id}.id
            items = [
        """ <>
          Enum.join(item_links, ",\n") <>
          """
            ]
          }
        """
      else
        ""
      end

    Enum.join([char_block, item_block], "\n")
  end

  defp generate_room_objects(_room_id, _), do: ""

  defp contains_npc?(path), do: String.contains?(path, "npc")

  defp count_or_one({:int, n}), do: max(n, 1)
  defp count_or_one(_), do: 1

  defp extract_key_path({:var, v}), do: v
  defp extract_key_path({:string, v}), do: v
  defp extract_key_path(_), do: ""

  defp object_id(path), do: room_id_from_path(path)

  defp coord_of({:int, v}), do: v
  defp coord_of(_), do: 0

  defp resolve_exit_target({:string, s}), do: "rooms." <> room_id_from_path(s) <> ".id"

  defp resolve_exit_target({:var, v}) do
    v = String.trim(v)
    "rooms." <> room_id_from_path(v) <> ".id"
  end

  defp resolve_exit_target(_), do: "\"unknown\""

  defp room_id_from_path(path) do
    # Normalize __DIR__"x" -> x, "/d/zone/x" -> x, strip quotes
    stripped =
      path
      |> String.replace(~r/__DIR__"/, "")
      |> String.replace(~r/"$/, "")
      |> String.replace(~r/^"\/d\//, "")

    stripped
    |> Path.basename()
    |> Path.rootname()
    |> String.replace("-", "_")
    |> String.downcase()
  end

defp exit_key({:string, s}), do: s
  defp exit_key({:int, n}), do: to_string(n)
  defp exit_key({:var, v}), do: v
  defp exit_key(s) when is_binary(s), do: s
  defp exit_key(_), do: "unknown"

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
      %{content: content} -> escape_heredoc_content(content)
      nil ->
        case Map.get(sets, key) do
          {:string, s} -> escape_set_string(s)
          _ -> default
        end
    end
  end

  # Heredoc content is raw LPC text (real newlines, real quotes).
  # UCL/Elias accepts "\n" as literal backslash-n and "\"" as a quote.
  defp escape_heredoc_content(str) do
    str
    |> String.replace("\n", "\\n")
    |> String.replace("\"", "\\\"")
  end

  # Set-string values already carry LPC escapes (\" for a literal quote, \n
  # for a line break, ...). Only real newline chars (from multi-line LPC
  # literals that our parser joined) need converting to "\n".
  defp escape_set_string(str) do
    String.replace(str, "\n", "\\n")
  end

  defp generate_npc_ucl(ast, zone_id) do
    create = ast.create_fn
    sets = Map.get(create, :sets, %{})
    heredocs = Map.get(create, :heredocs, %{})

    npc_id =
      ast.source_path
      |> Path.basename()
      |> Path.rootname()
      |> String.replace("-", "_")

    ucl = """
    characters "#{npc_id}" {
      name = "#{extract_string(Map.get(sets, "name"), "NPC")}"
      description = "#{get_heredoc_or_set(heredocs, sets, "long", "")}"
"""

    # Brain reference (from inherit or default)
    brain = infer_brain(ast.inherits)
    brain_line = if brain != nil, do: "  brain = brains.#{brain}\n", else: ""

    # Combat config
    combat = build_npc_combat(sets)

    # Goods
    goods = build_goods(sets)

    # Inquiries
    inquiries = build_inquiries(sets)

    # Chat
    chat = build_chat(sets)

    ucl <> brain_line <>
      (if combat != "", do: "\n  combat = {\n#{combat}\n  }\n", else: "") <>
      (if goods != [], do: "\n  goods = [\n" <> Enum.map_join(goods, "\n", &"    { id = #{&1} }") <> "\n  ]\n", else: "") <>
      (if inquiries != %{}, do: "\n  inquiries = {\n" <> generate_inquiries(inquiries) <> "\n  }\n", else: "") <>
      (if chat != nil, do: "\n  #{chat}\n", else: "") <>
      "    }"
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
      true -> nil
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
        chat_lines = Enum.map(lines, fn {:string, s} -> "    \"#{escape_set_string(s)}\"" end) |> Enum.join(",\n")
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

    item_id =
      ast.source_path
      |> Path.basename()
      |> Path.rootname()
      |> String.replace("-", "_")

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

    # Meta
    meta = build_item_meta(sets, ast.inherits)

    ucl <> "  verbs = [\n" <> Enum.map_join(verbs, ",\n", &"    \"#{&1}\"") <> "\n  ]\n" <>
      (if meta != %{}, do: "\n  meta = {\n" <> generate_meta(meta) <> "\n  }\n", else: "") <>
      "    }"
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

  defp format_meta_value({:string, s}), do: "\"#{escape_set_string(s)}\""
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