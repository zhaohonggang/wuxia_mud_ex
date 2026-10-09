#!/usr/bin/env elixir
# scripts/update_prepared_gates.exs
# T5: Update :prepared gates in perform specs with correct usage

# Ensure application is started
Application.ensure_all_started(:ex_venture)

# Force load all skill modules from their .beam files
Path.wildcard("_build/test/lib/ex_venture/ebin/Elixir.Kantele.Combat.Skills.*.beam")
|> Enum.each(fn beam ->
  module = beam
  |> Path.basename()
  |> String.replace(".beam", "")
  |> String.to_atom()
  Code.ensure_loaded?(module)
end)

defmodule Scripts.UpdatePreparedGates do
  @performs_dir "lib/kantele/combat/skills/performs"

  def run do
    perform_files = find_perform_files(@performs_dir)
    |> Enum.sort()

    IO.puts("Found #{length(perform_files)} perform files")

    by_skill = Enum.group_by(perform_files, fn file ->
      Path.basename(Path.dirname(file))
    end)

    Enum.each(by_skill, fn {skill, files} ->
      IO.puts("\n--- #{skill} ---")
      skill_module = skill_module_name(skill)
      usage = get_skill_usage(skill_module)
      move_name = get_move_name(skill)

      Enum.each(files, fn file ->
        update_prepared_gate(file, skill, usage, move_name)
      end)
    end)
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

  defp get_skill_usage(skill_module) do
    module_atom = String.to_atom(skill_module)

    # Try to call valid_enable directly - if module isn't loaded, it will raise
    known_usages = ["sword", "blade", "staff", "whip", "hammer", "axe", "throwing",
                    "parry", "dodge", "unarmed", "force", "finger", "cuff", "strike"]

    try do
      # Force module loading by calling a function
      if function_exported?(module_atom, :valid_enable, 1) do
        usages = Enum.filter(known_usages, fn u ->
          try do
            result = module_atom.valid_enable(u)
            result
          rescue
            _ -> false
          end
        end)

        if usages != [] do
          Enum.find(usages, & &1 in ["sword", "blade", "staff", "whip", "hammer", "axe", "throwing"]) || hd(usages)
        else
          "unarmed"
        end
      else
        "unarmed"
      end
    rescue
      e ->
        "unarmed"
    end
  end

  defp get_move_name(skill) do
    # Return Chinese name if available, otherwise skill name
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
      # Find and replace the prepared gate line
      lines = String.split(content, "\n", trim: false)
      IO.puts("  DEBUG: processing #{Path.basename(file)}, usage=#{usage}")
      new_lines = Enum.map(lines, fn line ->
        if String.contains?(line, "{:prepared,") and String.contains?(line, "unarmed") do
          IO.puts("  DEBUG: found prepared line: #{line}")
          new_line = String.replace(line, "\"unarmed\"", "\"#{usage}\"")
          IO.puts("  DEBUG: replaced to: #{new_line}")
          new_line
        else
          line
        end
      end)

      # Also update the message if it contains the skill directory name
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
        IO.puts("  #{Path.basename(file)}: updated usage to #{usage}")
      else
        IO.puts("  #{Path.basename(file)}: no change needed")
      end
    else
      IO.puts("  #{Path.basename(file)}: no spec found")
    end
  end
end

Scripts.UpdatePreparedGates.run()