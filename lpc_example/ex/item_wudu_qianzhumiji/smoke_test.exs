alias ExKantele.World.Item.Qianzhumiji, as: Q

ok = fn n, a, b ->
  if a == b, do: IO.puts("PASS #{n}"), else: IO.puts("FAIL #{n}: got #{inspect(a)} want #{inspect(b)}")
end

# ---- init_item / can_read? ----
ii = Q.init_item()
ok.("ii_id", ii.id, "qianzhu_miji")
ok.("ii_type", ii.type, "secret_manual")
ok.("ii_read", Q.can_read?(%{levels: %{"literate" => 1}, skills: %{"literate" => true}}), true)
ok.("ii_unread", Q.can_read?(%{levels: %{}, skills: %{}}), false)

# fully qualified researcher; qianzhu-wandushou 600 ->
#   suck chance = min(5 + div(500,10)*2, 100) = 100 -> deterministic success
qualified = %{
  id: "p", name: "Player",
  levels: %{"literate" => 1, "qianzhu-wandushou" => 600, "hand" => 130, "poison" => 120, "force" => 200},
  skills: %{"literate" => true, "qianzhu-wandushou" => true},
  max_neili: 2000, potential: 10, jing: 100, qi: 100,
  performs: [], temp: %{}
}
ctx = %{player: qualified, args: %{verb: "research", technique: "suck"}}

# ---- success ----
{ok1, res1} = Q.execute(nil, ctx)
ok.("succ_ok", ok1, :ok)
ok.("succ_technique", res1.technique, "suck")
ok.("succ_name", res1.name, "Absorb Poison Cultivation")
ok.("succ_msg", res1.message, "You mastered Absorb Poison Cultivation!")

# verb aliases route to execute too
ok.("ali_yinjiu", elem(Q.yanjiu(nil, ctx), 0), :ok)
ok.("ali_du", elem(Q.du(nil, ctx), 0), :ok)

# ---- error branches ----

# illiterate (checked first)
unlit = %{qualified | levels: Map.delete(qualified.levels, "literate"), skills: Map.delete(qualified.skills, "literate")}
{er1, m1} = Q.execute(nil, %{player: unlit, args: ctx.args})
ok.("err_illit", {er1, String.contains?(m1, "illiterate")}, {:error, true})

# bad verb
{er2, m2} = Q.execute(nil, %{player: qualified, args: %{verb: "foo", technique: "suck"}})
ok.("err_verb", {er2, String.contains?(m2, "Invalid research verb")}, {:error, true})

# bad technique
{er3, m3} = Q.execute(nil, %{player: qualified, args: %{verb: "research", technique: "zzz"}})
ok.("err_technique", {er3, String.contains?(m3, "Unknown technique")}, {:error, true})

# not learned qianzhu-wandushou
noqian = %{qualified | levels: Map.delete(qualified.levels, "qianzhu-wandushou"), skills: Map.delete(qualified.skills, "qianzhu-wandushou")}
{er4, m4} = Q.execute(nil, %{player: noqian, args: ctx.args})
ok.("err_noqian", {er4, String.contains?(m4, "haven't learned")}, {:error, true})

# qianzhu skill too low (< 100)
qianlow = %{qualified | levels: %{qualified.levels | "qianzhu-wandushou" => 50}}
{er5, m5} = Q.execute(nil, %{player: qianlow, args: ctx.args})
ok.("err_skill_low", {er5, String.contains?(m5, "insufficient")}, {:error, true})

# hand too low
handlow = %{qualified | levels: %{qualified.levels | "hand" => 50}}
{er6, m6} = Q.execute(nil, %{player: handlow, args: ctx.args})
ok.("err_hand_low", {er6, String.contains?(m6, "hand technique")}, {:error, true})

# poison too low (suck requires 100)
poislow = %{qualified | levels: %{qualified.levels | "poison" => 50}}
{er7, m7} = Q.execute(nil, %{player: poislow, args: ctx.args})
ok.("err_poison_low", {er7, String.contains?(m7, "poison")}, {:error, true})

# force too low (suck requires 150)
forcelow = %{qualified | levels: %{qualified.levels | "force" => 50}}
{er8, m8} = Q.execute(nil, %{player: forcelow, args: ctx.args})
ok.("err_force_low", {er8, String.contains?(m8, "force")}, {:error, true})

# max_neili too low (suck requires 1000)
neililow = %{qualified | max_neili: 500}
{er9, m9} = Q.execute(nil, %{player: neililow, args: ctx.args})
ok.("err_neili_low", {er9, String.contains?(m9, "max neili")}, {:error, true})

# already mastered (perform key uses tech.name = "Absorb Poison Cultivation")
mastered = %{qualified | performs: ["qianzhu-wandushou/Absorb Poison Cultivation"]}
{er10, m10} = Q.execute(nil, %{player: mastered, args: ctx.args})
ok.("err_mastered", {er10, String.contains?(m10, "already mastered")}, {:error, true})

# insufficient resources
poor = %{qualified | potential: 0}
{er11, m11} = Q.execute(nil, %{player: poor, args: ctx.args})
ok.("err_resources", {er11, String.contains?(m11, "Insufficient potential/jing/qi")}, {:error, true})

# default verb/technique (args without verb/technique)
{er12, _} = Q.execute(nil, %{player: unlit, args: %{}})
ok.("err_default_verb_ok", er12, :error)

IO.puts("done")
