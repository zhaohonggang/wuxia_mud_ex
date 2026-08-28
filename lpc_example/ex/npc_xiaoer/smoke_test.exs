alias ExKantele.World.Npc.Xiaoer, as: X

ok = fn n, a, b ->
  if a == b, do: IO.puts("PASS #{n}"), else: IO.puts("FAIL #{n}: got #{inspect(a)} want #{inspect(b)}")
end

contains = fn str, sub -> String.contains?(str, sub) end

# ---------- init_npc ----------
npc = X.init_npc()
ok.("init_id", npc.id, "xiaoer")
ok.("init_name", npc.name, "Waiter")
ok.("init_level", npc.level, 10)
ok.("init_title", npc.title, "Inn Waiter")
ok.("init_str", npc.stats.str, 20)
ok.("init_cooking", npc.skills["cooking"], 100)
ok.("init_service", npc.skills["service"], 100)
ok.("init_greetings_len", length(npc.greetings), 4)
ok.("init_inventory", npc.inventory, [])

# ---------- greet ----------
{g0, gr} = X.greet(%{id: "p1"})
ok.("greet_ok", g0, :ok)
ok.("greet_speaker", gr.speaker, "xiaoer")
ok.("greet_valid", gr.message in ["Welcome! What would you like to order?", "Good to see you! The usual?", "Come in, come in! Best food in town!", "Hey there! Hungry? Thirsty?"], true)

# ---------- accept_object ----------
money = %{id: "gold", type: "money", amount: 50}
{a0, a1} = X.accept_object(%{id: "p1", temp: %{}}, money)
ok.("accept_money_ok", a0, :ok)
ok.("accept_money_amount", a1.money_received, 50)
ok.("accept_money_msg", a1.message |> contains.("Thank"), true)

corpse = %{id: "corpse1", type: "corpse"}
{c0, c1} = X.accept_object(%{id: "p1"}, corpse)
ok.("accept_corpse_ok", c0, :ok)
ok.("accept_corpse_flag", c1.corpse_disposed, true)

ok.("accept_other", X.accept_object(%{id: "p1"}, %{id: "stone"}), {:error, "I don't need this item."})

# ---------- handle_money (sets rent_paid temp) ----------
p = %{id: "p1", temp: %{}}
returned = X.handle_money(p, %{type: "money", amount: 75})
ok.("handle_money_received", elem(returned, 1).money_received, 75)
ok.("handle_money_msg", elem(returned, 1).message |> contains.("75"), true)

# ---------- handle_corpse ----------
ok.("handle_corpse_disposed", elem(X.handle_corpse(%{}, corpse), 1).corpse_disposed, true)

# ---------- handle_drop ----------
{d0, d1} = X.handle_drop(%{}, corpse)
ok.("drop_corpse_ok", d0, :ok)
ok.("drop_corpse_removed", d1.corpse_removed, true)
ok.("drop_other", X.handle_drop(%{}, %{id: "stone"}), {:error, "You can't leave that here."})

# ---------- list_exchange ----------
items = X.list_exchange()
ok.("list_len", length(items), 8)
bb = Enum.find(items, &(&1.name == "blood_bodhi"))
ok.("list_blood_cost", bb.cost, 5)
ok.("list_blood_item", bb.item, "pill/puti1")
rp = Enum.find(items, &(&1.name == "rebirth_pill"))
ok.("list_rebirth_cost", rp.cost, 50)

# ---------- exchange ----------
rich = %{id: "p1", points: 20, items: []}
{ex0, ex1} = X.exchange(rich, "blood_bodhi")
ok.("exchange_ok", ex0, :ok)
ok.("exchange_item_name", ex1.item, "Blood Bodhi")
ok.("exchange_cost", ex1.cost, 5)
ok.("exchange_remaining", ex1.remaining_points, 15)
ok.("exchange_can_afford", ExKantele.World.Player.points(rich) >= 5, true)

poor = %{id: "p1", points: 2, items: []}
{p0, p1} = X.exchange(poor, "blood_bodhi")
ok.("exchange_insufficient_err", p0, :error)
ok.("exchange_insufficient_msg", p1 |> contains.("Insufficient"), true)

ok.("exchange_unknown", X.exchange(rich, "nope"), nil)

# ---------- heart_beat ----------
ok.("heart_beat", X.heart_beat(), :ok)

IO.puts("done")
