defmodule ValidateUCL do
  def main([path]) do
    content = File.read!(path)
    checks = [
      check_encoding(content),
      check_syntax(content),
      check_structure(content),
      check_integrity(content),
      check_chars(content)
    ]
    
    failed = Enum.filter(checks, &match?({:fail, _}, &1))
    if failed == [] do
      IO.puts("✅ All checks passed: #{path}")
      System.halt(0)
    else
      Enum.each(failed, fn {:fail, msg} -> IO.puts("❌ #{msg}") end)
      System.halt(1)
    end
  end

  defp check_encoding(content) do
    if String.valid?(content) && !String.starts_with?(content, <<0xFF, 0xFE>>) &&
       !String.contains?(content, "\r") do
      {:ok, "UTF-8, no BOM, no CRLF"}
    else
      {:fail, "Encoding: must be UTF-8, no BOM, LF only"}
    end
  end

  defp check_syntax(content) do
    case Elias.parse(content) do
      {:ok, _} -> {:ok, "Elias.parse OK"}
      {:error, err} -> {:fail, "Syntax: #{inspect(err)}"}
    end
  end

  defp check_structure(content) do
    has_zone = String.match?(content, ~r/zones\s+"\w+"/)
    has_rooms = String.match?(content, ~r/rooms\s+"\w+"/)
    has_exits = String.match?(content, ~r/room_exits\s+"\w+"/)
    if has_zone && has_rooms && has_exits do
      {:ok, "Structure: zone/rooms/exits present"}
    else
      {:fail, "Structure: missing zone/rooms/exits"}
    end
  end

  defp check_integrity(content) do
    rooms = Regex.scan(~r/rooms\s+"(\w+)"/, content, capture: :first) |> Enum.count()
    exits = Regex.scan(~r/room_exits\s+"(\w+)"/, content, capture: :first) |> Enum.count()
    if rooms == exits && rooms > 0 do
      {:ok, "Integrity: #{rooms} rooms, #{exits} exits match"}
    else
      {:fail, "Integrity: rooms(#{rooms}) != exits(#{exits})"}
    end
  end

  defp check_chars(content) do
    issues = []
    if String.match?(content, ~r/^\s*}\s*}/m) do
      issues = ["孤立双闭合括号 } }"]
    end
    if String.match?(content, ~r/,\s*}/m) do
      issues = issues ++ ["闭合括号前多余逗号 , }"]
    end
    quote_count = String.graphemes(content) |> Enum.count(&(&1 == "\""))
    if rem(quote_count, 2) != 0 do
      issues = issues ++ ["引号不成对"]
    end
    if issues == [] do
      {:ok, "Chars: no stray braces/commas, quotes balanced"}
    else
      {:fail, "Chars: #{Enum.join(issues, "; ")}"}
    end
  end
end

ValidateUCL.main(System.argv())