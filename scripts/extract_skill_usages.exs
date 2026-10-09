#!/usr/bin/env elixir
# scripts/extract_skill_usages.exs
# Extract valid_enable usages from skill module source files

defmodule Scripts.ExtractSkillUsages do
  @skills_dir "lib/kantele/combat/skills"

  def run do
    skill_files = Path.wildcard(Path.join(@skills_dir, "*.ex"))
    |> Enum.filter(fn f -> not String.ends_with?(f, "/skills.ex") end)
    |> Enum.sort()

    usages = Enum.reduce(skill_files, %{}, fn file, acc ->
      skill = Path.basename(file, ".ex")
      content = File.read!(file)
      skill_usages = extract_usages(content)
      Map.put(acc, skill, skill_usages)
    end)

    # Output as Elixir map for use in tests
    IO.puts("SKILL_USAGES = %{")
    Enum.each(usages, fn {skill, usage_list} ->
      primary = get_primary_usage(usage_list)
      IO.puts("  \"#{skill}\" => \"#{primary}\",")
    end)
    IO.puts("}")
  end

  defp extract_usages(content) do
    # Match valid_enable function: def valid_enable(usage), do: usage == "sword" or usage == "parry"
    # or: def valid_enable("sword"), do: true
    # or: def valid_enable(usage), do: usage in ["sword", "parry"]

    usages = []

    # Pattern 1: def valid_enable(usage), do: usage == "xxx" or usage == "yyy"
    for match <- Regex.scan(~r/def valid_enable\(usage\),\s*do:\s*(.+)$/m, content) do
      [_, body] = match
      usages = usages ++ extract_from_body(body)
    end

    # Pattern 2: def valid_enable("xxx"), do: true (multiple clauses)
    for match <- Regex.scan(~r/def valid_enable\("([^"]+)"\),\s*do:\s*true/m, content) do
      [_, usage] = match
      usages = usages ++ [usage]
    end

    # Pattern 3: def valid_enable(usage), do: usage in ["xxx", "yyy"]
    for match <- Regex.scan(~r/usage in \[([^\]]+)\]/, content) do
      [_, list] = match
      usages = usages ++ (list |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.map(&String.replace(&1, "\"", "")) |> Enum.map(&String.replace(&1, "'", "")))
    end

    Enum.uniq(usages)
  end

  defp extract_from_body(body) do
    # Parse expressions like: usage == "sword" or usage == "parry"
    usages = []
    for match <- Regex.scan(~r/usage\s*==\s*"([^"]+)"/, body) do
      [_, usage] = match
      usages = usages ++ [usage]
    end
    for match <- Regex.scan(~r/usage\s*==\s*'([^']+)'/, body) do
      [_, usage] = match
      usages = usages ++ [usage]
    end
    usages
  end

  defp get_primary_usage(usages) do
    # Prefer weapon usages
    preferred = Enum.find(usages, & &1 in ["sword", "blade", "staff", "whip", "hammer", "axe", "throwing"])
    preferred || (if usages != [], do: hd(usages), else: "unarmed")
  end
end

Scripts.ExtractSkillUsages.run()