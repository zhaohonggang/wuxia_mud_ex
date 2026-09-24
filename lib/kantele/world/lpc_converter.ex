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
    create_fn = parse_create_function(content, create_body)
    function_calls = parse_function_calls(create_body || find_create_body(content))
    
    # Collect handled function names to identify unhandled functions
    handled_functions = MapSet.new(["create", "init", "greeting", "accept_object", "permit_pass", "valid_leave"])
    other_fns = parse_other_functions(content)
    other_fn_names = Enum.map(other_fns, &(&1.name)) |> MapSet.new()
    unhandled_fns = MapSet.difference(other_fn_names, handled_functions)
    
    # Extract unhandled content: global variables, complex mappings, switch statements, etc.
    unhandled = extract_unhandled_content(content, unhandled_fns)
    
    %{
      inherits: parse_inherits(content),
      create_fn: create_fn,
      other_fns: other_fns,
      globals: parse_globals(content),
      heredocs: heredocs,
      source_path: source_path,
      base_path: base_path,
      valid_leave: parse_valid_leave(content),
      function_calls: function_calls,
      enter: extract_enter(content),
      greetings: extract_greetings(content),
      accept: extract_accept(content),
      guard: extract_guard(content),
      engage: extract_engage(content),
      unhandled: unhandled
    }
    |> AST.new()
    |> (fn ast -> {:ok, ast} end).()
  rescue
    e ->
      {:error, Exception.message(e)}
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

  @doc """
  Parse function calls in create() body: set_skill, map_skill, carry_object, etc.
  """
  defp parse_function_calls(body) do
    # Match function calls: func_name(arg1, arg2, ...);
    # Also handle chained calls like carry_object(...)->wear()
    Regex.scan(~r/(\w+)\s*\(([^)]*)\)\s*(?:->\s*\w+\s*\(\s*\))?\s*;/, body)
    |> Enum.reduce(%{}, fn [_, func, args_str], acc ->
      args =
        args_str
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.map(fn arg ->
          parse_lpc_value(arg)
        end)

      # Append to list for this function (support multiple calls)
      Map.update(acc, func, [args], fn existing -> existing ++ [args] end)
    end)
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

defp extract_unhandled_content(content, unhandled_fn_names) do
    try do
      unhandled = %{
        functions: [],
        globals: [],
        complex_mappings: [],
        switch_tables: [],
        switch_statements: [],
        switch_pools: [],
        conditional_branches: %{},
        complex_conditionals: [],
        raw_code_blocks: []
      }

# 1. Unhandled functions (not create/init/greeting/accept_object/permit_pass/valid_leave)
    unhandled = Enum.reduce(unhandled_fn_names, unhandled, fn fn_name, acc ->
      # Always record the function name for manual review, even if body extraction fails
      Map.update(acc, :functions, [fn_name], fn acc -> [fn_name | acc] end)
    end)

      # 2. Global variables not parsed by parse_globals (complex initializers)
      simple_globals =
        Regex.scan(~r/(int|string|mapping|object|mixed)\s+(\w+)\s*[=;]/, content)
        |> Enum.map(fn [_, type, name] -> {name, type} end)
        |> Enum.into(%{})

      complex_globals =
        Regex.scan(~r/(int|string|mapping|object|mixed)\s+(\w+)\s*=\s*[^;]+;/, content)
        |> Enum.map(fn [_, type, name] -> %{name: name, type: type} end)
        |> Enum.filter(fn %{name: name} -> not Map.has_key?(simple_globals, name) end)
      unhandled = Map.put(unhandled, :globals, complex_globals)

      # 3. Complex mappings with nested structures
      complex_mappings =
        Regex.scan(~r/\(\s*\[[^]]*\[[^]]*\]/, content)
        |> Enum.map(fn [m] -> m end)
        |> Enum.uniq()
      unhandled = Map.put(unhandled, :complex_mappings, complex_mappings)

      # 4. Switch statements：分三种
      #    - case-assign 表（L1，case 后是赋值键值对）→ switch_tables
      #    - random 台词池（L2，case 是 return/say/command 台词）→ switch_pools
      #    - 其余命令分发/状态机 → switch_statements 原文
      all_switches =
        Regex.scan(~r/switch\s*\(\s*[^()]*(?:\([^()]*\)[^()]*)*\)\s*\{[\s\S]*?\}/m, content)
        |> Enum.map(fn [stmt] -> String.trim(stmt) end)

      switch_tables =
        Enum.filter(all_switches, &is_switch_table?/1)
        |> Enum.map(&parse_switch_table/1)
        |> Enum.reject(&is_nil/1)

      switch_pools =
        Enum.filter(all_switches, fn stmt ->
          not is_switch_table?(stmt) and Regex.match?(~r/switch\s*\(\s*random\s*\(/s, stmt)
        end)

      switch_others =
        Enum.filter(all_switches, fn stmt ->
          not is_switch_table?(stmt) and not Regex.match?(~r/switch\s*\(\s*random\s*\(/s, stmt)
        end)

      unhandled = Map.put(unhandled, :switch_tables, switch_tables)
      unhandled = Map.put(unhandled, :switch_pools, switch_pools)
      unhandled = Map.put(unhandled, :switch_statements, switch_others)

      # 5. Conditional branches（if/else-if/else 链，"条件 → 行为"）
      conditional_branches =
        content
        |> function_bodies()
        |> Enum.reduce(%{}, fn {name, body}, acc ->
          case split_condition_branches(body) do
            [] -> acc
            chains -> Map.put(acc, name, chains)
          end
        end)
      unhandled = Map.put(unhandled, :conditional_branches, conditional_branches)

      # 6. Complex conditionals (nested if/else)
      complex_ifs =
        Regex.scan(~r/if\s*\([^)]+\)\s*\{[\s\S]*?\}\s*else\s*\{[\s\S]*?\}/m, content)
        |> Enum.map(fn [stmt] -> String.trim(stmt) end)
      unhandled = Map.put(unhandled, :complex_conditionals, complex_ifs)

      # 6. Raw code blocks (heartbeat, reset, clean_up)
      raw_blocks =
        Regex.scan(~r/(void|int)\s+(heart_beat|reset|clean_up)\s*\([^)]*\)\s*\{([\s\S]*?)\}/m, content)
        |> Enum.map(fn [_, _, name, body] -> %{name: name, body: String.trim(body)} end)
      unhandled = Map.put(unhandled, :raw_code_blocks, raw_blocks)

      unhandled
    rescue
      e ->
        IO.puts("WARNING: extract_unhandled_content failed: #{Exception.message(e)}")
        %{
          functions: [],
          globals: [],
          complex_mappings: [],
          switch_tables: [],
          switch_statements: [],
          switch_pools: [],
          conditional_branches: %{},
          complex_conditionals: [],
          raw_code_blocks: []
        }
    end
  end

  # case-assign 表判定：存在 `case "键": 变量 = 值;`（字符串键 + 赋值语句）
  defp is_switch_table?(stmt) do
    Regex.match?(~r/case\s+["'][^"']+["']\s*:\s*\w+\s*=/s, stmt)
  end

  # LPC switch(arg){ case "键": 变量 = 值; ... } → 解析为
  # %{expr: arg, rows: [%{key: 键, cols: [{变量, 值串}, ...]}]}
  # 值为字符串时保留引号，数字保数字，路径（new(...)）保留 clone 目标。
  defp parse_switch_table(stmt) do
    expr =
      case Regex.run(~r/switch\s*\(\s*([^)]+)\s*\)/, stmt) do
        [_, e] -> String.trim(e)
        _ -> nil
      end

    rows =
      Regex.scan(
        ~r/case\s+["']([^"']+)["']\s*:\s*([\s\S]*?)(?=case\s+["']|default\s*:)/,
        stmt
      )
      |> Enum.map(fn [_, key, body] ->
        cols =
          Regex.scan(~r/(\w+)\s*=\s*([^;]+);/, body)
          |> Enum.map(fn [_, var, val] ->
            {String.trim(var), String.trim(val)}
          end)

        %{key: key, cols: cols}
      end)

    if rows == [], do: nil, else: %{expr: expr, rows: rows}
  end

  # --------------------------------------------------------------------------
  # 条件分支抽取：if / else-if / else 链 → "条件 → 行为" 参考行（L2）
  # 只处理显式花括号块；原文保留在 COMPLEX CONDITIONALS 兜底（L3）。
  # --------------------------------------------------------------------------

  # 列出含花括号函数体的所有函数（{name, body}），复用 extract_function_body 的签名正则但不打 DEBUG。
  defp function_bodies(content) do
    sig = ~r/(?:int|string|void|mixed|mapping|object|protected)\s+(\w+)\s*\([^)]*\)\s*\n*\s*\{/

    Regex.scan(sig, content)
    |> Enum.map(fn [match, name] ->
      [_, rest] = String.split(content, match, parts: 2)
      brace_pos = String.length(content) - String.length(rest) - 1
      {name, find_matching_brace(content, brace_pos)}
    end)
    |> Enum.reject(fn {_, body} -> is_nil(body) end)
  end

  # 沿字符流扫描函数体，把顶层的 if/else-if/else 链切成
  # [%{kind: :if|:elif|:else, cond: 条件串|nil, actions: [行为串]}]
  # （不含 else 的独立 if、无花括号体不产出）。
  defp split_condition_branches(body) do
    chars = String.to_charlist(body)
    scan_chains(chars, 0, [], nil)
  end

  defp scan_chains(chars, i, acc, prev) do
    case next_word(chars, i) do
      nil ->
        Enum.reverse(acc)

      {"if", j, _} when prev != "else" ->
        case parse_chain(chars, j) do
          nil -> scan_chains(chars, j + 2, acc, "if")
          {chain, after_i} -> scan_chains(chars, after_i, [chain | acc], nil)
        end

      {w, _j, next} ->
        scan_chains(chars, next, acc, w)
    end
  end

  defp parse_chain(chars, if_pos) do
    case extract_condition(chars, if_pos) do
      nil ->
        nil

      {cond, after_paren} ->
        case read_block(chars, after_paren) do
          nil ->
            nil

          {body1, after1} ->
            head = %{kind: :if, cond: cond, actions: branch_actions(List.to_string(body1))}
            collect_else(chars, after1, [head])
        end
    end
  end

  # 从 if/else if 的关键字位置提取条件串；返回 {cond, 右括号后的下标}
  defp extract_condition(chars, if_pos) do
    j = skip_trivia(chars, if_pos + 2)

    if char_at(chars, j) == ?( do
      case match_delim(chars, j + 1, ?(, ?), 1) do
        nil ->
          nil

        close ->
          inner = Enum.slice(chars, j + 1, close - j - 1)
          {collapse_ws(List.to_string(inner)), skip_trivia(chars, close + 1)}
      end
    else
      nil
    end
  end

  defp collect_else(chars, i, acc) do
    case next_word(chars, i) do
      {"else", _, next} ->
        k = skip_trivia(chars, next)

        if word_at?(chars, k, "if") do
          case extract_condition(chars, k) do
            {cond, after_paren} ->
              case read_block(chars, after_paren) do
                {body, after_idx} ->
                  branch = %{kind: :elif, cond: cond, actions: branch_actions(List.to_string(body))}
                  collect_else(chars, after_idx, acc ++ [branch])

                nil ->
                  {acc, i}
              end

            nil ->
              {acc, i}
          end
        else
          case read_block(chars, k) do
            {body, after_idx} ->
              branch = %{kind: :else, actions: branch_actions(List.to_string(body))}
              {acc ++ [branch], after_idx}

            nil ->
              {acc, k}
          end
        end

      _ ->
        {acc, i}
    end
  end

  # 读块：花括号块（递归配平）或无花括号的单语句（到分号为止）
  defp read_block(chars, i) do
    case char_at(chars, i) do
      ?{ ->
        case match_delim(chars, i + 1, ?{, ?}, 1) do
          nil -> nil
          close -> {Enum.slice(chars, i + 1, close - i - 1), close + 1}
        end

      c when c != nil and c != ?; ->
        read_statement(chars, i)

      _ ->
        nil
    end
  end

  defp read_statement(chars, i) do
    {fwd, next} = do_read_statement(chars, i, [], 0)
    {Enum.reverse(fwd), next}
  end

  defp do_read_statement(chars, i, acc, depth) do
    case char_at(chars, i) do
      nil ->
        {acc, i}

      ?; when depth == 0 ->
        {acc, i + 1}

      ?" ->
        k = skip_string(chars, i)
        seg = Enum.slice(chars, i, k - i)
        do_read_statement(chars, k, Enum.reverse(seg) ++ acc, depth)

      ?{ ->
        do_read_statement(chars, i + 1, [?{ | acc], depth + 1)

      ?} ->
        do_read_statement(chars, i + 1, [?} | acc], max(depth - 1, 0))

      ?( ->
        do_read_statement(chars, i + 1, [?( | acc], depth + 1)

      ?) ->
        do_read_statement(chars, i + 1, [?)| acc], max(depth - 1, 0))

      _ ->
        do_read_statement(chars, i + 1, [char_at(chars, i) | acc], depth)
    end
  end

  # 分支行为抽取：command/say/tell_object/message_vision/write 整句台词
  defp branch_actions(body) do
    Regex.scan(~r/(command|say|tell_object|message_vision|write)\s*\([\s\S]*?\);/, body)
    |> Enum.filter(&(&1 != []))
    |> Enum.map(fn [full | _] -> full |> String.replace(~r/\s+/, " ") |> String.trim() end)
    |> Enum.uniq()
  end

  defp collapse_ws(s), do: String.replace(s, ~r/\s+/, " ")

  # ---------- 字符流工具 ----------

  defp char_at(chars, i), do: Enum.at(chars, i)

  defp is_ident(c) when is_integer(c), do: c in ?a..?z or c in ?A..?Z or c in ?0..?9 or c == ?_

  defp is_ident(_), do: false

  # w（如 "if"/"else"）恰好以 word 形式出现在 chars 的 i 处：前后都不是标识符字符
  defp word_at?(chars, i, w) do
    wlen = length(String.to_charlist(w))

    match =
      i >= 0 and
        i + wlen <= length(chars) and
        Enum.slice(chars, i, wlen) == String.to_charlist(w)

    match and
      (i == 0 or not is_ident(Enum.at(chars, i - 1))) and
      (i + wlen >= length(chars) or not is_ident(Enum.at(chars, i + wlen)))
  end

  # 读取下一个 token：跳过空白/注释/字符串字面量，返回 {词, 起始下标, 结束下标}
  defp next_word(chars, i) do
    case skip_trivia(chars, i) do
      nil ->
        nil

      j ->
        case char_at(chars, j) do
          ?" ->
            k = skip_string(chars, j)
            if is_nil(k), do: nil, else: {"<str>", j, k}

c ->
        if is_ident(c) do
          {w, k} = read_ident(chars, j)
          {List.to_string(w), j, k}
        else
          {"", j, j + 1}
        end
        end
    end
  end

  defp read_ident(chars, i), do: do_read_ident(chars, i, [])

  defp do_read_ident(chars, i, acc) do
    case char_at(chars, i) do
      c when is_integer(c) ->
        if is_ident(c) do
          do_read_ident(chars, i + 1, [c | acc])
        else
          {Enum.reverse(acc), i}
        end

      _ ->
        {Enum.reverse(acc), i}
    end
  end

  # 跳过空白、// 行注释、/* */ 块注释；返回下一个实质字符下标
  defp skip_trivia(chars, i) do
    case char_at(chars, i) do
      nil ->
        nil

      c when c in [? , ?\t, ?\n, ?\r] ->
        skip_trivia(chars, i + 1)

      ?/ ->
        case char_at(chars, i + 1) do
          ?/ -> skip_trivia(chars, skip_line_comment(chars, i + 2))
          ?* -> skip_trivia(chars, skip_block_comment(chars, i + 2))
          _ -> i
        end

      _ ->
        i
    end
  end

  # 跳过 "..." 字符串（含转义），返回收尾引号后的下标
  defp skip_string(chars, i) do
    do_skip_string(chars, i + 1, false)
  end

  defp do_skip_string(chars, i, escaped?) do
    case char_at(chars, i) do
      nil ->
        nil

      ?\\ when not escaped? ->
        do_skip_string(chars, i + 1, true)

      ?" when not escaped? ->
        i + 1

      _ ->
        do_skip_string(chars, i + 1, false)
    end
  end

  defp skip_line_comment(chars, i) do
    case char_at(chars, i) do
      nil -> i
      ?\n -> i + 1
      _ -> skip_line_comment(chars, i + 1)
    end
  end

  defp skip_block_comment(chars, i) do
    case char_at(chars, i) do
      nil ->
        i

      ?* ->
        if char_at(chars, i + 1) == ?/ do
          i + 2
        else
          skip_block_comment(chars, i + 1)
        end

      _ ->
        skip_block_comment(chars, i + 1)
    end
  end

  # 配平开闭字符（括号/花括号），跳过字符串与注释；返回闭合下标
  defp match_delim(chars, i, open, close, depth) do
    case char_at(chars, i) do
      nil ->
        nil

      ?" ->
        case skip_string(chars, i) do
          nil -> nil
          k -> match_delim(chars, k, open, close, depth)
        end

      ?/ ->
        case char_at(chars, i + 1) do
          ?/ -> match_delim(chars, skip_line_comment(chars, i + 2), open, close, depth)
          ?* -> match_delim(chars, skip_block_comment(chars, i + 2), open, close, depth)
          _ -> match_delim(chars, i + 1, open, close, depth)
        end

      ^open ->
        match_delim(chars, i + 1, open, close, depth + 1)

      ^close ->
        if depth == 1, do: i, else: match_delim(chars, i + 1, open, close, depth - 1)

      _ ->
        match_delim(chars, i + 1, open, close, depth)
    end
  end

  @doc """
  Parse valid_leave function to extract guard exit behavior.
  
  Matches pattern:
    int valid_leave(object me, string dir) {
      if (objectp(guarder = present("guard name", this_object())) && dir == "direction")
        return guarder->permit_pass(me, dir);
      return 1;
    }
  
  Returns map with: guard_npc, direction, permit_module, permit_function
  """
  defp parse_valid_leave(content) do
    # Find valid_leave function body
    case Regex.run(~r/int\s+valid_leave\s*\([^)]*\)\s*\{/, content) do
      nil -> nil
      [match] ->
        parts = String.split(content, match, parts: 2)
        case parts do
          [_, rest] ->
            # Find matching brace for function body
            body = find_matching_brace(content, String.length(match) + String.length(parts |> List.first()))
            parse_valid_leave_body(body)
          _ -> nil
        end
    end
  end

  defp find_quote_end(content, start) do
    find_quote_end_loop(content, start)
  end

  defp find_quote_end_loop(content, i) do
    if i >= String.length(content) do
      nil
    else
      char = String.at(content, i)
      cond do
        char == "\\" -> find_quote_end_loop(content, i + 2)
        char == "\"" -> i + 1
        true -> find_quote_end_loop(content, i + 1)
      end
    end
  end

  defp parse_valid_leave_body(body) do
    # Match: present("guard name", this_object())
    guard_npc =
      case Regex.run(~r/present\s*\(\s*(["'])([^"']+)\1\s*,\s*this_object\s*\(\s*\)/, body) do
        [_, _, name] -> name
        _ -> nil
      end

    # Match: dir == "direction"
    direction =
      case Regex.run(~r/dir\s*==\s*(["'])([^"']+)\1/, body) do
        [_, _, dir] -> dir
        _ -> nil
      end

    # Match: guarder->permit_pass or guard->permit_pass or xxx->permit_pass
    has_permit_pass = String.contains?(body, "permit_pass")

    cond do
      guard_npc && direction && has_permit_pass ->
        %{
          guard_npc: guard_npc,
          direction: direction,
          permit_module: "Kantele.Npc.Guarder",
          permit_function: "permit_pass"
        }
      true ->
        nil
    end
  end

  # ---- 功能函数抽取：init / greeting / accept_object ----

# 按函数名抽取函数体（不含外层大括号）。找不到返回 nil。
  defp extract_function_body(content, name) do
    # Match function signature with optional newline before opening brace
    case Regex.run(~r/(?:int|string|void|mixed|mapping|object|protected)\s+#{name}\s*\([^)]*\)\s*\n*\s*\{/, content) do
      nil ->
        IO.puts("DEBUG extract_function_body: no match for #{name}")
        nil
      [match] ->
        parts = String.split(content, match, parts: 2)
        case parts do
          [before, _rest] ->
            brace_pos = String.length(before) + String.length(match) - 1
            IO.puts("DEBUG extract_function_body: name=#{name}, brace_pos=#{brace_pos}, char=#{String.at(content, brace_pos)}")
            find_matching_brace(content, brace_pos)
          _ -> nil
        end
    end
  end

  # init()：add_action 注册的命令 / call_out("greeting", N) 延迟 / set_heart_beat(N)
  defp extract_enter(content) do
    case extract_function_body(content, "init") do
      nil -> nil
      body -> parse_enter_body(body)
    end
  end

  defp parse_enter_body(body) do
    add_actions =
      Regex.scan(~r/add_action\s*\(\s*["']([^"']+)["']\s*,\s*["']([^"']+)["']\s*\)/, body)
      |> Enum.map(fn [_, _func, verb] -> verb end)
      |> Enum.uniq()

    greet_delay =
      case Regex.run(~r/call_out\s*\(\s*["']greeting["']\s*,\s*(\d+)/, body) do
        [_, n] -> String.to_integer(n)
        _ -> 0
      end

    heartbeat =
      case Regex.run(~r/set_heart_beat\s*\(\s*(\d+)/, body) do
        [_, n] -> String.to_integer(n)
        _ -> 0
      end

    if add_actions == [] and greet_delay == 0 and heartbeat == 0 do
      nil
    else
      %{greet_delay: greet_delay, add_actions: add_actions, heartbeat: heartbeat}
    end
  end

  # greeting()：say/message_vision 台词池。字符串字面量拼接，LPC 表达式转占位符。
  defp extract_greetings(content) do
    case extract_function_body(content, "greeting") do
      nil ->
        nil

      body ->
        lines =
          Regex.scan(~r/(?:say|message_vision)\s*\(([\s\S]*?)\)\s*;/m, body)
          |> Enum.map(fn [_, args] -> render_dialogue(args) end)

        lines
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> case do
          [] -> nil
          clean -> clean
        end
    end
  end

  # 把 LPC 台词表达式还原为文本：字符串字面量拼接，表达式换成运行时占位符。
  defp render_dialogue(args) do
    parts = Regex.split(~r/("(?:[^"\\]|\\.)*")/, args, include_captures: true, trim: true)

    Enum.map(parts, fn token ->
      case token do
        "" ->
          ""

        "\"" <> rest ->
          # 去掉首尾引号（保留内部转义原样）
          inner = String.slice(rest, 0, max(String.length(rest) - 1, 0))
          inner =
            inner
            |> String.replace("\\n", "\n")
            |> String.replace("$N", "{npc}")
            |> String.replace("$n", "{name}")

          inner

        raw ->
          render_dialogue_expr(raw)
      end
    end)
    |> Enum.join()
  end

  defp render_dialogue_expr(raw) do
    expr = String.trim(raw)

    cond do
      # 纯大写 ANSI/宏常量（CYN/NOR/HIC/HIW ...），或仅由常量拼接（CYN + HIC + ）
      expr == "" -> ""
      Regex.match?(~r/^[A-Z][A-Z0-9_]*$/, expr) -> ""
      String.contains?(expr, "RANK_D->query_respect") -> "{respect}"
      String.contains?(expr, "RANK_D->query_rude") -> "{rude}"
      String.contains?(expr, "->name()") or String.contains?(expr, "query(\"name\")") -> "{name}"
      only_ansi_constants(expr) -> ""
      true -> "{expr}"
    end
  end

  # 表达式仅由 ANSI 常量与 + / 空格组成（如 "CYN + HIC + "）时，运行时无法重现，压成空。
  defp only_ansi_constants(expr) do
    expr
    |> String.replace(~r/[A-Z][A-Z0-9_]*/, "")
    |> String.replace("+", "")
    |> String.trim()
    |> Kernel.==("")
  end

  # accept_object()：抽取可识别的接收规则（收钱 / 指定物品 / 默认接受与否）。
  defp extract_accept(content) do
    case extract_function_body(content, "accept_object") do
      nil -> nil
      body -> parse_accept_body(body)
    end
  end

  # permit_pass() / guarder：抽取守卫配置（family + 拒绝台词）。
  defp extract_guard(content) do
    case extract_function_body(content, "permit_pass") do
      nil -> nil
      body -> parse_guard_body(body)
    end
  end

  defp parse_guard_body(body) do
    # 提取 family：me->query("family/family_name") == "门派名"
    family =
      case Regex.run(~r|query\s*\(\s*["']family/family_name["']\s*\)\s*==\s*["']([^"']+)["']|, body) do
        [_, fam] -> fam
        _ -> nil
      end

    # 提取拒绝台词：message_vision("...", this_object(), me)
    refuse_msg =
      case Regex.run(~r/message_vision\s*\(\s*["']([^"']+)["']/, body) do
        [_, msg] ->
          msg
          |> String.replace("\\n", "\n")
          |> String.replace("$N", "{npc}")
          |> String.replace("$n", "{name}")
          |> String.trim()
        _ -> nil
      end

    if is_nil(family) and is_nil(refuse_msg) do
      nil
    else
      %{
        family: family,
        refuse_other: refuse_msg
      }
    end
  end

  # accept_fight()/accept_hit()/accept_kill()：抽取 NPC 开战接受语义。
  # 返回 %{fight: %{...}, hit: %{...}, kill: %{...}}（只含检测到的键），
  # 每个键：%{accept: true|false, msg: 台词或 nil, retaliate: bool, spawn: [id]}
  # 复杂逻辑保留在 :note 供人工复核。
  defp extract_engage(content) do
    [:fight, :hit, :kill]
    |> Enum.reduce(%{}, fn kind, acc ->
      case extract_function_body(content, "accept_#{kind}") do
        nil ->
          acc

        body ->
          case parse_engage_kind(body) do
            nil -> acc
            parsed -> Map.put(acc, kind, parsed)
          end
      end
    end)
    |> case do
      %{} = engage when map_size(engage) > 0 -> engage
      _ -> nil
    end
  end

  # 解析单个 accept_fight/hit/kill 函数体为语义规则。
  # 启发式：
  #   - accept = 函数体最后一个 return 0/1（与 accept_object 同口径）
  #   - retaliate = 存在顶层 kill_ob(this_player()) 调用
  #   - spawn = new(__DIR__"...") / new("/abs/path/name") 召唤帮手名单
  #   - ::accept_xxx 继承回退 → 标记 :inherit（父类行为不可见，不猜测语义）
  defp parse_engage_kind(body) do
    last_return = get_last_return(body)
    has_return = not is_nil(last_return)
    has_kill_ob = has_own_kill_ob?(body)
    has_inherit = Regex.match?(~r/::\s*accept_(fight|hit|kill)\s*\(/, body)
    msg = extract_engage_msg(body)
    spawn = extract_spawn_ids(body)

    cond do
      # 有明确 return 0/1（最普遍）：accept 取最后一个
      has_return ->
        %{
          accept: last_return == 1,
          msg: msg,
          retaliate: has_kill_ob,
          spawn: spawn,
          inherit: has_inherit,
          note: body
        }

      # 无 return，纯继承回退（如只 return ::accept_kill(ob)）
      has_inherit ->
        %{
          accept: nil,
          msg: msg,
          retaliate: has_kill_ob,
          spawn: spawn,
          inherit: true,
          note: body
        }

      true ->
        # 认不出的结构：保留原文供人工决策，accept 置 nil（运行时按缺省放行）
        %{accept: nil, msg: msg, retaliate: false, spawn: spawn, inherit: false, note: body}
    end
  end

  # NPC 自身调用 kill_ob（反杀），排除 "->kill_ob"（帮手反杀他人）。
  defp has_own_kill_ob?(body) do
    Regex.match?(~r/(?<!->)kill_ob\s*\(/, body)
  end

  # 从 accept_* 函数体中抽取 NPC 台词：
  #   - 优先 command("say ...") 的短句
  #   - 其次 message_vision(...) 的首个字符串字面量，跨行拼接相邻字面量
  # 拼回前同样经 process_literal_string 处理占位符与转义。
  defp extract_engage_msg(body) do
    case Regex.run(~r/command\s*\(\s*["']say\s+([^"']+)["']\s*\)/, body) do
      [_, m] -> m |> process_literal_string()
      _ -> extract_message_vision_literal(body)
    end
  end

  # message_vision("..." "..." \n ...) 跨行字面量拼接，取首个相连串。
  defp extract_message_vision_literal(body) do
    case Regex.run(
           ~r/message_vision\s*\(\s*((?:"(?:\\.|[^"\\])*"\s*)+)/,
           body
         ) do
      nil ->
        nil

      [_, group] ->
        Regex.scan(~r/"((?:\\.|[^"\\])*)"/, group)
        |> Enum.map(fn [_, s] -> s end)
        |> Enum.join()
        |> process_literal_string()
        |> case do
          "" -> nil
          m -> m
        end
    end
  end

  # 从 accept_* 函数体中抽取召唤帮手的 id：new(__DIR__"name") / new("/p/x/name")
  defp extract_spawn_ids(body) do
    Regex.scan(~r/new\s*\(\s*(?:__DIR__)?\s*["']([^"']+)["']\s*\)/, body)
    |> Enum.map(fn [_, path] ->
      path
      |> Path.basename()
      |> Path.rootname()
    end)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_accept_body(body) do
    # Extract dialogue lines from accept_object (tell_object, command say, message_vision, say)
    accept_dialogues = extract_accept_dialogues(body)

    money_rule =
      if body =~ ~r/money_id/ do
        min =
          case Regex.run(~r/->value\s*\(\s*\)\s*>=\s*(\d+)/, body) do
            [_, n] -> String.to_integer(n)
            _ -> nil
          end

        msg = Map.get(accept_dialogues, :money) || Map.get(accept_dialogues, :default)

        %{kind: "money", min: min, msg: msg}
      end

    item_id_rules =
      Regex.scan(~r/(\w+->)?query\s*\(\s*["']id["']\s*\)\s*==\s*["']([^"']+)["']/, body)
      |> Enum.map(fn [_, _, id] ->
        %{kind: "item_id", id: id, msg: Map.get(accept_dialogues, :"item_id_#{id}") || Map.get(accept_dialogues, :default)}
      end)

    item_name_rules =
      Regex.scan(~r/(\w+->)?query\s*\(\s*["']name["']\s*\)\s*==\s*["']([^"']+)["']/, body)
      |> Enum.map(fn [_, _, name] ->
        %{kind: "item_name", name: name, msg: Map.get(accept_dialogues, :"item_name_#{name}") || Map.get(accept_dialogues, :default)}
      end)

has_return_0 = Regex.match?(~r/return\s+0\s*;/, body)
    has_return_1 = Regex.match?(~r/return\s+1\s*;/, body)

    # 判斷是否有具體的接受規則（money/item_id/item_name）
    has_specific_rules = (money_rule != nil) or (item_id_rules != []) or (item_name_rules != [])

    # 檢查函數最後一個 return 語句是 0 還是 1
    last_return = get_last_return(body)

    default_rule =
      cond do
        has_return_0 and not has_return_1 ->
          %{kind: "any", accept: false, msg: Map.get(accept_dialogues, :reject)}

        has_return_1 and not has_return_0 ->
          %{kind: "any", accept: has_specific_rules, msg: Map.get(accept_dialogues, :default)}

        has_return_0 and has_return_1 ->
          # 同時有 return 0 和 return 1：看最後一個 return 決定預設行為
          accept_default = last_return == 1
          msg = if last_return == 1, do: Map.get(accept_dialogues, :default), else: Map.get(accept_dialogues, :reject)
          %{kind: "any", accept: accept_default, msg: msg || Map.get(accept_dialogues, :default)}

        true ->
          nil
      end

    rules = Enum.reject([money_rule] ++ item_id_rules ++ item_name_rules ++ [default_rule], &is_nil/1)

    if rules == [], do: nil, else: rules
  end

  # 从 accept_object 函数体中抽取 NPC 台词（tell_object, command say, message_vision, say）
  defp extract_accept_dialogues(body) do
    # 抽取所有字符串字面量及其上下文
    all_strings = extract_all_strings_with_context(body)

    # 启发式分配：按出现顺序和上下文关键字分配
    money_msgs = Enum.filter(all_strings, fn {ctx, _} -> ctx in [:tell_object, :money] end) |> Enum.map(&elem(&1, 1))
    default_msgs = Enum.filter(all_strings, fn {ctx, _} -> ctx in [:command_say, :say, :message_vision, :command_other] end) |> Enum.map(&elem(&1, 1))
    reject_msgs = Enum.filter(all_strings, fn {ctx, _} -> ctx == :reject end) |> Enum.map(&elem(&1, 1))

    money_msg = List.first(money_msgs) || List.first(default_msgs)
    default_msg = List.first(default_msgs)
    reject_msg = List.first(reject_msgs)

    %{
      money: money_msg,
      default: default_msg,
      reject: reject_msg
    }
  end

  # 抽取函数体中所有字符串字面量及其上下文
  defp extract_all_strings_with_context(body) do
    # tell_object(me, ...) - 收钱回复
    tell_object =
      Regex.scan(~r/tell_object\s*\([^)]+\)/, body)
      |> Enum.flat_map(fn [call] ->
        # 从 tell_object 调用中提取所有字符串字面量
        Regex.scan(~r/"((?:\\.|[^"\\])*)"/, call)
        |> Enum.map(fn [_, s] -> {:tell_object, process_literal_string(s)} end)
      end)

    # command("say ...")
    cmd_say =
      Regex.scan(~r/command\s*\(\s*["']say\s+([^"']+)["']\s*\)/, body)
      |> Enum.map(fn [_, msg] -> {:command_say, process_literal_string(msg)} end)

    # message_vision("msg", ...)
    mv =
      Regex.scan(~r/message_vision\s*\(\s*["']([^"']+)["']/, body)
      |> Enum.map(fn [_, msg] -> {:message_vision, process_literal_string(msg)} end)

    # say("msg")
    say =
      Regex.scan(~r/say\s*\(\s*["']([^"']+)["']\s*\)/, body)
      |> Enum.map(fn [_, msg] -> {:say, process_literal_string(msg)} end)

    # command("msg") 不带 say 的情况
    cmd_other =
      Regex.scan(~r/command\s*\(\s*["']([^"']+)["']\s*\)/, body)
      |> Enum.map(fn [_, msg] -> {:command_other, process_literal_string(msg)} end)

    tell_object ++ cmd_say ++ mv ++ say ++ cmd_other
  end

  # 处理字面量字符串：处理转义字符、LPC 变量替换
  defp process_literal_string(s) do
    s
    |> String.replace("\\n", "\n")
    |> String.replace("$N", "{npc}")
    |> String.replace("$n", "{name}")
    |> String.trim()
  end

  # 取得函數體中最後一個 return 0 或 return 1
  defp get_last_return(body) do
    # 從後往前找最後一個 return 0; 或 return 1;
    # 忽略大括號內容，只看頂層的 return
    matches = Regex.scan(~r/return\s+([01])\s*;/, body)
    case matches do
      [] -> nil
      matches ->
        # 取最後一個匹配
        [_, last] = List.last(matches)
        String.to_integer(last)
    end
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

    header <> Enum.join(new_sections, "\n\n") <> generate_unhandled_comments(ast.unhandled)
  end

  defp generate_unhandled_comments(unhandled) do
    sections =
      [
        # Unhandled functions
        if unhandled[:functions] != [] do
          fn_list = Enum.map(unhandled[:functions], fn name -> "  # UNHANDLED FUNCTION: #{name}" end)
          ["# ==== UNHANDLED FUNCTIONS ====" | fn_list]
        else
          []
        end,

        # Unhandled globals
        if unhandled[:globals] != [] do
          global_list = Enum.map(unhandled[:globals], fn %{name: name, type: type} ->
            "  # UNHANDLED GLOBAL: #{type} #{name}"
          end)
          ["# ==== UNHANDLED GLOBAL VARIABLES ====" | global_list]
        else
          []
        end,

        # Complex mappings
        if unhandled[:complex_mappings] != [] do
          mapping_list = Enum.map(unhandled[:complex_mappings], fn m ->
            "  # COMPLEX MAPPING: #{String.trim(m)}"
          end)
          ["# ==== COMPLEX MAPPINGS ====" | mapping_list]
        else
          []
        end,

        # Switch tables（case-assign 表，结构化）
        if unhandled[:switch_tables] != [] do
          table_list =
            Enum.map(unhandled[:switch_tables], fn %{expr: expr, rows: rows} ->
              head = "  # SWITCH TABLE (expr: #{expr})"
              divider = "  # " <> String.duplicate("-", 64)

              row_lines =
                Enum.map(rows, fn %{key: key, cols: cols} ->
                  cols_str =
                    Enum.map_join(cols, " ", fn {v, val} -> "#{v}=#{val}" end)

                  "  #   #{key}: #{cols_str}"
                end)

              [head, divider | row_lines]
            end)
            |> List.flatten()

          ["# ==== SWITCH TABLES ====" | table_list]
        else
          []
        end,

        # Switch statement pools（random 台词池）
        if unhandled[:switch_pools] != [] do
          pool_list = Enum.map(unhandled[:switch_pools], fn stmt ->
            lines = String.split(stmt, "\n")
            Enum.map(lines, fn l -> "  # SWITCH POOL: #{String.trim(l)}" end)
            |> Enum.join("\n")
          end)
          ["# ==== SWITCH POOLS ====" | pool_list]
        else
          []
        end,

        # Switch statements（命令分发/状态机，原文保留）
        if unhandled[:switch_statements] != [] do
          switch_list = Enum.map(unhandled[:switch_statements], fn stmt ->
            lines = String.split(stmt, "\n")
            Enum.map(lines, fn l -> "  # SWITCH: #{String.trim(l)}" end)
            |> Enum.join("\n")
          end)
          ["# ==== SWITCH STATEMENTS ====" | switch_list]
        else
          []
        end,

        # Conditional branches（if/else-if/else 链，"条件 → 行为"）
        if unhandled[:conditional_branches] != %{} do
          branch_sections =
            for {fn_name, chains} <- unhandled[:conditional_branches] do
              header = "# ==== CONDITIONAL BRANCHES (#{fn_name}) ===="

              chain_lines =
                Enum.map(chains, fn chain ->
                  Enum.map(chain, fn branch ->
                    prefix =
                      case branch.kind do
                        :if -> "if (#{branch.cond})"
                        :elif -> "else if (#{branch.cond})"
                        :else -> "else"
                      end

                    actions = Enum.join(branch.actions, " ")
                    "  # #{prefix}  →  #{actions}"
                  end)
                end)
                |> List.flatten()

              [header | chain_lines]
            end

          ["# ==== CONDITIONAL BRANCHES ====" | List.flatten(branch_sections)]
        else
          []
        end,

        # Complex conditionals
        if unhandled[:complex_conditionals] != [] do
          cond_list = Enum.map(unhandled[:complex_conditionals], fn stmt ->
            lines = String.split(stmt, "\n")
            Enum.map(lines, fn l -> "  # COMPLEX IF: #{String.trim(l)}" end)
            |> Enum.join("\n")
          end)
          ["# ==== COMPLEX CONDITIONALS ====" | cond_list]
        else
          []
        end,

        # Raw code blocks (heartbeat, reset, etc.)
        if unhandled[:raw_code_blocks] != [] do
          block_list = Enum.map(unhandled[:raw_code_blocks], fn %{name: name, body: body} ->
            lines = String.split(body, "\n")
            comment_lines = Enum.map(lines, fn l -> "  # #{name}: #{String.trim(l)}" end)
            Enum.join(["  # RAW BLOCK: #{name}", comment_lines | []], "\n")
          end)
          ["# ==== RAW CODE BLOCKS ====" | block_list]
        else
          []
        end
      ]
      |> List.flatten()

    if sections != [] do
      header = "\n\n# ========================================\n# UNHANDLED CONTENT (for manual review)\n# ========================================\n"
      body = Enum.reverse(sections) |> Enum.join("\n")
      footer = "\n# ========================================\n"
      header <> body <> footer
    else
      ""
    end
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

    room_block = room_block <> coords_block <> flags_block

    # Behavior from valid_leave (guarded exits)
    behavior_block =
      case ast.valid_leave do
        nil -> ""
        vl ->
          """
          behavior = "guarded_exit"
          behavior_config = {
            guard_npc = "#{vl.guard_npc}"
            direction = "#{vl.direction}"
            permit_module = "#{vl.permit_module}"
            permit_function = "#{vl.permit_function}"
          }
        """
      end

    room_block = room_block <> behavior_block <> "    }"

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
    set_name = Map.get(create, :set_name, %{})
    heredocs = Map.get(create, :heredocs, %{})

    npc_id =
      ast.source_path
      |> Path.basename()
      |> Path.rootname()
      |> String.replace("-", "_")

    # Extract name from set_name (primary) or sets (fallback)
    name = extract_string(Map.get(set_name, "name"), extract_string(Map.get(sets, "name"), "NPC"))
    aliases = Map.get(set_name, "aliases", [])

    ucl = """
    characters "#{npc_id}" {
      name = "#{name}"
      description = "#{get_heredoc_or_set(heredocs, sets, "long", "")}"
"""

    # Basic attributes from set()
    basic_attrs = []
    basic_attrs = add_if_present(basic_attrs, sets, "title", :string)
    basic_attrs = add_if_present(basic_attrs, sets, "nickname", :string)
    basic_attrs = add_if_present(basic_attrs, sets, "gender", :string)
    basic_attrs = add_if_present(basic_attrs, sets, "age", :int)
    basic_attrs = add_if_present(basic_attrs, sets, "shen_type", :int)
    basic_attrs = add_if_present(basic_attrs, sets, "score", :int)
    basic_attrs = add_if_present(basic_attrs, sets, "startroom", :string)

    # Aliases
    if aliases != [] do
      basic_attrs = ["  aliases = [#{Enum.map_join(aliases, ", ", &"\"#{&1}\"")}]" | basic_attrs]
    end

    basic_block = if basic_attrs != [], do: Enum.join(Enum.reverse(basic_attrs), "\n") <> "\n", else: ""

    # Brain reference (from inherit or default)
    brain = infer_brain(ast.inherits)
    brain_line = if brain != nil, do: "  brain = brains.#{brain}\n", else: ""

    # Combat config
    combat = build_npc_combat(sets)

    # Goods
    goods = build_goods(sets)

    # Inquiries (handle both "inquiry" and "inquiries")
    inquiries = build_inquiries(sets)

    # Chat
    chat = build_chat(sets)

    # Function calls: skills, map_skill, carry_object, etc.
    function_calls = ast.function_calls
    skills_block = build_skills_block(function_calls)
    carry_block = build_carry_block(function_calls)

    # init() / greeting() / accept_object() / permit_pass() 声明（功能函数抽取）
    init_block = build_enter_ucl(ast.enter)
    greetings_block = build_greetings_ucl(ast.greetings)
    accept_block = build_accept_ucl(ast.accept)
    guarder_block = build_guarder_ucl(ast.guard)
    engage_block = build_engage_ucl(ast.engage)

    ucl <> basic_block <> brain_line <>
      (if combat != "", do: "\n  combat = {\n#{combat}\n  }\n", else: "") <>
      (if goods != [], do: "\n  goods = [\n" <> Enum.map_join(goods, "\n", &"    { id = #{&1} }") <> "\n  ]\n", else: "") <>
      (if inquiries != %{}, do: "\n  inquiries = [\n" <> generate_inquiries(inquiries) <> "\n  ]\n", else: "") <>
      (if chat != nil, do: "\n  #{chat}\n", else: "") <>
      (if skills_block != "", do: "\n#{skills_block}\n", else: "") <>
      (if carry_block != "", do: "\n#{carry_block}\n", else: "") <>
      (if init_block != "", do: "\n#{init_block}\n", else: "") <>
      (if greetings_block != "", do: "\n#{greetings_block}\n", else: "") <>
      (if accept_block != "", do: "\n#{accept_block}\n", else: "") <>
      (if guarder_block != "", do: "\n#{guarder_block}\n", else: "") <>
      (if engage_block != "", do: "\n#{engage_block}\n", else: "") <>
      "    }"
  end

  defp build_enter_ucl(nil), do: ""

  defp build_enter_ucl(init) do
    add_actions = Map.get(init, :add_actions, [])
    heartbeat = Map.get(init, :heartbeat, 0)
    greet_delay = Map.get(init, :greet_delay, 0)

    "  init = {\n" <>
      "    greet_delay = #{greet_delay}\n" <>
      (if heartbeat > 0, do: "    heartbeat = #{heartbeat}\n", else: "") <>
      (if add_actions != [], do: "    add_actions = [#{Enum.map_join(add_actions, ", ", &"\"#{&1}\"")}]\n", else: "") <>
      "  }"
  end

  defp build_greetings_ucl(nil), do: ""
  defp build_greetings_ucl(lines) when is_list(lines) and lines != [] do
    "  greetings = [\n" <>
      Enum.map_join(lines, ",\n", fn line ->
        "    { line = \"#{escape_heredoc_content(line)}\" }"
      end) <> "\n  ]"
  end
  defp build_greetings_ucl(_), do: ""

  defp build_accept_ucl(nil), do: ""
  defp build_accept_ucl(rules) when is_list(rules) and rules != [] do
    "  accept = [\n" <>
      Enum.map_join(rules, ",\n", fn rule ->
        "    { kind = \"#{rule.kind}\"" <>
          (if rule[:min], do: " min = #{rule.min}", else: "") <>
          (if rule[:id], do: " id = \"#{rule.id}\"", else: "") <>
          (if rule[:name], do: " name = \"#{rule.name}\"", else: "") <>
          (if rule[:accept] != nil, do: " accept = #{rule.accept}", else: " accept = true") <>
          (if rule[:msg], do: " msg = \"#{escape_set_string(rule.msg)}\"", else: "") <>
          " }"
      end) <> "\n  ]"
  end
  defp build_accept_ucl(_), do: ""

  defp build_guarder_ucl(nil), do: ""
  defp build_guarder_ucl(guard) when is_map(guard) do
    family = Map.get(guard, :family)
    refuse_other = Map.get(guard, :refuse_other)

    if is_nil(family) do
      ""
    else
      "  meta = {\n" <>
        "    guarder = {\n" <>
          "      family = \"#{family}\"\n" <>
          (if refuse_other, do: "      msgs = { refuse_other = \"#{escape_set_string(refuse_other)}\" }\n", else: "") <>
        "    }\n" <>
      "  }"
    end
  end
  defp build_guarder_ucl(_), do: ""

  # accept_fight/accept_hit/accept_kill：UCL engage 块
  defp build_engage_ucl(nil), do: ""

  defp build_engage_ucl(engage) when is_map(engage) do
    # 只输出 accept 判定的键（accept=nil 的继承/复杂场景不输出运行时规则）
    entries =
      Enum.map(engage, fn {kind, rule} ->
        case rule[:accept] do
          nil ->
            nil

          accept ->
            "    #{kind} = {" <>
              " accept = #{accept}" <>
              (if rule[:msg], do: " msg = \"#{escape_set_string(rule.msg)}\"", else: "") <>
              (if rule[:retaliate], do: " retaliate = true", else: "") <>
              (if rule[:spawn] != [], do: " spawn = [#{Enum.map_join(rule.spawn, ", ", &"\"#{&1}\"")}]", else: "") <>
              " }"
        end
      end)
      |> Enum.reject(&is_nil/1)

    if entries == [] do
      ""
    else
      "  engage = {\n" <> Enum.join(entries, "\n") <> "\n  }"
    end
  end

  defp build_engage_ucl(_), do: ""

  defp build_skills_block(calls) do
    skills = Map.get(calls, "set_skill", [])
    map_skills = Map.get(calls, "map_skill", [])

    cond do
      skills == [] and map_skills == [] -> ""
      true ->
        skill_lines =
          Enum.map(skills, fn
            [{:string, skill}, {:int, level}] -> "    { skill = \"#{skill}\" level = #{level} }"
            [{:string, skill}, {:string, level}] -> "    { skill = \"#{skill}\" level = #{level} }"
            _ -> nil
          end)
          |> Enum.filter(&(&1 != nil))

        map_lines =
          Enum.map(map_skills, fn
            [{:string, type}, {:string, skill}] -> "    { type = \"#{type}\" skill = \"#{skill}\" }"
            _ -> nil
          end)
          |> Enum.filter(&(&1 != nil))

        all_lines = skill_lines ++ map_lines
        if all_lines == [] do
          ""
        else
          """
  skills = [
#{Enum.join(all_lines, ",\n")}
  ]
"""
        end
    end
  end

  defp build_carry_block(calls) do
    carry_objects = Map.get(calls, "carry_object", [])

    cond do
      carry_objects == [] -> ""
      true ->
        items =
          Enum.map(carry_objects, fn
            [{:string, path}] -> "items.#{room_id_from_path(path)}.id"
            [{:var, path}] -> "items.#{room_id_from_path(path)}.id"
            _ -> "items.unknown.id"
          end)

        """
  carry = [
#{Enum.map_join(items, ",\n", &"    { id = #{&1} }")}
  ]
"""
    end
  end

  defp add_if_present(acc, sets, key, type) do
    case Map.get(sets, key) do
      {:string, v} -> ["  #{key} = \"#{escape_set_string(v)}\"" | acc]
      {:int, v} -> ["  #{key} = #{v}" | acc]
      _ -> acc
    end
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
    # Look for inquiry-like mappings (LPC uses "inquiry", we normalize to "inquiries")
    inquiry_data = Map.get(sets, "inquiry") || Map.get(sets, "inquiries")
    case inquiry_data do
      {:mapping, pairs} ->
        Enum.into(pairs, %{}, fn {k, v} ->
          {get_string(k), get_string(v)}
        end)
      _ -> %{}
    end
  end

  defp generate_inquiries(inquiries) do
    # Output as array of objects: [{ key = "..." value = "..." }, ...]
    # UCL/Elias requires no comma between key-value pairs in object literals
    Enum.map(inquiries, fn {q, a} ->
      "    { key = #{q} value = #{a} }"
    end)
    |> Enum.join(",\n")
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