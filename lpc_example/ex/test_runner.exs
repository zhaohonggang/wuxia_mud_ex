# Unified smoke-test runner for the migrated lpc_example/ex sample suites.
#
# It discovers every <sample>/smoke_test.exs, compiles ONLY the modules those
# suites need (each suite dir's `*.ex` + `test_support/*.ex` doubles) into a
# scratch beam dir, then runs every suite and reports a clean per-suite +
# aggregate summary. Compiler warnings and per-suite detail are captured and
# hidden unless a suite fails.
#
# Run inside the container with the full source tree present (see README):
#   elixir /tmp/runner/test_runner.exs
# Exit code is non-zero if any suite fails or fails to compile.

defmodule Runner do
  @pass_re ~r/^PASS /
  @fail_re ~r/^FAIL /

  def main(root) do
    suites =
      Path.wildcard(Path.join([root, "**", "smoke_test.exs"]))
      |> Enum.map(&Path.relative_to(&1, root))
      |> Enum.sort()

    if suites == [] do
      IO.puts("No smoke_test.exs suites found under #{root}")
      System.halt(2)
    end

    out_dir = Path.join(System.tmp_dir!(), "runner_out_#{System.unique_integer([:positive])}")
    File.mkdir_p!(out_dir)

    try do
      compile_sources(root, suites, out_dir)
      results = Enum.map(suites, &run_suite(root, out_dir, &1))
      report(results)
      failed = Enum.count(results, &(elem(&1, 4) == false))
      System.halt(if failed > 0, do: 1, else: 0)
    after
      File.rm_rf!(out_dir)
    end
  end

  defp compile_sources(root, suites, out_dir) do
    suite_dirs = suites |> Enum.map(&Path.dirname/1) |> Enum.uniq()

    source_files =
      (Path.wildcard(Path.join([root, "test_support", "*.ex"])) ++
         Enum.flat_map(suite_dirs, fn d -> Path.wildcard(Path.join([root, d, "*.ex"])) end))
      |> Enum.uniq()

    {_output, status} = System.cmd("elixirc", ["-o", out_dir | source_files], stderr_to_stdout: true)

    if status != 0 do
      IO.puts("COMPILE FAILED for source modules (status #{status}):")
      IO.puts("  " <> Enum.join(source_files, "\n  "))
      System.halt(2)
    end
  end

  defp run_suite(root, out_dir, suite) do
    path = Path.join(root, suite)
    {output, code} = System.cmd("elixir", ["-pa", out_dir, path], stderr_to_stdout: true)
    lines = String.split(output, ~r/\n/)

    passes = Enum.count(lines, &Regex.match?(@pass_re, &1))
    fails = Enum.count(lines, &Regex.match?(@fail_re, &1))
    errors = Enum.filter(lines, &String.starts_with?(&1, "RUNNER-ERROR"))
    crashed = code != 0 && fails == 0

    passed = fails == 0 and errors == [] and code == 0

    if not passed do
      IO.puts("\n----- #{suite} [FAILED] -----")
      for l <- lines, Regex.match?(@fail_re, l) or String.starts_with?(l, "** (") do
        IO.puts("  #{l}")
      end
      if crashed do
        IO.puts("  <suite process exited non-zero: #{code}>")
      end
      IO.puts("-----")
    end

    {suite, passes, fails, errors, passed}
  end

  defp report(results) do
    IO.puts("\n" <> String.duplicate("=", 54))
    IO.puts("          UNIFIED SMOKE-RUN SUMMARY (#{length(results)} suites)")
    IO.puts(String.duplicate("=", 54))

    total_pass = Enum.sum(Enum.map(results, &elem(&1, 1)))
    total_fail = Enum.sum(Enum.map(results, &elem(&1, 2)))
    clean = Enum.count(results, &elem(&1, 4))

    for {suite, passes, fails, _errors, passed} <- results do
      status = if passed, do: "PASS", else: "FAIL"
      IO.puts("  #{status}   #{String.pad_trailing(suite, 46)} #{pad(passes)}P / #{pad(fails)}F")
    end

    IO.puts(String.duplicate("-", 54))
    IO.puts("  TOTAL  #{total_pass} assertions passed, #{total_fail} failed")
    IO.puts("  SUITE  #{clean}/#{length(results)} clean")
  end

  defp pad(n), do: String.pad_leading(Integer.to_string(n), 3)
end

Runner.main(Path.expand(".", __DIR__))
