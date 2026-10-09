#!/usr/bin/env elixir
# scripts/extract_skill_usages_v3.exs
# Fixed extraction of valid_enable usages

defmodule Scripts.ExtractSkillUsagesV3 do
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
    # Collect all usages from different patterns
    pattern1_usages = extract_pattern1(content)
    pattern2_usages = extract_pattern2(content)
    pattern3_usages = extract_pattern3(content)
    pattern4_usages = extract_pattern4(content)
    pattern5_usages = extract_pattern5(content)

    Enum.uniq(pattern1_usages ++ pattern2_usages ++ pattern3_usages ++ pattern4_usages ++ pattern5_usages)
  end

  defp extract_pattern1(content) do
    for match <- Regex.scan(~r/def valid_enable\(usage\)[^)]*\)?\s*,\s*do:\s*(.+)$/m, content),
        [_, body] = match,
        usage <- extract_from_body(body) do
      usage
    end
  end

  defp extract_pattern2(content) do
    for match <- Regex.scan(~r/def valid_enable\("([^"]+)"\)[^)]*\)?\s*,\s*do:\s*true/m, content),
        [_, usage] = match do
      usage
    end
  end

  defp extract_pattern3(content) do
    for match <- Regex.scan(~r/usage in \[([^\]]+)\]/, content),
        [_, list] = match,
        usage <- parse_usage_list(list) do
      usage
    end
  end

  defp extract_pattern4(content) do
    for match <- Regex.scan(~r/def valid_enable\(usage[^)]*\)\s*,\s*do:\s*(.+)$/m, content),
        [_, body] = match,
        usage <- extract_from_body(body) do
      usage
    end
  end

  defp extract_pattern5(content) do
    for match <- Regex.scan(~r/def valid_enable\(usage\)[^)]*\)?\s*do\s*(.+?)\s*end/m, content),
        [_, body] = match,
        usage <- extract_from_multiline_body(body) do
      usage
    end
  end

  defp extract_from_body(body) do
    for match <- Regex.scan(~r/usage\s*==\s*"([^"]+)"/, body), [_, usage] = match do
      usage
    end
    ++ for match <- Regex.scan(~r/usage\s*==\s*'([^']+)'/, body), [_, usage] = match do
      usage
    end
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

Scripts.ExtractSkillUsagesV3.run()