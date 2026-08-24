defmodule OrderProbe do
  def run() do
    m = Kantele.Character.Commands

    look_first = [:parse_look_run, :parse_l_run, :parse_learn_run]
    learn_first = [:parse_learn_run, :parse_look_run, :parse_l_run]

    Enum.each([{"look_first", look_first}, {"learn_first", learn_first}], fn {label, order} ->
      result = Kalevala.Character.Command.Router.parse(m, order, "learn force 王重九")

      case result do
        {:ok, pc} -> IO.puts("#{label}: #{inspect(pc.module)} #{pc.function}")
        other -> IO.puts("#{label}: #{inspect(other)}")
      end
    end)
  end
end

OrderProbe.run()
