#!/usr/bin/env elixir
# Usage: mix run batch_classify.exs <file_list>

file_list = List.first(System.argv())

files = File.read!(file_list) |> String.split("\n", trim: true)

Enum.each(files, fn f ->
  case Kantele.World.LPCConverter.convert_file(f) do
    {:ok, ucl} ->
      cond do
        String.contains?(ucl, "# Generic LPC file") -> IO.puts("GENERIC: #{f}")
        String.contains?(ucl, "rooms \"") -> :ok
        String.contains?(ucl, "characters \"") -> :ok
        String.contains?(ucl, "items \"") -> :ok
        String.contains?(ucl, "skills \"") -> :ok
        true -> IO.puts("UNHANDLED: #{f}")
      end
    {:error, e} ->
      IO.puts("ERROR: #{f} - #{inspect(e)}")
  end
end)