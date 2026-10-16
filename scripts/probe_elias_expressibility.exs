# UCL/elias expressibility probe — the authority for "can this even be written?"
#
# Why this exists
# ---------------
# `docs/data-world-converted-ucl-comments.zh-CN.md` §2 states several reasons why
# the converter skipped things, e.g. "direction is not ASCII; elias's Word token is
# ASCII-only, so this key cannot be lexed".  That claim is FALSE against the elias
# version actually pinned in mix.lock: `data/world/shaolin.ucl` carries 32 lines of
# CJK exit keys (`乾 = rooms.bagua7.id`) and they lex and survive Elias.parse/1.
#
# So before deciding "this needs a framework first", test it here.  Do not trust the
# archived docs' stated blockers.
#
# Run inside the container (mix is not on the host):
#   docker exec -w /app wuxia_mud_dev-app-1 mix run --no-start scripts/probe_elias_expressibility.exs
#
# Read-only: parses strings only, never touches data/world.

# Build a multi-line snippet from lines (avoids escaping a literal backslash-n).
ml = fn lines -> Enum.join(lines, "\n") end

cases = [
  # --- keys -----------------------------------------------------------------
  {"key plain ascii",              ~s|room_exits "h" { room_id = rooms.a.id  qian = rooms.b.id }|},
  {"key CJK (bagua)",              ~s|room_exits "h" { room_id = rooms.a.id  qian = rooms.b.id  乾 = rooms.c.id }|},
  {"key ends in digit",            ~s|room_exits "h" { room_id = rooms.a.id  hole_1 = rooms.b.id }|},
  {"key digit inside",             ~s|room_exits "h" { room_id = rooms.a.id  hole1 = rooms.b.id }|},
  {"key digit + underscore",       ~s|room_exits "h" { room_id = rooms.a.id  hole_a = rooms.b.id }|},
  {"key with hyphen",              ~s|room_exits "h" { room_id = rooms.a.id  x-y = rooms.b.id }|},
  {"key quoted",                   ~s|room_exits "h" { room_id = rooms.a.id  "乾" = rooms.b.id }|},

  # --- commas / whitespace (the big one) ------------------------------------
  {"list quoted, comma+space",     ~s|items "i" { aliases = ["a", "b"] }|},
  {"list bare refs, no space",     ~s|rooms "r" { t = [rooms.a.id,rooms.b.id] }|},
  {"list bare refs, comma+space",  ~s|rooms "r" { t = [rooms.a.id, rooms.b.id] }|},
  {"map entries, whitespace sep",  ~s|items "i" { meta = { a = 1  b = 2 } }|},
  {"map entries, comma sep",       ~s|items "i" { meta = { a = 1,b = 2 } }|},
  {"map entries, comma+space",     ~s|items "i" { meta = { a = 1, b = 2 } }|},
  {"trailing comma in list",       ~s|rooms "r" { t = ["a","b",] }|},
  # --- list separators inside a room block (B1 regression) -------------------
  # The hand-written `flags` precedent in data/world/city.ucl has only ONE item,
  # so it never exercised the separator.  Two newline-separated items with no
  # comma are REJECTED -- that bug shipped once and had to be rolled back.
  {"flags 1 item, multi-line",     ml.(["rooms \"r\" {", "  name = \"x\"", "  flags = [", "    \"no_fight\"", "  ]", "}"])},
  {"flags 2 items, multi-line NO comma", ml.(["rooms \"r\" {", "  name = \"x\"", "  flags = [", "    \"a\"", "    \"b\"", "  ]", "}"])},
  {"flags 2 items, multi-line w/ comma", ml.(["rooms \"r\" {", "  name = \"x\"", "  flags = [", "    \"a\",", "    \"b\"", "  ]", "}"])},
  {"flags 3 items, single-line",   ~s|rooms "r" { flags = ["a", "b", "c"] }|},

  # --- value shapes ---------------------------------------------------------
  {"nested mapping",               ~s|characters "c" { inquiries = [ { id = "x"  value = { kind = "smith"  pattern = "huwan" } } ] }|},
  {"list of mappings",             ~s|rooms "r" { actions = [ { v = "a"  h = "M" } ] }|},
  {"deep nested mapping",          ~s|items "i" { meta = { a = { b = { c = 1 } } } }|},
  {"float",                        ~s|items "i" { meta = { value = 1.5 } }|},
  {"negative int",                 ~s|items "i" { meta = { value = -5 } }|},
  {"boolean true",                 ~s|rooms "r" { all_dirs = true }|},
  {"empty list",                   ~s|rooms "r" { tags = [] }|},
  {"tilde sentinel",               ~s|rooms "r" { direction = ~ }|},

  # --- strings --------------------------------------------------------------
  {"single-quoted string",         ~s|rooms "r" { d = 'abc' }|},
  {"string w/ parens+comma tight", ~s|rooms "r" { c = "objectp(present('ao bai',environment(me))) && dir == 'north'" }|},
  {"string w/ comma+space",        ~s|rooms "r" { c = "objectp(present('ao bai', environment(me)))" }|},
  {"string w/ comma+space+digit",  ~s|rooms "r" { d = "abc, 1 def" }|},
  {"nested escaped quote",         ~s|rooms "r" { d = "he said \\"hi\\"" }|},
  {"CJK value",                    ~s|rooms "r" { name = "鳌府大厅" }|},
]

IO.puts(String.duplicate("=", 92))
IO.puts("elias expressibility probe   (elias #{Application.spec(:elias, :vsn) |> to_string()})")
IO.puts(String.duplicate("=", 92))

for {label, src} <- cases do
  res =
    try do
      case Elias.parse(src) do
        {:ok, v} -> "OK   " <> inspect(v, limit: :infinity, printable_limit: 300)
        {:error, e} -> "FAIL " <> inspect(e, limit: 4, printable_limit: 90)
        other -> "OK?  " <> inspect(other, limit: 4, printable_limit: 150)
      end
    rescue
      e -> "FAIL " <> Exception.message(e)
    end

  ok = String.starts_with?(res, "OK")
  IO.puts("#{if ok, do: "  ok ", else: "  NO "}#{String.pad_trailing(label, 30)} #{res}")
end

IO.puts(String.duplicate("=", 92))
IO.puts("""
Legend / what to do with a FAIL:
  key shape fails        -> pick a naming scheme FIRST (e.g. hole_a not hole_1)
  float fails            -> decide a representation FIRST (string? scaled int?)
  comma+space fails      -> write [a,b] with NO space (existing data already does this)
  multi-line list w/o comma fails -> that is CORRECT behaviour: put a comma between
                            items.  A single item needs no separator, so a 1-item
                            precedent tells you nothing -- always test with >= 2.
  anything else fails    -> the value needs a schema decision before conversion
""")
