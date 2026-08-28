alias ExKantele.World.Npc.Horseboss, as: H

ok = fn n, a, b ->
  if a == b, do: IO.puts("PASS #{n}"), else: IO.puts("FAIL #{n}: got #{inspect(a)} want #{inspect(b)}")
end

contains = fn str, sub -> String.contains?(str, sub) end

# ---------------- init_npc ----------------
npc = H.init_npc()
ok.("init_id", npc.id, "horseboss")
ok.("init_name", npc.name, "Pet Shop Owner")
ok.("init_level", npc.level, 20)
ok.("init_training", npc.skills["training"], 400)
ok.("init_title", npc.title, "Mount Merchant")

# ---------------- species_info ----------------
sp = H.species_info()
ok.("species_len", length(sp), 20)
horse = Enum.find(sp, &(&1.key == :horse))
ok.("species_horse_name", horse.name, "Horse")
ok.("species_horse_unit", horse.unit, "match")
ok.("species_horse_str", horse.base_stats.str, 30)
ok.("species_beast_str", Enum.find(sp, &(&1.key == :beast)).base_stats.str, 50)

# ---------------- start_purchase ----------------
low = %{id: "p1", levels: %{"training" => 10}}
ok.("start_low_err", elem(H.start_purchase(low), 0), :error)
high = %{id: "p1", levels: %{"training" => 100}}
{sp0, sp1} = H.start_purchase(high)
ok.("start_high_ok", sp0, :ok)
ok.("start_step", sp1.step, :choose_species)
ok.("start_price", sp1.price, 1_000_000)
ok.("start_species_len", length(sp1.species_list), 20)

# ---------------- greet ----------------
ok.("greet_low_canbuy", elem(H.greet(low), 1).can_buy, false)
ok.("greet_high_canbuy", elem(H.greet(high), 1).can_buy, true)
ok.("greet_price", elem(H.greet(high), 1).price, 1_000_000)

# ---------------- choose_species ----------------
ok.("cs_valid_step", elem(H.choose_species(high, :horse), 1).step, :choose_gender)
ok.("cs_valid_species", elem(H.choose_species(high, :lion), 1).species, :lion)
ok.("cs_valid_data", elem(H.choose_species(high, :horse), 1).species_data.name, "Horse")
ok.("cs_invalid", elem(H.choose_species(high, :dragon), 0), :error)

# ---------------- choose_gender ----------------
ok.("cg_male", elem(H.choose_gender(high, "male"), 1).gender, "male")
ok.("cg_m", elem(H.choose_gender(high, "m"), 1).gender, "male")
ok.("cg_f", elem(H.choose_gender(high, "f"), 1).gender, "female")
ok.("cg_female", elem(H.choose_gender(high, "Female"), 1).gender, "female")
ok.("cg_invalid", {elem(H.choose_gender(high, "x"), 0), elem(H.choose_gender(high, "x"), 1)}, {:error, "Gender must be 'male' or 'female'."})

# ---------------- choose_id ----------------
wizard = %{id: "p1", name: "P", temp: %{chosen_species: :horse, pet_gender: "male", pet_id: "myhorse", pet_name: "小黑"}}
ok.("id_short", {elem(H.choose_id(wizard, "ab"), 0)}, {:error})
ok.("id_invalid_char", {elem(H.choose_id(wizard, "Ab1"), 0)}, {:error})
ok.("id_invalid_space", {elem(H.choose_id(wizard, "my horse"), 0)}, {:error})
ok.("id_valid_step", elem(H.choose_id(wizard, "myhorse"), 1).step, :choose_name)
ok.("id_valid_petid", elem(H.choose_id(wizard, "myhorse"), 1).pet_id, "myhorse")
Process.put({:item_exists, "taken ma"}, true)
ok.("id_taken", {elem(H.choose_id(wizard, "taken"), 0), elem(H.choose_id(wizard, "taken"), 1)}, {:error, "This ID is already taken."})
Process.delete({:item_exists, "taken ma"})

# ---------------- choose_name ----------------
ok.("name_short", {elem(H.choose_name(high, "a"), 0)}, {:error})
ol = String.duplicate("黑", 13)
ok.("name_long", {elem(H.choose_name(high, ol), 0)}, {:error})
ok.("name_ascii", {elem(H.choose_name(high, "abc"), 0), elem(H.choose_name(high, "abc"), 1) |> contains.("Chinese")}, {:error, true})
ok.("name_valid_step", elem(H.choose_name(high, "小黑"), 1).step, :choose_desc)
ok.("name_valid_petname", elem(H.choose_name(high, "小黑"), 1).pet_name, "小黑")

# ---------------- choose_desc / build_pet ----------------
long_desc = String.duplicate("a", 61)
ok.("desc_long", {elem(H.choose_desc(wizard, long_desc), 0)}, {:error})
{bd0, bd1} = H.choose_desc(wizard, "A swift northern steed.")
mount = bd1.mount
ok.("build_ok", bd0, :ok)
ok.("mount_id", mount.id, "myhorse ma")
ok.("mount_name", mount.name, "小黑Horse")
ok.("mount_species", mount.species, "Horse")
ok.("mount_gender", mount.gender, "male")
ok.("mount_unit", mount.unit, "match")
ok.("mount_type", mount.type, "mount")
ok.("mount_owner", mount.owner, "p1")
ok.("mount_owner_name", mount.owner_name, "P")
ok.("mount_rideable", mount.rideable, true)
ok.("mount_trained", mount.trained, true)
ok.("mount_summon_id", mount.summon_id, "myhorse ma")
ok.("mount_desc_owner", mount.description |> contains.("belongs to P"), true)
ok.("mount_str_range", mount.stats.str >= 1 and mount.stats.str <= 40, true)
ok.("mount_has_stats", Map.keys(mount.stats) |> Enum.all?(&(&1 in [:str, :con, :dex, :int])), true)
ok.("build_msg", bd1.message |> contains.("小黑"), true)

# build with a female lion to sanity check another species
lw = %{id: "p2", name: "Q", temp: %{chosen_species: :lion, pet_gender: "female", pet_id: "king", pet_name: "阿黄"}}
{bl0, bl1} = H.choose_desc(lw, "A proud lion.")
ok.("lion_id", bl1.mount.id, "king shi")
ok.("lion_species", bl1.mount.species, "Lion")
ok.("lion_name", bl1.mount.name, "阿黄Lion")
ok.("lion_gender", bl1.mount.gender, "female")
ok.("lion_owner", bl1.mount.owner, "p2")

IO.puts("done")
