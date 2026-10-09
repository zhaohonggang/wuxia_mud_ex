#!/usr/bin/env elixir
# scripts/check_extractor_coverage.exs
# D7: Extractor coverage protection - runs extractor against all known skill files
# and ensures no crashes. Can be run with: mix run scripts/check_extractor_coverage.exs

Code.require_file("translate_skill.exs", __DIR__)

defmodule Scripts.CheckExtractorCoverage do
  @fixtures_dir "/app/scripts/fixtures/kungfu/skill"

  def run do
    skill_files = Path.wildcard(Path.join(@fixtures_dir, "*.c"))
    |> Enum.sort()

    if skill_files == [] do
      IO.puts("No skill files found in #{@fixtures_dir}")
      System.halt(1)
    end

    IO.puts("=== Extractor Coverage Check ===")
    IO.puts("Testing #{length(skill_files)} skill files...")

    results = Enum.map(skill_files, fn file ->
      skill = Path.basename(file, ".c")
      try do
        data = TranslateSkill.extract(file)
        {:ok, skill, data}
      rescue
        e ->
          {:error, skill, Exception.message(e)}
      end
    end)

    ok_count = Enum.count(results, &match?({:ok, _, _}, &1))
    error_count = Enum.count(results, &match?({:error, _, _}, &1))

    IO.puts("\nResults: #{ok_count} OK, #{error_count} errors")

    Enum.each(results, fn
      {:ok, skill, data} ->
        IO.puts("  ✓ #{skill}: #{length(data.actions)} static actions, #{data.dynamic_actions} dynamic, enable=#{inspect(data.valid_enable)}, cost=#{inspect(data.practice_cost)}")
      {:error, skill, msg} ->
        IO.puts("  ✗ #{skill}: #{msg}")
    end)

    if error_count > 0 do
      System.halt(1)
    else
      IO.puts("\nAll skill files processed successfully!")
      System.halt(0)
    end
  end
end

Scripts.CheckExtractorCoverage.run()