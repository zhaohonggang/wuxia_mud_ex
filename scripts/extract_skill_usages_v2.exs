#!/usr/bin/env elixir
# scripts/extract_skill_usages_v2.exs
# Improved extraction of valid_enable usages

defmodule Scripts.ExtractSkillUsagesV2 do
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

    IO.puts("SKILL_USAGES = %{")
    Enum.each(usages, fn {skill, usage_list} ->
      primary = get_primary_usage(usage_list)
      IO.puts("  \"#{skill}\" => \"#{primary}\",")
    end)
    IO.puts("}")
  end

  defp extract_usages(content) do
    usages = []

    # Pattern 1: def valid_enable(usage), do: usage == "xxx" or usage == "yyy"
    for match <- Regex.scan(~r/def valid_enable\(usage\)[^)]*\)?\s*,\s*do:\s*(.+)$/m, content) do
      [_, body] = match
      usages = usages ++ extract_from_body(body)
    end

    # Pattern 2: def valid_enable("xxx"), do: true (multiple clauses)
    for match <- Regex.scan(~r/def valid_enable\("([^"]+)"\)[^)]*\)?\s*,\s*do:\s*true/m, content) do
      [_, usage] = match
      usages = usages ++ [usage]
    end

    # Pattern 3: def valid_enable(usage), do: usage in ["xxx", "yyy"]
    for match <- Regex.scan(~r/usage in \[([^\]]+)\]/, content) do
      [_, list] = match
      usages = usages ++ parse_usage_list(list)
    end

    # Pattern 4: def valid_enable(usage, level), do: ... (with extra params)
    for match <- Regex.scan(~r/def valid_enable\(usage[^)]*\)\s*,\s*do:\s*(.+)$/m, content) do
      [_, body] = match
      usages = usages ++ extract_from_body(body)
    end

    # Pattern 5: def valid_enable(usage) do ... end (multi-line)
    for match <- Regex.scan(~r/def valid_enable\(usage\)[^)]*\)?\s*do\s*(.+?)\s*end/m, content) do
      [_, body] = match
      usages = usages ++ extract_from_multiline_body(body)
    end

    Enum.uniq(usages)
  end

  defp extract_from_body(body) do
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

  defp extract_from_multiline_body(body) do
    extract_from_body(body)
  end

  defp parse_usage_list(list_str) do
    list_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.replace(&1, "\"", ""))
    |> Enum.map(&String.replace(&1, "'", ""))
    |> Enum.map(&String.trim/1)
  end

  defp get_primary_usage(usages) do
    preferred = Enum.find(usages, & &1 in ["sword", "blade", "staff", "whip", "hammer", "axe", "throwing"])
    preferred || (if usages != [], do: hd(usages), else: "unarmed")
  end
end

Scripts.ExtractSkillUsagesV2.run()