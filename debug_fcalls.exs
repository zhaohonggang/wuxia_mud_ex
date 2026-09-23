defmodule DebugFCalls do
  def find_matching_brace(content, start_pos) do
    find_matching_brace_loop(content, start_pos, 1, start_pos + 1)
  end

  defp find_matching_brace_loop(content, _start_index, brace_count, i) do
    if i > String.length(content) - 1 do
      ""
    else
      char = String.at(content, i)
      cond do
        char == "{" -> find_matching_brace_loop(content, _start_index, brace_count + 1, i + 1)
        char == "}" ->
          if brace_count - 1 == 0 do
            String.slice(content, _start_index + 1, i - _start_index - 1)
          else
            find_matching_brace_loop(content, _start_index, brace_count - 1, i + 1)
          end
        char == "\"" ->
          case find_quote_end(content, i + 1) do
            nil -> find_matching_brace_loop(content, _start_index, brace_count, i + 1)
            new_i -> find_matching_brace_loop(content, _start_index, brace_count, new_i)
          end
        true -> find_matching_brace_loop(content, _start_index, brace_count, i + 1)
      end
    end
  end

  defp find_quote_end(content, start) do
    find_quote_end_loop(content, start)
  end

  defp find_quote_end_loop(content, i) do
    if i >= String.length(content) do
      nil
    else
      char = String.at(content, i)
      cond do
        char == "\\" -> find_quote_end_loop(content, i + 2)
        char == "\"" -> i + 1
        true -> find_quote_end_loop(content, i + 1)
      end
    end
  end

  def parse_function_calls(body) do
    Regex.scan(~r/(\w+)\s*\(([^)]*)\)\s*;/, body)
    |> Enum.map(fn [_, func, args_str] ->
      args =
        args_str
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.map(fn arg ->
          parse_lpc_value(arg)
        end)
      {func, args}
    end)
    |> Enum.into(%{})
  end

  defp parse_lpc_value(value_str) do
    value_str = String.trim(value_str)
    cond do
      String.starts_with?(value_str, "\"") && String.ends_with?(value_str, "\"") ->
        {:string, parse_lpc_string(value_str)}
      String.match?(value_str, ~r/^\d+$/) ->
        {:int, String.to_integer(value_str)}
      String.match?(value_str, ~r/^\d+\.\d+$/) ->
        {:float, String.to_float(value_str)}
      String.starts_with?(value_str, "({") && String.ends_with?(value_str, "})") ->
        {:array, []}
      String.starts_with?(value_str, "([") && String.ends_with?(value_str, "])") ->
        {:mapping, []}
      String.match?(value_str, ~r/^\w+\(.*\)$/) ->
        {:call, value_str}
      true ->
        {:var, value_str}
    end
  end

  defp parse_lpc_string(value_str) do
    segments =
      Regex.scan(~r/"((?:\\.|[^"\\])*)"/, value_str)
      |> Enum.map(fn [_, seg] -> seg end)
    Enum.join(segments)
  end
end

content = File.read!("test_minimal_world_v2_modified/npc/furen.c")

case Regex.run(~r/void\s+create\s*\(\s*\)\s*\{/, content) do
  nil -> IO.puts("No create")
  [match] ->
    parts = String.split(content, match, parts: 2)
    case parts do
      [before, rest] ->
        open_brace_pos = String.length(before) + String.length(match) - 1
        body = DebugFCalls.find_matching_brace(content, open_brace_pos)
        IO.puts("Body length: #{String.length(body)}")

        calls = DebugFCalls.parse_function_calls(body)
        IO.inspect(calls, limit: :infinity)
    end
end