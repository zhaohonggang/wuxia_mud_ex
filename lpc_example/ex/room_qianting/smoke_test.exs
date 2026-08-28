alias ExKantele.World.Room.Qianting, as: Q

ok = fn n, a, b ->
  if a == b, do: IO.puts("PASS #{n}"), else: IO.puts("FAIL #{n}: got #{inspect(a)} want #{inspect(b)}")
end

# NOTE: Qianting's greeter branches use LPC-style object dot-calls
# (laopu.owner?(player) / laopu.is_owner?(player)) which do not run on plain
# maps in Elixir; those branches need a framework `laopu` object and are not
# unit-testable. This suite covers the pure gate state machine and the
# map-safe surface (laopu.living / laopu.present / player.name / player.shen
# are plain map fields).

ir = Q.init_room()
ok.("r_init_gate", ir.gate, :close)
ok.("r_init_exits_no_north", "north" in ir.exits, false)
ok.("r_init_laopu_living", ir.laopu_living, true)

player = %{name: "Huang", shen: 1000}
# laopu as a plain map: only .living / .present fields are read in the
# map-safe paths we exercise here.
laopu_present = %{living: true, present: true}
laopu_absent = %{living: false, present: false}

# ---- do_push error branch (gate already open; no laopu/player interaction) ----
state_open = %{ir | gate: :open, exits: ["south", "east", "west", "north"]}
re_push = Q.do_push(state_open, player, laopu_present)
ok.("push_err_when_open", elem(re_push, 0), :error)

# ---- do_close error branch (gate already closed) ----
re_close = Q.do_close(ir, player, laopu_present, false)
ok.("close_err_when_closed", elem(re_close, 0), :error)

# ---- auto_close_timer: gate closed -> noop (no laopu interaction) ----
ac_closed = Q.auto_close_timer(ir, laopu_present)
ok.("auto_close_closed_noop", elem(ac_closed, 0), :noop)
ok.("auto_close_closed_same_state", elem(ac_closed, 1).gate, :close)

# ---- check_valid_leave: map-safe branches ----
ok.("leave_non_north", Q.check_valid_leave(ir, player, "south", laopu_present), {:passthrough})
ok.("leave_north_laopu_dead", Q.check_valid_leave(ir, player, "north", laopu_absent), {:passthrough})

# ---- generate_long (pure, state + laopu_present bool) ----
gl_open  = Q.generate_long("BASE", state_open, true)
gl_close = Q.generate_long("BASE", ir, false)
ok.("gen_long_starts", String.starts_with?(gl_open, "BASE"), true)
# 大门病开 (open), 大门缕闭 (closed)
ok.("gen_long_open_text", String.contains?(gl_open, "\u{5927}\u{95E8}\u{75C5}\u{5F00}"), true)
ok.("gen_long_close_text", String.contains?(gl_close, "\u{5927}\u{95E8}\u{7DFC}\u{95ED}"), true)
# each line padded to width 60 -> result = "BASE" (4) + sort_string 60 = 64 chars
ok.("gen_long_open_width", String.length(gl_open), 4 + 60)
ok.("gen_long_close_width", String.length(gl_close), 4 + 60)

IO.puts("done")
