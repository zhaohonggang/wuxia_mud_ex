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

          cap.(~r/(?:characters|items)\s+"[^"]+"\s*\{(.*?)\n\s{2}\}/s, t)
          |> Enum.reduce(acc, fn body, a -> MapSet.union(a, parse_aliases.(body)) end)
      end

    %{world: world, cap: cap, parse_aliases: parse_aliases, definitions: definitions}
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
      do_classify(ctx, room, c)
    end
  end

  defp do_classify(ctx, room, c) do
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
    presents = ctx.cap.(~r/present\('([^']+)'/, c)

    if presents == [] do
      {:live, nil}
    else
      t = File.read!("data/world/#{room.zone_id}.ucl")
      key = String.replace_prefix(room.id, room.zone_id <> ":", "")

      body =
        case ctx.cap.(~r/room_characters\s+"#{Regex.escape(key)}"\s*\{(.*?)\n\s{2}\}/s, t) do
          [b | _] -> b
          _ -> ""
        end

      ids = ctx.cap.(~r/characters\.(\w+)\.id/, body)

      in_room =
        ids
        |> Enum.uniq()
        |> Enum.reduce(MapSet.new(), fn cid, acc ->
          case ctx.cap.(~r/characters\s+"#{Regex.escape(cid)}"\s*\{(.*?)\n\s{2}\}/s, t) do
            [cb | _] -> MapSet.union(acc, ctx.parse_aliases.(cb))
            _ -> acc
          end
        end)

      undefined = Enum.reject(presents, &MapSet.member?(ctx.definitions, &1))
      absent = Enum.reject(presents, &MapSet.member?(in_room, &1))

      cond do
        undefined != [] -> {:dead, {:undefined, undefined}}
        absent != [] -> {:dead, {:absent, absent}}
        true -> {:live, nil}
      end
    end
  end

  @tag :world_data
  test "总账：166 条里 114 条会拦人、52 条不会", ctx do
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

    assert tally[:live] == 114, "会拦人的条数变了：#{tally[:live]}"
    assert tally[:dead] == 52, "不会拦的条数变了：#{tally[:dead]}"
  end

  @tag :world_data
  test "不会拦的 52 条里，没有一条是「求值器不支持」——那类只剩自定义函数", ctx do
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
  test "依赖缺失的 NPC 清单被钉住（防止新增 unnoticed）", ctx do
    missing =
      for room <- ctx.world.rooms,
          veto <- room.exit_vetoes,
          {:dead, {:undefined, names}} <- [classify(ctx, room, veto)],
          reduce: MapSet.new() do
        acc -> Enum.reduce(names, acc, &MapSet.put(&2, &1))
      end

    # 这批是 LPC 里有、数据里没有的 NPC（多为 CLASS_D 门派工厂 / 独立 .c 未转换）。
    # 已知的：山门徐家兄弟、少林伏魔刀/金刚琢、黑木崖桑三娘、死亡沼泽麒麟靴…
    for known <- ["sang sanniang", "xu ming", "xu tong", "fumo dao", "jingang zhao", "qilin xue"] do
      assert MapSet.member?(missing, known),
             "#{known} 应在「依赖缺失」清单里"
    end
  end

  @tag :world_data
  test "依赖 NPC 但 NPC 不在房里的条件，也被记为 dead", ctx do
    absent =
      for room <- ctx.world.rooms,
          veto <- room.exit_vetoes,
          {:dead, {:absent, names}} <- [classify(ctx, room, veto)],
          reduce: [] do
        acc -> acc ++ names
      end

    assert absent != [], "应存在「NPC 有定义但不在房里」的条件"
  end

  @tag :world_data
  test "山门徐家兄弟、少林伏魔刀这些守卫确实还没落地（提醒后续补）", ctx do
    rooms =
      for room <- ctx.world.rooms,
          veto <- room.exit_vetoes,
          {:dead, {:undefined, names}} <- [classify(ctx, room, veto)],
          "xu ming" in names or "xu tong" in names,
          do: room.id

    assert "shaolin:shanmen" in rooms,
           "山门的「徐家兄弟把守」应仍在缺失清单里（todo 文档点名的三项之一）"
  end
end