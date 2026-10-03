alias Kantele.World.Loader

#16 个 guarded_exit 房间的守卫清单（behavior_config.guard_npc）
pad = fn v, n -> String.pad_trailing(to_string(v), n) end

world = Loader.load()

targets = [
  {"baituo", "damen", "men wei"},
  {"baituo", "ximen", "men wei"},
  {"dali", "wangfugate", "chu wanli"},
  {"guanwai", "xiaoyuan", "ping si"},
  {"hengyang", "zhurongdian", "mi weiyi"},
  {"huashan", "buwei1", "lu dayou"},
  {"huashan", "laojun", "lao denuo"},
  {"huashan", "square", "gao genming"},
  {"huashan", "xiaowu", "feng buping"},
  {"shenlong", "dating", "wugen daozhang"},
  {"shenlong", "zoulang", "zhang danyue"},
  {"taohua", "dating", "huang yaoshi"},
  {"xiyu", "xxh2", "xingxiu dizi"},
  {"xiyu", "xxroad5", "chuchen zi"},
  {"xuedao", "shandong2", "bao xiang"},
  {"xuedao", "sroad9", "sheng di"}
]

# 守卫别名 -> 该别名下的所有实体
by_alias =
  Enum.reduce(world.characters, %{}, fn c, acc ->
    Enum.reduce(Map.get(c.meta, :aliases) || [], acc, fn a, a2 ->
      Map.update(a2, a, [c], &[c | &1])
    end)
  end)

IO.puts(
  pad.("房间", 24) <>
    pad.("守卫", 17) <>
    pad.("实体", 7) <>
    pad.("已放置", 8) <>
    pad.("family", 10) <> "方向规则"
)

IO.puts(String.duplicate("-", 100))

rows =
  for {z, r, g} <- targets do
    rid = "#{z}:#{r}"
    room = Enum.find(world.rooms, &(&1.id == rid))

    cfg = (room && Map.get(room, :behavior_config)) || %{}

    dirs =
      case {Map.get(cfg, :guard_directions), Map.get(cfg, :exempt_directions)} do
        {nil, nil} -> "**旧的 direction=" <> inspect(Map.get(cfg, :direction)) <> "**"
        {d, nil} -> "守 " <> inspect(d)
        {nil, e} -> "除 " <> inspect(e) <> " 外全守"
        _ -> "?"
      end

    case Map.get(by_alias, g, []) do
      [] ->
        IO.puts(pad.(rid, 24) <> pad.(g, 17) <> pad.("无", 7) <> pad.("-", 8) <> pad.("-", 10) <> dirs)
        {rid, g, :no_entity, false, nil, dirs}

      entities ->
        in_room = Enum.filter(entities, &(to_string(&1.room_id) == rid))
        fams = entities |> Enum.map(&Map.get(&1.meta, :guarder)) |> Enum.map(&(&1 && &1.family)) |> Enum.uniq()

        IO.puts(
          pad.(rid, 24) <>
            pad.(g, 17) <>
            pad.("有", 7) <>
            pad.("#{length(in_room)}/#{length(entities)}", 8) <>
            pad.(inspect(fams), 10) <> dirs
        )

        {rid, g, :ok, in_room != [], fams, dirs}
    end
  end

ready = Enum.count(rows, &match?({_, _, _, true, [_ | _], _}, &1))
IO.puts("\n完全就绪（已放置 + 有family）: #{ready} / 16")

IO.puts("\n=== 缺口汇总 ===")
IO.puts("  实体不存在: #{Enum.count(rows, &match?({_, _, :no_entity, _, _, _}, &1))}")
IO.puts("  没放对房间: #{Enum.count(rows, fn {_, _, :ok, false, _, _} -> true; _ -> false end)}")
IO.puts("  缺 family  : #{Enum.count(rows, fn {_, _, :ok, _, f, _} -> f in [nil, [nil]]; _ -> false end)}")
IO.puts("  方向仍是旧单值: #{Enum.count(rows, fn {_, _, _, _, _, d} -> String.starts_with?(d, "**"); _ -> false end)}")