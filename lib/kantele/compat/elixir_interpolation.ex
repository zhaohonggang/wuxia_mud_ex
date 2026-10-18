defmodule :elixir_interpolation do
  @moduledoc false

  # Compatibility shim for Elixir 1.20+, where :elixir_interpolation.unescape_chars/1
  # was removed. The Elixir parser already handles escape sequences in interpolated
  # strings, so this is a pass-through.
  def unescape_chars(string) when is_binary(string), do: string
end
