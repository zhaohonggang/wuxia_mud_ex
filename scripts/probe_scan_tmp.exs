for %{file: f, status: s} <- Kantele.CommandProbe.scan() do
  IO.puts("#{s}  #{f}")
end
