defmodule ParseOrderSmoke do
  def run() do
    cases = [
      {"learn force 王重九", Kantele.Character.LearnCommand},
      {"l", Kantele.Character.LookCommand},
      {"look", Kantele.Character.LookCommand},
      {"commands", Kantele.Character.CommandsCommand},
      {"i", Kantele.Character.InventoryCommand}
    ]

    Enum.each(cases, fn {text, expected_module} ->
      case Kantele.Character.Commands.parse(text) do
        {:ok, parsed} ->
          status =
            if parsed.module == expected_module do
              "OK"
            else
              "WRONG #{inspect(parsed.module)}"
            end

          IO.puts("#{status}: #{text} -> #{inspect(parsed.module)}.#{parsed.function}")

        other ->
          IO.puts("FAIL: #{text} => #{inspect(other)}")
      end
    end)
  end
end

ParseOrderSmoke.run()
