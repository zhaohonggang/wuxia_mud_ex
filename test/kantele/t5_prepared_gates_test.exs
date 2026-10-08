defmodule Kantele.T5PreparedGatesTest do
  use ExUnit.Case

  @performs_dir "lib/kantele/combat/skills/performs"

  test "T5: update all perform specs with correct :prepared gate usage" do
    perform_files = find_perform_files(@performs_dir)
    |> Enum.sort()

    by_skill = Enum.group_by(perform_files, fn file ->
      Path.basename(Path.dirname(file))
    end)

Enum.each(by_skill, fn {skill, files} ->
      usage = get_skill_usage(skill)
      move_name = get_move_name(skill)

      Enum.each(files, fn file ->
        update_prepared_gate(file, skill, usage, move_name)
      end)
    end)

    # Verify all specs have correct usage
    verify_all_specs(by_skill)
  end

  defp find_perform_files(dir) do
    File.ls!(dir)
    |> Enum.flat_map(fn entry ->
      path = Path.join(dir, entry)
      if File.dir?(path) do
        find_perform_files(path)
      else
        if String.ends_with?(entry, ".ex"), do: [path], else: []
      end
    end)
  end

  defp skill_module_name(skill) do
    camel = skill
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join()
    "Kantele.Combat.Skills.#{camel}"
  end

  defp get_skill_usage(skill) do
    Kantele.SkillUsages.get(skill)
  end

  defp get_move_name(skill) do
    case skill do
      "huashan_jian" -> "华山剑法"
      "liuxin_jian" -> "柳心剑法"
      "chousui_zhang" -> "抽髓掌"
      "taiji_quan" -> "太极拳"
      "dugu_jiujian" -> "独孤九剑"
      _ -> skill
    end
  end

  defp update_prepared_gate(file, skill, usage, move_name) do
    content = File.read!(file)

    if String.contains?(content, "def spec()") do
      lines = String.split(content, "\n", trim: false)
      new_lines = Enum.map(lines, fn line ->
        if String.contains?(line, "{:prepared,") and String.contains?(line, "unarmed") do
          String.replace(line, "\"unarmed\"", "\"#{usage}\"")
        else
          line
        end
      end)

      new_lines2 = Enum.map(new_lines, fn line ->
        if String.contains?(line, "你尚未预备") and String.contains?(line, skill) do
          String.replace(line, "你尚未预备#{skill}", "你尚未预备#{move_name}")
        else
          line
        end
      end)

      new_content = Enum.join(new_lines2, "\n")

      if new_content != content do
        File.write!(file, new_content)
      end
    end
  end

  defp verify_all_specs(by_skill) do
    Enum.each(by_skill, fn {skill, files} ->
      Enum.each(files, fn file ->
        content = File.read!(file)
        if String.contains?(content, "def spec()") do
          case Regex.run(~r/{:prepared,\s*"([^"]+)",/, content) do
            [_, usage] ->
              expected_usage = get_skill_usage(skill)
              assert usage == expected_usage, "Skill #{skill} perform #{Path.basename(file)} has usage #{usage}, expected #{expected_usage}"
            nil ->
              flunk("No :prepared gate found in #{file}")
          end
        end
      end)
    end)
  end
end