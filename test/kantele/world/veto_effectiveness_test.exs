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

  defp do_classify(ctx, room, c, all_dirs \\ false) do
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
          {kind, _} = cls <- [classify(ctx, room, veto)],
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

  defp missing_uncategorized(ctx) do
    for room <- ctx.world.rooms,
        veto <- room.exit_vetoes,
        {:dead, {:undefined, names}} <- [classify(ctx, room, veto)],
        reduce: MapSet.new() do
      acc -> Enum.reduce(names, acc, &MapSet.put(&2, &1))
    end
  end
end