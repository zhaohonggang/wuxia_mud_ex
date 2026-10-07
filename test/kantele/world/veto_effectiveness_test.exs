defmodule Kantele.World.VetoEffectivenessTest do
  @moduledoc """
  「条件写在数据里」不等于「会拦人」—— 用测试把这件事钉住。

  一条 `valid_leave` 条件要真的拦下玩家，必须同时满足：

    1. 限定了方向（`dir == 'x'`）—— 否则等于把该房间**所有**出口变成同一道门禁
    2. 那个方向真实存在
    3. `present('x')` 依赖的 NPC / 物品**有定义且在房里**
    4. 求值器支持它

  这份断言的由来：连续三次「以为做了、其实没生效」——

    * guarded_exit 的 16 个房间：`meta.guardert.family` 全是 nil，守卫被过滤光
    * 性别条件：11 条里只有 4 条真会拦，其余依赖的 NPC 不在场 / 方向不存在
    * 之前报告给用户的「测试清单」错房间名、错方向，靠的是印象而不是核对

  所以数字必须由脚本算出来、并被测试锁住。
  完整清单见 `scripts/audit_veto_effectiveness.exs`。
  """
  use ExUnit.Case, async: false

  alias Kantele.World.Loader
alias Kantele.World.LpcCondition

  setup_all do
    world = Loader.load()

    cap = fn re, text ->
      Regex.scan(re, text, capture: :all_but_first)
      |> Enum.flat_map(fn
        [] -> []
        [x | _] -> List.wrap(x)
      end)
      |> Enum.map(&to_string/1)
    end

    parse_aliases = fn body ->
      case cap.(~r/aliases\s*=\s*\[(.*?)\]/s, body) do
        [al | _] -> cap.(~r/"([^"]+)"/, al) |> MapSet.new()
        _ -> MapSet.new()
      end
    end

    definitions =
      for f <- Path.wildcard("data/world/*.ucl"), reduce: MapSet.new() do
        acc ->
          t = File.read!(f)

          cap.(~r/(?:characters|items)\s+"[^"]+"\s*\{(.*?)\n\s*\}/s, t)
          |> Enum.reduce(acc, fn body, a -> MapSet.union(a, parse_aliases.(body)) end)
      end

    %{world: world, cap: cap, parse_aliases: parse_aliases, definitions: definitions}
  end


  # present() 的第二个参数决定判据：environment(me) / this_object() 要在场，me 不要
  defp room_ref(alias, cond) do
    re = ~r/present\('#{Regex.escape(alias)}'\s*,\s*([^)]+)\)/
    case Regex.run(re, cond) do
      [_, second] -> second =~ "environment" or second =~ "this_object"
      _ -> false
    end
  end

  # 判定顺序与 scripts/audit_veto_effectiveness.exs **完全一致** ——
  # 脚本是给人看的清单，这里是给 CI 看的断言，两者必须同口径。
  defp classify(ctx, room, veto) do
    c = Map.get(veto, :condition)

    # 243 条 exit_vetoes 里有 77 条 condition 是 nil（转换器留下的空条目），
    # 必须在**碰 c 之前**返回 —— 否则 Regex.scan 会拿到 nil 直接崩。
    if not is_binary(c) or c == "" do
      :skip
    else
      do_classify(ctx, room, c, Map.get(veto, :all_dirs, false))
    end
  end

  defp do_classify(ctx, room, c, all_dirs) do
    exits = Enum.map(room.exits, & &1.exit_name)
    req = ctx.cap.(~r/dir\s*==\s*'(\w+)'/, c)
    missing_dirs = Enum.reject(req, &(&1 in exits))

    cond do
      # ---- Trap 通道：不走纯判定，由 Trap.Wuxing / Trap.Bagua / Trap.Arena 实现，
      #      所以它们**算会拦人**（18 条：五行迷宫 5 + 八卦阵 8 + 擂台 5）
      String.contains?(c, "check_out(") ->
        {:live, {:trap, :wuxing}}

      String.contains?(c, "check_dirs(") ->
        {:live, {:trap, :bagua}}

      String.contains?(c, "->refuse(") ->
        {:live, {:trap, :arena}}

      # ---- 纯条件 ----
      # `all_dirs = true` 是数据里**显式声明**「这条就拦所有方向」，
      # 和「转换器丢了 LPC 外层守卫」是两回事：前者 LPC 原文本来就没有
      # dir 判断（d/lingxiao/wave.c 玄冰莽封路、d/city/nproom.c 坐着不许走），
      # 后者要补守卫。
      #
      # 之前这里只看 condition 里有没有 "dir" 字样，把 12 条 all_dirs 门禁
      # 全判成 :unscoped，等于把「故意拦所有方向」和「丢了守卫」混为一谈。
      all_dirs ->
        {:live, {:all_dirs, nil}}

      all_dirs ->
        {:live, {:all_dirs, nil}}

      not Kantele.World.LpcCondition.direction_scoped?(c) ->
        {:dead, :unscoped}

      not Kantele.World.LpcCondition.supported?(c) ->
        {:dead, :unsupported}

      not Kantele.World.LpcCondition.enforceable?(c) ->
        {:dead, :unenforceable}

      missing_dirs != [] ->
        {:dead, {:no_such_dir, missing_dirs}}

      true ->
        check_presents(ctx, room, c)
    end
  end

  defp check_presents(ctx, room, c) do
    presents = LpcCondition.present_refs(c)

    if presents == [] do
      {:live, nil}
    else
      t = File.read!("data/world/#{room.zone_id}.ucl")
      key = String.replace_prefix(room.id, room.zone_id <> ":", "")

      body =
        case ctx.cap.(~r/room_characters\s+"#{Regex.escape(key)}"\s*\{(.*?)\n\s*\}/s, t) do
          [b | _] -> b
          _ -> ""
        end

      ids = ctx.cap.(~r/characters\.(\w+)\.id/, body)

      in_room =
        ids
        |> Enum.uniq()
        |> Enum.reduce(MapSet.new(), fn cid, acc ->
          case ctx.cap.(~r/characters\s+"#{Regex.escape(cid)}"\s*\{(.*?)\n\s*\}/s, t) do
            [cb | _] -> MapSet.union(acc, ctx.parse_aliases.(cb))
            _ -> acc
          end
        end)

      # `present(x, environment(me))` / `present(x, this_object())` 要求**在场**；
      # `present(x, me)` 是「玩家自己身上」，只要物品有定义即可。
      # 不区分这两者会把 qilin xue / jingang zhao / rice / tea 误判成
      # 「不在房里」——它们本来就是玩家携带的物品。
      {in_room_refs, on_player} =
        Enum.split_with(presents, fn a -> room_ref(a, c) end)

      undefined_player = Enum.reject(on_player, &MapSet.member?(ctx.definitions, &1))
      undefined_room = Enum.reject(in_room_refs, &MapSet.member?(ctx.definitions, &1))
      not_placed = Enum.reject(in_room_refs, &MapSet.member?(in_room, &1))

      # 按 &&/||/! 的**真实布尔结构**判定，而不是把多个 present() 当合取。
      # LPC 里大量条件是析取，例如
      #   (present('fumo dao',me) || present('jingang zhao',me) || ...) && dir == 'in'
      # 只要有一条分支成立就算「可能生效」。一律当合取会把 shaolin/qyping、
      # mingjiao/square 这类**其实有效**的门禁误判成 dead。
      avail =
        Map.new(presents, fn a ->
          defined? = MapSet.member?(ctx.definitions, a)

          {a,
           if room_ref(a, c) do
             defined? and MapSet.member?(in_room, a)
           else
             defined?
           end}
        end)

      cond do
        LpcCondition.satisfiable?(c, avail) -> {:live, nil}
        undefined_player != [] -> {:dead, {:undefined_player, undefined_player}}
        undefined_room != [] -> {:dead, {:undefined, undefined_room}}
        not_placed != [] -> {:dead, {:absent, not_placed}}
        true -> {:live, nil}
      end
    end
  end

  @tag :world_data
  test "总账：166 条里 155 条会拦人、11 条不会", ctx do
    tally =
      for room <- ctx.world.rooms,
          veto <- room.exit_vetoes,
          {kind, _} <- [classify(ctx, room, veto)],
          kind != :skip,
          reduce: %{} do
        acc -> Map.update(acc, kind, 1, &(&1 + 1))
      end

    total = tally[:live] + tally[:dead]

    assert total == 166,
           "条件总数变了：#{total}（tally=#{inspect(tally)}）"

    # 155 = 纯条件 137 + Trap 通道 18（五行迷宫 5 + 八卦阵 8 + 擂台 5）
    # 137 里含 12 条 all_dirs 全方向门禁：pigging_seat 4 + weiqi_seat 3
    #      + soup/rice 2 + prostitute 1 + xuanbing chimang 1 + xisui jing 1。
    # 注意「会拦人」= 机制已接好且依赖可满足；其中 11 条的触发状态
    # （拱猪桌/棋苑/丽春院/采花子）压根没移植，实际永不触发。
    assert tally[:live] == 155, "会拦人的条数变了：#{tally[:live]}"
    assert tally[:dead] == 11, "不会拦的条数变了：#{tally[:dead]}"
  end

  @tag :world_data
  test "不会拦的那些条里，没有一条是「求值器不支持」——那类只剩自定义函数", ctx do
    reasons =
      for room <- ctx.world.rooms,
          veto <- room.exit_vetoes,
          {:dead, reason} <- [classify(ctx, room, veto)],
          reduce: MapSet.new() do
        acc -> MapSet.put(acc, reason)
      end

    # 自定义函数（check_dirs/check_out/ob->refuse）走 Trap 通道，不算 dead
    refute MapSet.member?(reasons, :unsupported),
           "不应再有「依赖缺失字段」的条件 —— gender 已落地"

    assert MapSet.member?(reasons, :unscoped),
           "仍应有未限定方向的条件（防锁死守卫）"
  end

  @tag :world_data
  test "已补上的三个 NPC 不再出现在缺失清单里", ctx do
    missing = missing_uncategorized(ctx)

    # 这三个是从 LPC 的 CLASS_D(...) 门派工厂移植的：山门徐家兄弟（知客僧）
    # 与黑木崖桑三娘。它们原先让 4 条条件永远不触发。
    for fixed <- ["sang sanniang", "xu ming", "xu tong"] do
      refute MapSet.member?(missing, fixed),
             "#{fixed} 已移植到 data/world，不该再报「未定义」（若报错请检查 room_characters 是否也放了）"
    end
  end

  @tag :world_data
  test "loader 对解析不到的 room_items / room_characters 引用会 warn（不再静默跳过）" do
    # 这类悬空引用历史上一直静默跳过：
    #     nil -> # NPC 数据缺失（引用不存在）时跳过，避免悬挂引用
    #     []
    # 结果 767 条 room_characters + 468 条 room_items 悬空长期没人发现，
    # 门禁那边只表现为「这个 NPC 不在房里」，很容易被误判成条件写错了。
    # 见 docs/dangling-room-items-report.zh-CN.md §〇
    Kantele.World.Loader.reset_unresolved_warnings()
    Kantele.World.Loader.load()

    seen = :erlang.get(:world_unresolved) || %{}
    assert map_size(seen) > 0, "应记录到若干悬空引用"

    kinds = seen |> Map.keys() |> Enum.map(fn {_z, k, _r} -> k end) |> Enum.uniq() |> Enum.sort()
    assert :character in kinds, "room_characters 的悬空也应被记录"
    assert :item in kinds, "room_items 的悬空也应被记录"

    # 值的形状是 {次数, 最后一个房间}，别直接 Enum.sum
    total_refs = seen |> Map.values() |> Enum.map(fn {c, _room} -> c end) |> Enum.sum()
    assert total_refs >= map_size(seen), "每个 ref 至少要被数一次"

    # 「同一个 ref 被多个房间引用时次数会累加」这条守卫以前靠真实数据顺带
    # 验证（当时有 4 条 ref 各被引用 2~4 次）。把 room_items 里的活物搬进
    # room_characters 之后剩下的 13 条悬空恰好一条都不重复，真实数据再也
    # 触发不了这个分支，所以直接打一次 warn_unresolved 来守。
    Kantele.World.Loader.reset_unresolved_warnings()
    Kantele.World.Loader.warn_unresolved(:item, "z", "room-a", "items.probe.id")
    Kantele.World.Loader.warn_unresolved(:item, "z", "room-b", "items.probe.id")

    probe = :erlang.get(:world_unresolved)

    # 只守「次数累加」：重复命中时 loader 记的是最后一个房间（见 loader.ex
    # 的 `{count + 1, room_id}`），这里不断言房间是哪个。
    assert {2, _room} = probe[{"z", :item, "items.probe.id"}],
           "同一 ref 被两个房间引用时，次数应累加"
    Kantele.World.Loader.reset_unresolved_warnings()

    # 别写死阈值。之前写的是 > 1000，那时总数 1235；后来陆续补齐了
    # mafu(27) / bing(76) / guanbing(16) / walker(141)，再补 ducha / liumang /
    # wujiang / kid1 / xunbu / xiaoer2 / guest / duke（合计 140），
    # 总数降到 815，断言就变成「必须还有 1000 个悬空」—— 补得越多越容易红。
    #
    # 之后又把**跨区借用的 NPC 统一 namespacing**（`<来源区>_<id>`）并放进
    # clone_lib，房间引用改成 `characters.beijing_xianren.id` 这种形式，
    # room_characters 的悬空从 351 掉到 **7**。
    #
    # 再后来按 LPC 原文逐条分类剩下的 room_items 悬空，发现 443 条里
    # **431 条根本不是物品**（355 条 /kungfu/class/<门派>/ + 75 条
    # /clone/{quarry,worm,beast}/ + 1 条 /d/hangzhou/honghua/huo，全是
    # `inherit NPC`），是转换器把 set("objects") 里的活物写进了 room_items。
    # 真物品只有 10 条，已全部补齐（4 条 /clone/book + 3 条跨区 namespacing
    # + city 本地的 box 和 shijing_book），悬空降到 **437**。
    #
    # 然后按 LPC 的 inherit 链把 room_items 里的活物**外科式**搬进
    # room_characters（scripts/fix_npc_in_items.py）：439 条引用、386 个房间、
    # 53 个区，缺的 366 个定义按 `<来源>_<id>` 命名落进 clone_lib。
    # 悬空从 **437 掉到 13**。之后补齐 shaolin:cjlou1 的 wuji1~4 秘籍
    # （顶层 `items "wuji{1..4}"` 落进 clone_lib + 实例掷骰随机技能，
    # 见 docs/lpc-port-gaps.zh-CN.md §十二之一；顺带修了首套 lv5d 缺右花括号
    # 的孤儿块），掉到 **9**。剩 9 条全是真待办：
    #   - 2 条 sammatti:town_square 引 `global.items.*`，而 global 已搬去
    #     test/fixtures/world，默认加载不含它
    #
    # tong_ren/zixu 两个跨区引用经 clone_lib 回退解析，静态仍显示悬空（不跨区解析）。
    # cheng/liang/liao/qi/mujiang 已补齐本区定义，不再悬空。
    #
    # 这里钉的是**上限**：修复只会让这个数变小，所以给一个当前值附近的门槛，
    # 数字变大说明数据退化了（或者又漏了一个区）。
    assert total_refs <= 20, "悬空引用不该变多，当前 #{total_refs}（上限 20）"

# 头部现在只剩 clone_tong_ren/adm_zixu 两个跨区引用（静态分析不跨区，仍显示悬空；
    # 运行时经 clone_lib 回退可解析）。其余 cheng/liang/liao/qi/mujiang 已补齐本区定义。
    for id <- ~w(clone_tong_ren adm_zixu) do
      assert Enum.any?(seen, fn
                   {{_z, :character, r}, _} -> String.ends_with?(r, "." <> id <> ".id")
                   _ -> false
                 end),
              "#{id} 还应被记录在悬空里（若已补齐，请从这里移除并下调上面的上限）"
    end

    Kantele.World.Loader.reset_unresolved_warnings()
  end

  @tag :world_data
  test "之前空掉的房间现在有物品了（items 与 characters 一样只在本区解析）", ctx do
    # `dereference/3` 是 `zone |> flatten_items() |> ...`，所以 items 也只在本区解析。
    # 钢刀/长剑/竹棒这些**全库本来就有定义**，只是定义在别的区，
    # 于是引用它们的区全是空房。本轮把这些定义复制到了引用它们的区。
    for rid <- ~w(city:ma_bingqi kaifeng:hh_bingqi baituo:wuqiku wudang:cangjingge
                  wudang:nanyan1 shaolin:damodong huanghe:caodi2 xiakedao:wuqiku
                  suzhou:huqiu shenfeng:shibi) do
      room = Enum.find(ctx.world.rooms, &(&1.id == rid))
      assert room, "应有 #{rid}"

      inst = Map.get(room, :item_instances) || []
      assert inst != [], "#{rid} 应有物品实例（转换器写了 room_items 但定义在本区缺失）"
    end

    # 全库落地率。
    #
    # 注意口径：`test` / `global` 两个夹具区已经搬去 `test/fixtures/world`，
    # 默认加载不再包含它们，所以这里的分母是**真实世界**的 4409 间房。
    #
    # 实测（`Loader.load()` vs `Loader.load_fixture_world()`）：
    #   正式世界   4409 间房，其中 163 间有物品实例
    #   含夹具     4470 间房，其中 202 间有物品实例  <- 夹具区白送 39 间
    #
    # 旧的 `>= 190` 阈值只有靠夹具区那 39 间才够得着；真实世界本来就只有 163。
    # 所以这里下调到 160 留余量，真正的回归防线是上面那 10 个具体房间断言。
    with_items =
      Enum.count(ctx.world.rooms, fn r -> (Map.get(r, :item_instances) || []) != [] end)

    assert with_items >= 160,
           "真实世界有物品的房间应 >= 160，实际 #{with_items}（夹具区已不计入）"

    # 兵械库那几间应该拿到钢刀/长剑/竹棒
    for rid <- ~w(city:ma_bingqi kaifeng:hh_bingqi xiakedao:wuqiku) do
      room = Enum.find(ctx.world.rooms, &(&1.id == rid))

      names =
        room
        |> Map.get(:item_instances)
        |> Enum.map(fn i ->
          case Enum.find(ctx.world.items, &(&1.id == i.item_id)) do
            nil -> nil
            it -> it.name
          end
        end)

      assert Enum.any?(names, &(&1 in ["钢刀", "长剑", "竹棒", "长鞭", "钢杖"])),
             "#{rid} 应有兵器，实际 #{inspect(names)}"
    end
  end

  @tag :world_data
  test "9 种蛇按 LPC clone/beast/*.c 定义并放进了引用它们的房间", ctx do
    # LPC 里这些都是 inherit SNAKE（mud/inherit/char/snake.c 的 setup()
    # 给的是 attitude="aggressive"），转换器把它们写进了 room_items，
    # 于是被 loader 静默丢弃。修法是 characters + room_characters。
    #
    # 与三匹马不同，这些蛇**没有任何 valid_leave 引用**，
    # 所以放置它们不会造成新的封路 / 死锁。
    expect = %{
      "dushe" => {"毒蛇", 500, 8_000},
      "qingshe" => {"竹叶青蛇", 400, 6_000},
      "yanjingshe" => {"眼镜蛇", 1_800, 200_000},
      "jinshe" => {"金环蛇", 300, 5_000},
      "wubushe" => {"五步蛇", 700, 10_000},
      "caihuashe" => {"菜花蛇", nil, nil},
      "wangshe" => {"眼镜王蛇", nil, nil},
      "fushe" => {"腹蛇", nil, nil},
      "mangshe" => {"蟒蛇", 5_000, 300_000}
    }

    for {cid, {name, max_qi, exp}} <- expect do
      insts =
        Enum.filter(ctx.world.characters, fn c ->
          cid in (c.meta.aliases || [])
        end)

      assert insts != [],
             "#{cid}（#{name}）应该有实例 —— 定义和放置是否都做了？"

      for c <- insts do
        assert c.name == name

        if max_qi do
          assert c.meta.vitals.max_qi == max_qi,
                 "#{cid} 的 max_qi 应为 #{max_qi}，实际 #{c.meta.vitals.max_qi}"
        end

        if exp do
          assert c.meta.stats.combat_exp == exp,
                 "#{cid} 的 combat_exp 应为 #{exp}，实际 #{c.meta.stats.combat_exp}"
        end

        # inherit SNAKE -> aggressive
        assert c.meta.combat_config.attitude == "aggressive",
               "#{cid} 应 aggressive（mud/inherit/char/snake.c）"

        # LPC 的 clone/beast/*.c 一个 set_skill 都没有
        assert c.meta.stats.skills == %{}, "#{cid} 不该有技能"

        # 顶层 gender 会被 loader 丢弃，这里只要求不崩
        assert is_binary(c.name)
      end
    end

    # 别名要同时给带空格与不带空格的两种：
    #   LPC set_name 给的是 "du she"，而数据 id / room_items 引用是 dushe。
    #   别名匹配不做空格规范化，两种都得在。
    for cid <- ["dushe", "qingshe", "jinshe", "wubushe", "fushe", "mangshe"] do
      c = Enum.find(ctx.world.characters, fn x -> cid in (x.meta.aliases || []) end)

      assert cid in c.meta.aliases, "#{cid} 应含无空格别名"

      # 别名不能只有无空格 id 一个：LPC 的 present() 按**原文**查
      # （"du she" / "jinhuan she"），所以带空格/带词的形式必须留着。
      # 注意 jinshe 是个例外 —— LPC 里它的 id 是「jinhuan she」而不是「jin she」，
      # 所以不能简单地去空格比对。
      assert length(c.meta.aliases) >= 3,
             "#{cid} 的别名应至少有 3 个（无空格 id + LPC 原文别名），实际 #{inspect(c.meta.aliases)}"
    end

    # 抽查放置：白驼山的蛇园 / 草原、洛阳城外等
    for rid <- ["baituo:cao2", "baituo:sheyuan", "city:jiaowai5",
                "hengyang:zigai1", "xiyu:btshan"] do
      snakes = Enum.filter(ctx.world.characters, fn c -> c.room_id == rid end)
      assert snakes != [], "#{rid} 应有蛇"
    end
  end

  @tag :world_data
  test "29 个马厩里都有 3 匹马（跨区引用必须在每个区各定义一份）", ctx do
    # LPC: /clone/horse/{zaohongma,huangbiaoma,ziliuma}: 1
    # 转换器把这三个 NPC 写进了 room_items，于是被静默丢弃 ——
    # 修法是每个区各放一份 characters 定义 + room_characters 引用。
    #
    # 这里钉住两件事：
    #   1. 29 个马厩每个都恰好 3 匹
    #   2. 每匹马的 spawn_room_id 就是那个马厩（证明 room_characters 真的生效，
    #      而不是只有定义存在）
    stables = ~w(beijing:majiu beijing:majuan changan:majiu chengdu:majiu
                 city:majiu dali:majiu emei:majiu1 emei:majiu2 foshan:majiu
                 fuzhou:majiu guanwai:majiu hangzhou:majiu hengyang:majiu
                 huanghe:majiu jingzhou:majiu kaifeng:majiu kunming:majiu
                 lanzhou:majiu lingzhou:majiu lingzhou:malan luoyang:majiu
                 quanzhen:majiu quanzhou:majiu1 quanzhou:majiu2 shaolin:majiu1
                 suzhou:majiu xiangyang:majiu xiyu:majiu zhongzhou:majiu)

    horse_names = ["枣红马", "黄骠马", "紫骝马"]

    for rid <- stables do
      horses =
        Enum.filter(ctx.world.characters, fn c ->
          c.room_id == rid and c.name in horse_names
        end)

      assert length(horses) == 3,
             "#{rid} 应有 3 匹马，实际 #{length(horses)}（#{inspect(Enum.map(horses, & &1.name))}）"

      for h <- horses do
        assert h.meta.combat_config.spawn_room_id == rid,
               "#{h.name}@#{rid} 的 spawn_room_id 应是 #{rid}"
      end
    end

    # 属性照 LPC clone/horse/*.c：attitude=peaceful / max_qi=300 / exp=50000 / 0 技能
    for h <- Enum.filter(ctx.world.characters, &(&1.name in horse_names)) do
      assert h.meta.combat_config.attitude == "peaceful", "#{h.name} 应 peaceful"
      assert h.meta.vitals.max_qi == 300, "#{h.name} 的 max_qi 应 300"
      assert h.meta.stats.combat_exp == 50_000, "#{h.name} 的 combat_exp 应 50000"
      assert h.meta.stats.skills == %{}, "#{h.name} 不该有技能（LPC 无 set_skill）"
    end

    assert length(Enum.filter(ctx.world.characters, &(&1.name in horse_names))) == 87,
           "三匹马各 29 匹，共 87"
  end

  @tag :world_data
  test "lingxiao:wave 的玄冰莽门禁是**真**生效的（不是空转）", ctx do
    # mud/d/lingxiao/wave.c:
    #   set("objects", ([ "/clone/beast/xuanmang" : 1 ]));
    #   if (objectp(present("xuanbing chimang", environment(me))))
    #       return notify_fail("...顿时将去路完全封锁。\n");
    #
    # wave 只有 up / down / out 三个出口，全部被封 —— 所以这条 all_dirs 门禁
    # 一旦成立，玩家出不去，**必须能打死玄冰莽**。因此这里钉住：
    #   * NPC 真的在房里（否则 present() 恒假，门禁空转）
    #   * 它 aggressive（会主动攻击）
    #   * no_kill = false 且 respawn_delay = nil（打得死，且不会刷新后再次锁死）
    room = Enum.find(ctx.world.rooms, &(&1.id == "lingxiao:wave"))
    assert room, "应有 lingxiao:wave 这个房间"

    exits = Enum.map(room.exits, & &1.exit_name) |> Enum.sort()
    assert exits == ["down", "out", "up"], "wave 的出口变了: #{inspect(exits)}"

    snake =
      Enum.filter(ctx.world.characters, fn c ->
        "xuanbing chimang" in [c.name | (c.meta.aliases || [])]
      end)

    assert length(snake) == 1,
           "lingxiao:wave 应恰好有 1 个玄冰莽，实际 #{length(snake)}"

    [snake] = snake
    assert snake.room_id == "lingxiao:wave"

    cfg = snake.meta.combat_config
    assert cfg.attitude == "aggressive", "玄冰莽应 aggressive（inherit SNAKE 的设定）"
    refute cfg.no_kill, "玄冰莽必须打得死，否则 wave 会变成死房间"
    assert is_nil(cfg.respawn_delay), "不设刷新，否则打死后又会被封路"

    # 属性照 LPC clone/beast/xuanmang.c
    st = snake.meta.stats
    assert st.combat_exp == 5_000_000
    assert st.str == 50 and st.con == 100 and st.dex == 50
    assert st.skills["unarmed"] == 500 and st.skills["force"] == 500
    assert snake.meta.vitals.max_qi == 20_000
    assert cfg.apply.attack == 500 and cfg.apply.armor == 300

    # 门禁本身：all_dirs + 依赖 xuanbing chimang 在场
    veto = Enum.find(room.exit_vetoes, &(&1.condition =~ "xuanbing chimang"))
    assert veto, "wave 应有玄冰莽那条 veto"
    assert Map.get(veto, :all_dirs, false), "玄冰莽封路是 all_dirs（LPC 原文就没有 dir 判断）"
  end

  @tag :world_data
  test "all_dirs = true 的门禁算「故意拦所有方向」，不算丢了守卫", ctx do
    # 数据里有 12 条 veto 标了 all_dirs = true，它们的 LPC 原文本来就没有
    # dir 判断（玄冰莽封路、坐着不许走、端着饭不许走……）。
    # 之前审计只看 condition 里有没有 "dir" 字样，把它们全判成
    # 「未限定方向」，等于把「故意拦所有方向」和「转换器丢了守卫」混为一谈。
    all_dirs =
      for room <- ctx.world.rooms,
          veto <- room.exit_vetoes,
          Map.get(veto, :all_dirs, false),
          reduce: [] do
        acc -> [room.id | acc]
      end

    assert length(all_dirs) == 12,
           "预期 12 条 all_dirs 门禁，实际 #{length(all_dirs)}: #{inspect(all_dirs)}"

    # 它们都该被 classify 成 live，且理由是 {:all_dirs, nil}
    for room <- ctx.world.rooms,
        veto <- room.exit_vetoes,
        Map.get(veto, :all_dirs, false) do
      assert {:live, {:all_dirs, nil}} = classify(ctx, room, veto),
             "#{room.id} 标了 all_dirs，就不该再被判成 :unscoped"
    end

    # 真正「丢了守卫」的只剩 4 条
    unscoped =
      for room <- ctx.world.rooms,
          veto <- room.exit_vetoes,
          {:dead, :unscoped} <- [classify(ctx, room, veto)],
          reduce: [] do
        acc -> [room.id | acc]
      end

    assert length(unscoped) == 4,
           "真正未限定方向的应为 4 条，实际 #{length(unscoped)}: #{inspect(unscoped)}"
  end

  @tag :world_data
  test "marks/花 那条门禁必须保持未限定方向（加了会把 xiyu:xiaoyao 封死）", ctx do
    # mud/d/xiyu/xxh6.c 里第三条拦截是
    #   if (dir == "in") { if (present("caihua zi", environment(me)))
    #   { if (!(int)this_player()->query_temp("marks/花")) return notify_fail(...); } }
    #
    # marks/花 只由 mud/d/xiyu/npc/caihua.c 的 action 设置，而采花子的 action
    # 没有移植 —— 全库没有任何地方写这个标记。加上 dir 守卫后，
    # xiyu:xiaoyao 会对**所有人**封死（不是只封非星宿海）。
    #
    # 同房间另一条（gender == 无性）是安全的：那是玩家固有属性，
    # LPC 本来就这个意思，不存在「需要先做点什么才能解开」。
    conds =
      Enum.flat_map(ctx.world.rooms, fn r ->
        Enum.map(r.exit_vetoes || [], &{r.id, Map.get(&1, :condition)})
      end)

    marks =
      for {id, c} <- conds,
          is_binary(c),
          String.contains?(c, "marks/花"),
          do: {id, c}

    assert length(marks) == 1, "预期只有 xiyu:xxh6 这一条涉及 marks/花"

    for {id, c} <- marks do
      refute LpcCondition.direction_scoped?(c),
             "#{id} 的 marks/花 门禁不能限定方向：marks/花 无人设置，加守卫会封死 xiyu:xiaoyao"
    end
  end

  @tag :world_data
  test "上一轮补齐的 9 个 NPC 都不再出现在缺失清单里", ctx do
    missing = missing_uncategorized(ctx)

    # 这批的根因是转换器把 LPC set("objects", ...) 写错了地方：
    #   * 多数写进了 room_items（当成物品），而它们其实是 characters
    #   * luoyang/jingzhou 写进了 room_characters，但本区没有该定义
    #   * jingzhou/npc/jing.c 的名字被写倒成「凌思退」，别名成了 ling situi
    for fixed <- ["mang she", "guan bing", "jia ding", "miao renfeng",
                  "ren woxing", "he hongyao", "daoming", "wuchen daozhang",
                  "ling tuisi"] do
      refute MapSet.member?(missing, fixed),
             "#{fixed} 已补进 data/world，不该再报「未定义 / 不在房里」"
    end
  end

  @tag :world_data
  test "玩家身上的物品不算「不在房里」，且「不在房里」已清零", ctx do
    # `present(x, me)` 只要物品有定义即可 —— 玩家捡到就能用。
    # 审计脚本一度把它们判成 dead（qilin xue / jingang zhao / rice / tea），
    # 白白少算了 4 条。
    absent =
      for room <- ctx.world.rooms,
          veto <- room.exit_vetoes,
          {:dead, {:absent, names}} <- [classify(ctx, room, veto)],
          reduce: [] do
        acc -> acc ++ names
      end

    for item <- ["qilin xue", "jingang zhao", "rice", "tea"] do
      refute item in absent,
             "#{item} 是玩家携带的物品，不该被判成「不在房里」"
    end

    # 之前这里断言 `absent != []` 当哨兵，防止「:absent 分支再也没进过」。
    # 现在 6 条「有定义但没放进去」都补上了（guan bing / jia ding /
    # miao renfeng / ren woxing / he hongyao / wuchen daozhang），
    # 该类别已清零 —— 改成钉住「别再涨回来」。
    assert absent == [],
           "不该再有「NPC 有定义但没放进房间」的条件：#{inspect(Enum.uniq(absent))}"
  end

  @tag :world_data
  test "山门「徐家兄弟把守」的条件现在真的会拦人了", ctx do
    rooms =
      for room <- ctx.world.rooms,
          veto <- room.exit_vetoes,
          {:live, _} <- [classify(ctx, room, veto)],
          cond = Map.get(veto, :condition),
          is_binary(cond) and String.contains?(cond, "xu"),
          do: room.id

    assert "shaolin:shanmen" in rooms,
           "山门的「徐家兄弟把守」应该已经生效（虚明 / 徐通 已移植并放进房间）"
  end

  @tag :world_data
  test "10 条真物品悬空已补齐（其余 431 条是 NPC 错位，另案处理）", ctx do
    # scripts/classify_dangling_items.py 按 LPC 原文把 443 条 room_items 悬空
    # 分类后，只有这 10 条是真物品，其余全是 `inherit NPC` 被转换器写错位置。
    #
    # 这里逐个钉住：定义存在，且真的被放进 LPC 指定的那间房。
    expect = [
      # {房间,           物品 id,          名字,   来源}
      {"huanghe:shixiazi", "city_shitou", "大石头", "d/city/obj/shitou.c"},
      {"jueqing:house", "gumu_fengmi", "玉蜂蜜", "d/gumu/obj/fengmi.c"},
      {"xiakedao:chashi", "wudang_mitao", "水蜜桃", "d/wudang/obj/mitao.c"},
      {"xiakedao:chashi", "wudang_xiangcha", "香茶", "d/wudang/obj/xiangcha.c"},
      {"city:wumiao", "box", "功德箱", "d/city/obj/box.c"},
      {"city:shuyuan2", "shijing_book", "诗经", "u/mudren/obj/shijing_book.c"}
    ]

    for {rid, iid, name, origin} <- expect do
      room = Enum.find(ctx.world.rooms, &(&1.id == rid))
      assert room, "应有 #{rid}"

      placed =
        room.item_instances
        |> Enum.map(& &1.item_id)
        |> Enum.map(fn iid_full ->
          case Enum.find(ctx.world.items, &(&1.id == iid_full)) do
            nil -> nil
            # 本区没有同名物品时 id 是 "clone_lib:<来源区>_<id>"，只比末段
            it -> {it.id |> String.split(":") |> List.last(), it.name}
          end
        end)

      # 本区没有同名物品时，房间引用的是 clone_lib 里的 `<来源区>_<id>`
      assert Enum.any?(placed, fn
               {^iid, ^name} -> true
               _ -> false
             end),
             "#{rid} 应有 #{name}（#{iid}，来自 #{origin}），实际 #{inspect(placed)}"
    end

    # 属性抽查：跨区借用的三样都走 clone_lib 回退，meta 必须真的解析出来，
    # 不能只是「有个空壳定义」—— 之前 room_items 悬空时就是这样被静默跳过的。
    shitou = Enum.find(ctx.world.items, &(&1.id == "clone_lib:city_shitou"))
    assert shitou, "city_shitou 应在 clone_lib 里"
    assert shitou.meta.skill_type == "hammer", "shitou 是 inherit HAMMER"
    assert shitou.meta.damage == 1, "init_hammer(1) 即 damage 1"

    tao = Enum.find(ctx.world.items, &(&1.id == "clone_lib:wudang_mitao"))
    assert tao.meta.food == 30, "mitao 的 food 应来自 set(\"food_supply\", 30)"

    gongde = Enum.find(ctx.world.items, &(&1.id == "city:box"))
    assert gongde, "city:wumiao 的 box 应解析到 city:box"
    assert gongde.meta.value == 1000 and gongde.meta.material == "wood"
  end

  @tag :world_data
  test "city:wumiao 的 box 不会被别区的同名 box 顶掉（本区优先）", ctx do
    # suzhou.ucl / tianlongsi.ucl 各自也有 items "box"，loader 是本区优先、
    # 找不到才回退 clone_lib，所以三个区的功德箱互不干扰。
    gongde = Enum.find(ctx.world.items, &(&1.id == "city:box"))
    assert gongde, "city:box 应存在"
    assert gongde.name == "功德箱", "应是 city 自己那份，不该是别区的 box"
  end

  defp missing_uncategorized(ctx) do
    for room <- ctx.world.rooms,
        veto <- room.exit_vetoes,
        {:dead, {:undefined, names}} <- [classify(ctx, room, veto)],
        reduce: MapSet.new() do
      acc -> Enum.reduce(names, acc, &MapSet.put(&2, &1))
    end
  end
end