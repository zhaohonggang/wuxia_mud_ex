files = System.argv()

bad =
  Enum.reduce(files, 0, fn f, acc ->
    src = File.read!(f)

    result =
      try do
        case Elias.parse(src) do
          {:error, e} ->
            IO.puts("ERROR #{inspect(e)}")
            1

          _ ->
            IO.puts("OK")
            0
        end
      rescue
        e ->
          IO.puts("RAISED #{Exception.message(e)}")
          1
      end

    acc + result
  end)

IO.puts("failures: #{bad}")
