#!/usr/bin/env elixir
# Usage: mix run classify_file.exs <path>

path = List.first(System.argv())

case Kantele.World.LPCConverter.convert_file(path) do
  {:ok, ucl} ->
    cond do
      String.contains?(ucl, "# Generic LPC file") -> IO.puts("GENERIC")
      String.contains?(ucl, "rooms \"") -> IO.puts("ROOM")
      String.contains?(ucl, "characters \"") -> IO.puts("NPC")
      String.contains?(ucl, "items \"") -> IO.puts("ITEM")
      String.contains?(ucl, "skills \"") -> IO.puts("SKILL")
      true -> IO.puts("UNHANDLED")
    end
  {:error, e} ->
    IO.puts("ERROR: #{inspect(e)}")
end