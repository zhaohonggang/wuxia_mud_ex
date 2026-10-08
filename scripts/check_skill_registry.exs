defmodule Scripts.CheckSkillRegistry do
  @skills_dir "lib/kantele/combat/skills"
  @skills_mod_file "lib/kantele/combat/skills.ex"

  @non_skill_keys ~w(action attack damage damage_type dodge lvl parry skill_name
    force martial martial-cognize throwing unarmed weaponed)a

  def run do
    skills_ex = File.read!(@skills_mod_file)
    static_keys = extract_static_keys(skills_ex)

    module_files =
      Path.wildcard(Path.join(@skills_dir, "*.ex"))
      |> Enum.reject(&String.ends_with?(&1, "/skills.ex"))
      |> Enum.sort()

    file_keys =
      module_files
      |> Enum.map(fn f -> module_name_to_skill_id(Path.basename(f, ".ex")) end)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    static_set = MapSet.new(static_keys)
    missing = MapSet.difference(file_keys, static_set) |> Enum.sort()
    extra = MapSet.difference(static_set, file_keys) |> Enum.sort()

    IO.puts("=== Skill Registry Check ===")
    IO.puts("modules: #{MapSet.size(file_keys)}  static: #{MapSet.size(static_set)}")

    if missing != [] do
      IO.puts("\nMISSING in @static (#{length(missing)}):")
      Enum.each(missing, &IO.puts("  - #{&1}"))
    else
      IO.puts("\nOK: all modules registered")
    end

    if extra != [] do
      IO.puts("\nEXTRA in @static (#{length(extra)}):")
      Enum.each(extra, &IO.puts("  - #{&1}"))
    else
      IO.puts("\nOK: no extra keys")
    end

    if missing == [] and extra == [], do: System.halt(0), else: System.halt(1)
  end

  defp extract_static_keys(text) do
    # Extract lines between @static %{ and the closing }
    lines = String.split(text, "\n")
    in_static = false
    static_keys = []

    Enum.reduce_while(lines, {in_static, static_keys}, fn line, {in_block, acc} ->
      cond do
        String.contains?(line, "@static %") ->
          {:cont, {true, acc}}
        in_block and String.trim(line) == "}" ->
          {:halt, {false, acc}}
        in_block ->
          # Match "key" => Module,
          case Regex.run(~r/"([a-z0-9][a-z0-9_-]+)"\s*=>/, line) do
            [_, key] -> {:cont, {in_block, [key | acc]}}
            _ -> {:cont, {in_block, acc}}
          end
        true ->
          {:cont, {in_block, acc}}
      end
    end)
    |> elem(1)
    |> Enum.reverse()
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp module_name_to_skill_id(module_name) do
    # Convert Elixir module name to kebab-case skill_id
    # e.g., LiuxinJian -> liuxin-jian, TaijiShengong -> taiji-shengong
    # Special handling: known prefixes
    module_name
    |> Macro.underscore()
    |> String.replace_suffix("_skill", "")
    |> String.replace("_", "-")
    |> maybe_skip()
  end

  defp maybe_skip(id) do
    # Skip perform modules that are not skills
    if id in @non_skill_keys or String.starts_with?(id, "force-") do
      nil
    else
      id
    end
  end
end

Scripts.CheckSkillRegistry.run()