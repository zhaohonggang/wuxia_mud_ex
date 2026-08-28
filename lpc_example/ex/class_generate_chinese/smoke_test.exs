alias ExKantele.World.NameGenerator, as: NG

ok = fn n, a, b ->
  if a == b, do: IO.puts("PASS #{n}"), else: IO.puts("FAIL #{n}: got #{inspect(a)} want #{inspect(b)}")
end

# ---- table dispatch ----
male = NG.given_table("男性")
female = NG.given_table("女性")
ok.("gt_male_nonempty", map_size(male) > 0, true)
ok.("gt_female_nonempty", map_size(female) > 0, true)
ok.("gt_male_ai", male["ai"], "皑哀蔼隘埃瑷嫒捱")
ok.("gt_female_ai", female["ai"], "嫒爱")
ok.("gt_female_hui", female["hui"], "惠慧彗荟")
# gender other than "女性" -> male table
ok.("gt_other_male", NG.given_table("男")["ai"], male["ai"])

# ---- rng forcing single-char given name (rng.(3) == 2 != 1) ----
# single-char surname -> length 2, double-char surname -> length 3
single_rng = fn n -> if n == 3, do: 2, else: 1 end
{name1, py1} = NG.random_name("男性", single_rng)
ok.("single_is_binary", is_binary(name1), true)
len1 = String.length(name1)
ok.("single_len", len1 == 2 or len1 == 3, true)
ok.("single_py2", length(py1), 2)
# pinyin differ (surname pinyin != given pinyin)
ok.("single_py_distinct", Enum.at(py1, 0) != Enum.at(py1, 1), true)

# ---- rng forcing double-char given name (rng.(3) == 1), but
#      a fixed-1 rng would infinitely recurse in pick_distinct,
#      so use :rand.uniform for the pinyin picks ----
double_rng = fn n -> if n == 3, do: 1, else: :rand.uniform(n) end
{name2, py2} = NG.random_name("女性", double_rng)
len2 = String.length(name2)
ok.("double_len", len2 >= 3 and len2 <= 4, true)
ok.("double_py2", length(py2), 2)

# ---- structural invariants across several runs ----
Enum.each(1..20, fn i ->
  {nm, pys} = NG.random_name("男性", fn n -> :rand.uniform(n) end)
  if is_binary(nm) and is_list(pys) and length(pys) == 2 do
    IO.puts("PASS loop_#{i}")
  else
    IO.puts("FAIL loop_#{i}: got #{inspect({nm, pys})}")
  end
end)

IO.puts("done")
