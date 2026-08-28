alias ExKantele.World.Npc.Luban, as: L

ok = fn n, a, b ->
  if a == b, do: IO.puts("PASS #{n}"), else: IO.puts("FAIL #{n}: got #{inspect(a)} want #{inspect(b)}")
end

# room_example
ok.("rex_len", length(L.room_example()), 3)
ok.("rex_names", L.room_example() |> Enum.map(& &1.name), ["独乐居", "彩虹居", "盘龙居"])
ok.("rex_value", Enum.find(L.room_example(), &(&1.type == "dule")).value, 20_000_000)
ok.("rex_panlong_files", Enum.find(L.room_example(), &(&1.type == "panlong")).files |> map_size(), 22)

# check_legal_type (by type and by name)
ok.("type_by_code", L.check_house_type("caihong").name, "彩虹居")
ok.("type_by_name", L.check_house_type("独乐居").type, "dule")
ok.("type_none", L.check_house_type("bogus"), nil)

# str_width: 独乐居 = 3 CJK = 6 width
ok.("width_cjk", L.str_width("独乐居"), 6)
ok.("width_ascii", L.str_width("hello"), 5)
ok.("width_mixed", L.str_width("a独"), 3)

# check_room_name
ok.("name_ok", L.check_room_name("我的大宅"), :ok)
ok.("name_short", L.check_room_name("宅"), {:error, "对不起，你房屋的名字必须是 2 到 6 个中文字。"})
ok.("name_long", L.check_room_name("一二三四五六七八九十"), {:error, "对不起，你房屋的名字必须是 2 到 6 个中文字。"})
ok.("name_ascii", L.check_room_name("hello"), {:error, "对不起，请您用「中文」为房屋取名字。"})

# check_room_id
ok.("id_ok", L.check_room_id("myhouse"), :ok)
ok.("id_short", L.check_room_id("ab"), {:error, "对不起，你房屋的代号必须是 3 到 10 个英文字母。"})
ok.("id_long", L.check_room_id("abcdefghijk"), {:error, "对不起，你房屋的代号必须是 3 到 10 个英文字母。"})
ok.("id_badchar", L.check_room_id("ab1"), {:error, "对不起，你房屋的代号必须用英文字母。"})
ok.("id_banned", L.check_room_id("north"), {:error, "不要起这种名字！免得人家误会。"})

# obey_description
ok.("desc_empty", L.obey_description(""), {:ok, ""})
ok.("desc_nil", L.obey_description(nil), {:ok, ""})
{:ok, d} = L.obey_description("hi $RED$there")
ok.("desc_ansi", d, "hi\e[31mthere\e[0m")
{:ok, d2} = L.obey_description("a\tb c")
ok.("desc_clean", d2, "abc\e[0m")
ok.("desc_long", L.obey_description(String.duplicate("x", 500)), :error)

# file_dir / to_player
ok.("filedir", L.file_dir("/data/", "me"), "/data/room/me/")
ok.("toplayer", L.to_player("/data/", "me", "/d/room/panlong/xiaoyuan.c"), "/data/room/me/xiaoyuan.c")

# processable
ok.("proc", L.processable?(4), true)
ok.("proc_no", L.processable?(3), false)
