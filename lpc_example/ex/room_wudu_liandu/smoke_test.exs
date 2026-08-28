alias ExKantele.World.Room.WuduLiandu, as: W

ok = fn n, a, b ->
  if a == b, do: IO.puts("PASS #{n}"), else: IO.puts("FAIL #{n}: got #{inspect(a)} want #{inspect(b)}")
end

contains = fn str, sub -> String.contains?(str, sub) end

# ---------------- init_room ----------------
room = W.init_room()
ok.("room_id", room.id, "liandu_shi")
ok.("room_name", room.name, "Poison Crafting Room")
ok.("room_no_fight", room.no_fight, true)
ok.("room_exit", room.exits["north"], "nanyuan")
ok.("room_npcs", room.npcs, ["daoren"])

# ---------------- start_crafting ----------------
craft = %{
  id: "p1", name: "P",
  faction: "Five Poisons Sect",
  levels: %{"wudu-qishu" => 80, "poison" => 40},
  jing: 100, qi: 100,
  items: ["du nang", "shexin zi", "qianri zui"],
  temp: %{},
  busy: false, int: 20,
  environment_id: "liandu_shi",
  potential: 100
}

ok.("craft_bad_faction", W.start_crafting(%{craft | faction: "Shaolin"}, "heding hong"), {:error, "You don't know how to start."})
ok.("craft_already", W.start_crafting(%{craft | temp: %{"liandu/recipe" => "hedinghong"}}, "heding hong"), {:error, "You are already crafting. Don't get distracted."})
ok.("craft_busy", {elem(W.start_crafting(%{craft | busy: true}, "heding hong"), 0)}, {:error})
ok.("craft_low_skill", {elem(W.start_crafting(%{craft | levels: %{"wudu-qishu" => 30}}, "heding hong"), 0)}, {:error})
ok.("craft_low_vitals", {elem(W.start_crafting(%{craft | jing: 40}, "heding hong"), 0)}, {:error})
ok.("craft_missing_ing", W.start_crafting(%{craft | items: ["du nang", "shexin zi"]}, "heding hong"), {:error, "Missing ingredient: qianri zui."})
ok.("craft_unknown", W.start_crafting(craft, "nope"), nil)

{sc0, sc1} = W.start_crafting(craft, "heding hong")
ok.("craft_ok", sc0, :ok)
ok.("craft_msg", sc1.message |> contains.("Crane Top Red"), true)
ok.("craft_time", sc1.time >= 15, true)

# ---------------- liandu_callback: early returns ----------------
ok.("cb_no_recipe", W.liandu_callback(%{craft | temp: %{}, environment_id: "liandu_shi"}), :ok)
ok.("cb_wrong_env", W.liandu_callback(%{craft | temp: %{"liandu/recipe" => "hedinghong"}, environment_id: "elsewhere"}), :ok)

# ---------------- liandu_callback: full path ----------------
recipe_temp = %{"liandu/recipe" => "hedinghong", "liandu/level_bonus" => 0, "liandu/duration" => 15}
# seed RNG for reproducible-ish outcome; accept either success or failure structurally
:rand.seed(:exsplus, {101, 102, 103})
{cb0, cb1} = W.liandu_callback(%{craft | temp: recipe_temp, environment_id: "liandu_shi"})
ok.("cb_ok", cb0, :ok)
ok.("cb_msg_present", is_binary(cb1.message), true)
if contains.(cb1.message, "successful") do
  ok.("cb_product", cb1.product, "Heding Hong")
  ok.("cb_exp_int", is_integer(cb1.exp), true)
  ok.("cb_pot_int", is_integer(cb1.pot), true)
  ok.("cb_score_int", is_integer(cb1.score), true)
  ok.("cb_msg_product", contains.(cb1.message, "Heding Hong"), true)
else
  ok.("cb_failure_msg", contains.(cb1.message, "failed"), true)
end

# second run (fresh seed not needed) -- just verify it completes
{cb2_0, _} = W.liandu_callback(%{craft | temp: recipe_temp, environment_id: "liandu_shi"})
ok.("cb_second_runs", cb2_0, :ok)

IO.puts("done")
