alias ExKantele.Combat.CombatDaemon, as: C

ok = fn n, a, b ->
  if a == b, do: IO.puts("PASS #{n}"), else: IO.puts("FAIL #{n}: got #{inspect(a)} want #{inspect(b)}")
end

# valid_power
ok.("pow_low", C.valid_power(1_000_000), 1_000_000)
ok.("pow_mid", C.valid_power(2_500_000), 2_050_000)          # 200万 + (250万-200万)/10 = 200万+5万
ok.("pow_hi", C.valid_power(5_000_000), 3_000_000 + div(2_000_000, 20))  # 300万 + 10万

# skill_power
# level 100, exp 1e6: level_pow=100*100*100/10=100000; +valid_power(1e6)=1e6 => 1_100_000
# attack: pow/30*str(30) = div(1_100_000,30)*30 = 1_099_980
ok.("sp_basic", C.skill_power(100, 1_000_000, :attack, %{str: 30}), 1_099_980)
# high level >500 branch: 600 -> 60*600*600 = 21_600_000, div/30*30 = same
ok.("sp_high", C.skill_power(600, 0, :attack, %{str: 30}), 21_600_000)
# low level (<1) fallback: exp 1e6 -> valid_power/2=500000, attack div/30*str
ok.("sp_fallback", C.skill_power(0, 1_000_000, :attack, %{str: 30}), 499_980)

# parry_delta
ok.("pd_fist_vs_weapon", C.parry_delta(false, true), 10)
ok.("pd_weapon_vs_fist", C.parry_delta(true, false), -10)
ok.("pd_same", C.parry_delta(true, true), 0)

# base_damage deterministic
rng1 = fn _ -> 1 end  # random returns 1 -> (damage + 1 - 1)/2
ok.("bd_min", C.base_damage(100, rng1), 50)
ok.("bd_odd", C.base_damage(101, rng1), 50)  # (101+1-1)/2 = 50

# damage_pct
ok.("dpct", C.damage_pct(100, 50), 150)

# vicious
ok.("vicious", C.vicious_bonus(100), 120)

# int_ratio
ok.("int_ratio_effect", C.int_ratio(10, fn _ -> 9 end), 1)   # 10/10 = 1
ok.("int_ratio_no", C.int_ratio(10, fn _ -> 0 end), 0)        # random(10)=0 not >8
ok.("int_ratio_30", C.int_ratio(30, fn _ -> 9 end), 0)        # 7/30 = 0

# damage_cap
ok.("cap_under", C.damage_cap(150), 150)
ok.("cap_250", C.damage_cap(250), 225)   # (250-200)/2+200 = 25+200
ok.("cap_500", C.damage_cap(500), 325)   # (500-400)/4+300 = 25+300

# wound_cap
ok.("wcap_zero", C.wound_cap(0), 0)
ok.("wcap_normal", C.wound_cap(100), 100)

# righteous_wound / con_wound
ok.("righteous", C.righteous_wound(100), 80)
ok.("con", C.con_wound(100, 30), 80)   # 100 - 100*20/100 = 80

# dodge?/parry? deterministic
rnglast = fn n -> n end
ok.("dodge_miss", C.dodge?(50, 50, fn _ -> 100 end), false)  # rand(100)=100 >50
ok.("dodge_ok", C.dodge?(50, 50, rnglast), false)            # rand(100)=100 >50 (<= check false)
ok.("parry_ok", C.parry?(50, 10, fn _ -> 10 end), true)      # rand(60)=10 <=10
ok.("parry_no", C.parry?(50, 10, fn _ -> 11 end), false)     # rand(60)=11 >10

IO.puts("done")
