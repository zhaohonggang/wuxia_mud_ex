alias ExKantele.World.Item.Yinzhen, as: Y

ok = fn n, a, b ->
  if a == b, do: IO.puts("PASS #{n}"), else: IO.puts("FAIL #{n}: got #{inspect(a)} want #{inspect(b)}")
end

# ---- init_item ----
ii = Y.init_item()
ok.("ii_id", ii.id, "yinzhen")
ok.("ii_verb", ii.verb, "zhenjiu")
ok.("ii_type", ii.type, "acupuncture_tool")

# fixture base: skilled self-heal target (skill 120 forces success: roll 1..120 <= 120)
healer_base = %{
  id: "h", name: "Healer",
  levels: %{"zhenjiu-shu" => 120, "force" => 0},
  skills: %{"zhenjiu-shu" => true},
  handing: ["yinzhen"], is_player: false, is_npc: false,
  alive: true, busy: false, eff_qi: 100, max_eff_qi: 100, temp: %{}
}

# monotonic_time can be large-negative in a fresh container; use a real far-past
# last use so the success path clears the 60s cooldown deterministically.
healer = %{healer_base | temp: %{"last_zhenjiu_h" => System.monotonic_time(:second) - 1_000_000}}

# ---- can_use? ----
ok.("canuse_qualified", Y.can_use?(healer, nil), true)
ok.("canuse_low", Y.can_use?(%{healer | levels: %{"zhenjiu-shu" => 50, "force" => 0}}, nil), false)

# ---- execute success (deterministic: zhenjiu-shu 120 -> always success) ----
{ok1, res1} = Y.execute(nil, %{player: healer, target: healer})
ok.("succ_type", ok1, :ok)
ok.("succ_heal_type", res1.type, :heal)
ok.("succ_amount", res1.amount, 50 + div(120, 2))  # 110
ok.("succ_target", res1.target, "h")

# ---- execute fail (deterministic: zhenjiu-shu 0 -> roll 1..120 always > 0) ----
lowskill = %{healer | levels: %{"zhenjiu-shu" => 0, "force" => 0}, skills: %{"zhenjiu-shu" => true}}
{ok2, res2} = Y.execute(nil, %{player: lowskill, target: lowskill})
ok.("fail_type", ok2, :ok)
ok.("fail_fail_type", res2.type, :fail)
ok.("fail_target", res2.target, "h")
ok.("fail_dmg_min", res2.damage >= 20, true)

# ---- error branches (one defect at a time) ----

# no skill
noforce = %{healer | levels: %{"force" => 0}, skills: %{}}
{err1, m1} = Y.execute(nil, %{player: noforce, target: noforce})
ok.("err_noskill", {err1, String.contains?(m1, "zhenjiu-shu")}, {:error, true})

# not handing
nohand = %{healer | handing: []}
{er2, m2} = Y.execute(nil, %{player: nohand, target: nohand})
ok.("err_nohand", {er2, String.contains?(m2, "needle")}, {:error, true})

# busy
busy = %{healer | busy: true}
{er3, m3} = Y.execute(nil, %{player: busy, target: busy})
ok.("err_busy", {er3, String.contains?(m3, "busy")}, {:error, true})

# target force too strong (target is player; force >= 300)
strong = %{healer | levels: %{"zhenjiu-shu" => 120, "force" => 300}}
{er4, m4} = Y.execute(nil, %{player: strong, target: strong})
ok.("err_force", {er4, String.contains?(m4, "internal force")}, {:error, true})

# eff_qi too low
weak = %{healer | eff_qi: 2, max_eff_qi: 100}
{er5, m5} = Y.execute(nil, %{player: weak, target: weak})
ok.("err_effqi", {er5, String.contains?(m5, "eff_qi")}, {:error, true})

# cooldown (last use now -> diff < 60)
now = System.monotonic_time(:second)
cool = %{healer | temp: %{"last_zhenjiu_h" => now}}
{er6, m6} = Y.execute(nil, %{player: cool, target: cool})
ok.("err_cooldown", {er6, String.contains?(m6, "cooldown")}, {:error, true})

IO.puts("done")
