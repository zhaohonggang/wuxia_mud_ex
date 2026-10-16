# Probe: exactly which comma forms elias 0.2.8 rejects inside a quoted UCL value.
# (B5b writes LPC equipment messages verbatim; some contain ASCII commas.)
#   MSYS_NO_PATHCONV=1 docker exec -w /app wuxia_mud_dev-app-1 \
#     mix run --no-start scripts/probe_ucl_brackets.exs

vals = [
  {"comma + CJK (no space)",    "{npc}解开{name},把{name}从身上脱了下来。"},
  {"comma + space + CJK",       "{npc}解开{name}, 把{name}从身上脱了下来。"},
  {"comma + ascii letter",      "{npc}解开{name},and{name}。"},
  {"comma + space + letter",    "{npc}解开{name}, and {name}。"},
  {"comma + digit",             "{npc}脱下第1,2件{name}。"},
  {"comma + space + digit",     "{npc}脱下第 1, 2 件{name}。"},
  {"CJK comma",                 "{npc}解开{name}，把{name}从身上脱了下来。"},
  {"fullwidth comma + space",   "{npc}解开{name}， 把{name}从身上脱了下来。"}
]

Enum.each(vals, fn {label, v} ->
  ucl = "messages = {\n  wear = \"" <> v <> "\"\n}\n"

  result =
    try do
      case Elias.parse(ucl) do
        {:error, e} -> "FAIL: #{inspect(e)}"
        %{} = _ -> "OK"
        other -> "OK(#{inspect(other)})"
      end
    rescue
      e -> "RAISE: #{Exception.message(e)}"
    end

  IO.puts("[" <> String.pad_trailing(label, 24) <> "] " <> result)
end)
