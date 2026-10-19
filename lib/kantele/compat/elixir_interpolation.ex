if Version.compare(System.version(), "1.20.0") != :lt do
  defmodule :elixir_interpolation do
    @moduledoc false

    # Compatibility shim for Elixir 1.20+, where :elixir_interpolation.unescape_chars/1
    # was removed. The Elixir parser already handles escape sequences in interpolated
    # strings, so this is a pass-through.
    #
    # Guarded by version on purpose: on Elixir < 1.20 the stdlib still ships the real
    # :elixir_interpolation module (extract/6, unescape_string/2, ...). Redeclaring it
    # here would shadow those functions and break the compiler while tokenizing
    # `"""` heredocs and `~r`/`~s` sigils.
    def unescape_chars(string) when is_binary(string), do: string
  end
end
