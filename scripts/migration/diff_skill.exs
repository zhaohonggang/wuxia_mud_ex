#!/usr/bin/env elixir
# scripts/migration/diff_skill.exs
# 对比生成的骨架与现有实现，生成 diff 报告

defmodule Migration.DiffSkill do
  @generated_root "tmp/skill_out"
  @impl_root "lib/kantele/combat/skills"

  def run(skill_id \\ nil) do
    skills = if skill_id do
      [skill_id]
    else
      Path.wildcard(Path.join(@generated_root, "*.ex"))
      |> Enum.map(&Path.basename(&1, ".ex"))
      |> Enum.map(&String.replace(&1, "_", "-"))
      |> Enum.sort()
    end

    Enum.each(skills, fn skill ->
      diff_skill(skill)
    end)
  end

  defp diff_skill(skill_id) do
    gen_file = Path.join(@generated_root, skill_dir(skill_id) <> ".ex")
    impl_file = Path.join(@impl_root, skill_dir(skill_id) <> ".ex")

    gen_exists = File.exists?(gen_file)
    impl_exists = File.exists?(impl_file)

    case {gen_exists, impl_exists} do
      {true, true} ->
        gen = File.read!(gen_file)
        impl = File.read!(impl_file)
        diff = generate_diff(gen, impl, skill_id)
        write_report(skill_id, diff)

      {true, false} ->
        IO.puts("🆕 NEW: #{skill_id} (generated only)")

      {false, true} ->
        IO.puts("⚠️  ORPHAN: #{skill_id} (impl only)")

      {false, false} ->
        IO.puts("❓ MISSING: #{skill_id}")
    end
  end

  defp generate_diff(gen, impl, skill_id) do
    # 提取关键部分对比
    gen_parts = extract_parts(gen)
    impl_parts = extract_parts(impl)

    diffs = []

    # 对比各部分
    for key <- [:id, :valid_enable, :practice_cost, :actions, :perform_list, :exert_list, :query_action] do
      gen_val = Map.get(gen_parts, key)
      impl_val = Map.get(impl_parts, key)

      if gen_val != impl_val do
        diffs = [{:diff, key, gen_val, impl_val} | diffs]
      end
    end

    # 检查 impl 中独有的部分
    impl_only = Map.keys(impl_parts) -- Map.keys(gen_parts)
    for key <- impl_only do
      diffs = [{:impl_only, key, Map.get(impl_parts, key)} | diffs]
    end

    diffs
  end

  defp extract_parts(code) do
    parts = %{
      id: extract_between(code, "def id(), do: ", "\n"),
      valid_enable: extract_between(code, "def valid_enable", "end\n"),
      practice_cost: extract_between(code, "def practice_cost", "end\n"),
      actions: extract_between(code, "@actions", "]"),
      perform_list: extract_between(code, "def perform_list", "end\n"),
      exert_list: extract_between(code, "def exert_list", "end\n"),
      query_action: extract_between(code, "def query_action", "end\n")
    }
    Map.drop(parts, fn _k, v -> is_nil(v) or v == "" end)
  end

  defp extract_between(code, start_marker, end_marker) do
    case Regex.run(~r/#{Regex.escape(start_marker)}(.*?)#{Regex.escape(end_marker)}/ms, code) do
      [_, content] -> String.trim(content)
      _ -> nil
    end
  end

  defp skill_dir(skill_id) do
    String.replace(skill_id, "-", "_")
  end

  defp write_report(skill_id, diffs) do
    if diffs != [] do
      filename = "tmp/migration_diff_#{skill_dir(skill_id)}.md"
      content = "# Diff Report: #{skill_id}\n\n"
      content = content <> Enum.map_join(diffs, "\n", fn
        {:diff, key, gen, impl} ->
          "## #{key}\n**Generated:**\n```\n#{gen}\n```\n\n**Impl:**\n```\n#{impl}\n```\n"
        {:impl_only, key, val} ->
          "## #{key} (Impl Only)\n```\n#{val}\n```\n"
      end)
      File.write!(filename, content)
      IO.puts("📝 Diff written: #{filename}")
    else
      IO.puts("✅ #{skill_id}: No diffs")
    end
  end
end

Migration.DiffSkill.run()