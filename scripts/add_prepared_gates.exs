#!/usr/bin/env elixir
# scripts/add_prepared_gates.exs
# T5: Add :prepared gates to perform specs

defmodule Scripts.AddPreparedGates do
  @performs_dir "lib/kantele/combat/skills/performs"

  def run do
    perform_files = find_perform_files(@performs_dir)
    |> Enum.sort()

    IO.puts("Found #{length(perform_files)} perform files")

    # Group by skill (parent directory)
    by_skill = Enum.group_by(perform_files, fn file ->
      Path.basename(Path.dirname(file))
    end)

    Enum.each(by_skill, fn {skill, files} ->
      IO.puts("\n--- #{skill} ---")
      skill_module = skill_module_name(skill)
      usage = get_skill_usage(skill_module)

      Enum.each(files, fn file ->
        add_prepared_gate(file, skill, usage)
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
    # e.g., huashan_jian -> Kantele.Combat.Skills.HuashanJian
    camel = skill
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join()
    "Kantele.Combat.Skills.#{camel}"
  end

  defp get_skill_usage(skill_module) do
    # Ensure the skill module is loaded
    module_atom = String.to_atom(skill_module)
    unless Code.ensure_loaded?(module_atom) do
      # Try to load it - skill_module is like "Kantele.Combat.Skills.BaishengDaofa"
      # Need to convert to file name: "baisheng_daofa.ex"
      skill_file = skill_module
      |> String.replace("Kantele.Combat.Skills.", "")
      |> Macro.underscore()
      |> Kernel.<>(".ex")
      case Code.require_file(skill_file, "lib/kantele/combat/skills") do
        {^module_atom, _} -> :ok
        _ -> :error
      end
    end

    # Test valid_enable with known usage strings
    known_usages = ["sword", "blade", "staff", "whip", "hammer", "axe", "throwing",
                    "parry", "dodge", "unarmed", "force", "finger", "cuff", "strike"]

    try do
      if Code.ensure_loaded?(module_atom) and function_exported?(module_atom, :valid_enable, 1) do
        usages = Enum.filter(known_usages, fn u ->
          try do
            module_atom.valid_enable(u)
          rescue
            _ -> false
          end
        end)

        if usages != [] do
          # Prefer weapon usages over parry
          Enum.find(usages, & &1 in ["sword", "blade", "staff", "whip", "hammer", "axe", "throwing"]) || hd(usages)
        else
          "unarmed"
        end
      else
        "unarmed"
      end
    rescue
      _ -> "unarmed"
    end
  end

  defp add_prepared_gate(file, skill, usage) do
    content = File.read!(file)
    perform_id = get_perform_id(content) || "#{skill}/#{Path.basename(file, ".ex")}"

    # Check if spec already exists
    if String.contains?(content, "def spec()") do
      IO.puts("  #{Path.basename(file)}: already has spec")
      :ok
    else
      # Add spec function before the last `end`
      spec = """
  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "#{perform_id}",
      kind: :perform,
      gates: [
        {:prepared, "#{usage}", "你尚未预备#{skill}#{perform_id |> get_move_name()}，无法施展。\\n"}
      ],
      costs: %{},
      effects: [],
      busy: 0
    }
  end

"""
      # Insert before last `end`
      lines = String.split(content, "\n", trim: false)
      insert_at = Enum.find_index(Enum.reverse(lines), &String.match?(&1, ~r/^\s*end\s*$/))
      if insert_at do
        insert_at = length(lines) - insert_at - 1
        new_lines = List.insert_at(lines, insert_at, spec)
        new_content = Enum.join(new_lines, "\n")
        File.write!(file, new_content)
        IO.puts("  #{Path.basename(file)}: added spec with :prepared gate (usage=#{usage})")
      else
        IO.puts("  #{Path.basename(file)}: could not find insertion point")
      end
    end
  end

  defp get_perform_id(content) do
    case Regex.run(~r/@perform_id\s+"([^"]+)"/, content) do
      [_, id] -> id
      _ -> nil
    end
  end

  defp get_move_name(perform_id) do
    case String.split(perform_id, "/") do
      [_, move] -> "的#{move}"
      _ -> ""
    end
  end
end

Scripts.AddPreparedGates.run()