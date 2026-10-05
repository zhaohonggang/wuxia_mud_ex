defmodule Kantele.World.Loader do
  @moduledoc """
  Load the world from data files
  """

  alias Kalevala.Character
  alias Kalevala.World.Item
  alias Kalevala.World.Room.Feature
alias Kantele.Character.Stats
alias Kantele.World.LoaderError
  alias Kantele.World.Room
  alias Kantele.World.Zone

  @paths %{
    brains_path: "data/brains",
    help_path: "data/help",
    verbs_path: "data/verbs.ucl",
    world_path: "data/world",
    extra_world_paths: []
  }

  # 测试夹具区（test.ucl / global.ucl）所在目录。**只有测试会显式挂它。**
  @fixture_world_path "test/fixtures/world"

  @doc """
  Load zone files into Kalevala structs

  任一数据文件出错都会抛 `Kantele.World.LoaderError`，并尽量附带出错的
  文件路径，方便上层定位是哪个 .ucl 写坏了。

  ## `extra_world_paths`：只给测试用的夹具区

  `data/world` 里曾经混着 `test.ucl` / `global.ucl` 两个区。它们是当年拿
  `test_minimal_world_v2_modified/` 挑 `.c` 文件跑转换器测试的产物，跟真实区
  大量重名（`test` 的 34 个房间有 33 个在别的区也存在，`global` 是 20/27），
  而且互不连通 —— 没有任何真实区引用 `test:` / `global:` 的房间，玩家走不到。

  留在正式目录里的代价是实打实的：61 个走不到的房间、25 个 NPC、84 个物品
  混进运行时世界并参与别名统计，悬空引用报告和门禁审计也跟着被污染。
  所以它们现在搬到 `#{@fixture_world_path}`，**默认不再加载**。

  需要它们的测试显式传：

      Loader.load(%{extra_world_paths: ["test/fixtures/world"]})

  合并顺序是「夹具先、正式区后」：万一将来出现同名 zone key，
  后写入的正式区会覆盖夹具 —— 重复内容一律以正式区为准。
  """
  def load(paths \\ %{}) do
    paths = Map.merge(@paths, paths)

    world_data = load_world_data(paths)
    brain_data = load_brains(paths.brains_path)
    verbs = load_verbs(paths.verbs_path)

    context = %{
      verbs: verbs,
      brains: brain_data
    }

    zones =
      Enum.map(world_data, fn {key, zone_data} ->
        parse_zone_with_context({key, zone_data}, context)
      end)

    world =
      zones
      |> Enum.map(&build_zone(&1, world_data, zones))
      |> parse_world()

    # 悬空引用汇总放在最后打 —— 逐条 warn 会淹掉日志（实测 805 条 = 16000 行）
    report_unresolved()

    world
  end

  # ---- 文件级错误包装：读入/解析/构建出错时把文件路径挂进 LoaderError ----

  # 附加目录在前、正式目录在后：`Enum.into/2` 后写入的覆盖先写入的，
  # 所以同名 zone 最终以正式区为准（夹具不参与真实世界的定义）。
  defp load_world_data(paths) do
    merge = &merge_world_data/1

    (List.wrap(paths.extra_world_paths) ++ [paths.world_path])
    |> Enum.flat_map(&load_folder(&1, ".ucl", merge))
    |> Enum.into(%{})
  end

  @doc """
  测试夹具区的路径。只有测试该用它，生产/审计脚本不要挂。
  """
  def fixture_world_path, do: @fixture_world_path

  def load_fixture_world(paths \\ %{}) do
    load(Map.put(paths, :extra_world_paths, [fixture_world_path()]))
  end

  defp load_folder(path, file_extension, merge_fun) do
    ls!(path)
    |> Enum.filter(fn file ->
      String.ends_with?(file, file_extension)
    end)
    |> Enum.flat_map(fn file ->
      load_data_file(Path.join(path, file), merge_fun)
    end)
    |> Enum.into(%{})
  end

  defp load_data_file(path, merge_fun) do
    path
    |> File.read!()
    |> Elias.parse()
    |> merge_fun.()
  rescue
    exception ->
      reraise LoaderError,
              [
                message: "世界数据文件处理失败",
                file: path,
                reason: exception
              ],
              __STACKTRACE__
  end

  defp ls!(path) do
    File.ls!(path)
  rescue
    exception ->
      reraise LoaderError,
              [message: "读取目录失败", file: path, reason: exception],
              __STACKTRACE__
  end

  defp load_brains(path) do
    Kantele.Brain.load_all(path)
  rescue
    exception ->
      reraise LoaderError,
              [message: "大脑配置加载失败", file: path, reason: exception],
              __STACKTRACE__
  end

  defp load_verbs(path) do
    path
    |> File.read!()
    |> Elias.parse()
    |> parse_verbs()
  rescue
    exception ->
      reraise LoaderError,
              [message: "动词配置处理失败", file: path, reason: exception],
              __STACKTRACE__
  end

  defp parse_zone_with_context(zone_data, context) do
    parse_zone(zone_data, context)
  rescue
    exception ->
      {key, _zone_data} = zone_data

      reraise LoaderError,
              [
                message: "区域数据解析失败",
                file: zone_file_path(to_string(key)),
                reason: exception
              ],
              __STACKTRACE__
  end

  # 区域结构构建（exits/characters/items/minimap）逐区执行，出错归因到区域文件。
  # 与原先分阶段 Enum.map 等价：各阶段只改动本区域的副本，不跨区域写状态。
  defp build_zone(zone, world_data, zones) do
    zone
    |> parse_exits(world_data, zones)
    |> parse_characters(world_data, zones)
    |> parse_items(world_data, zones)
    |> zone_items_to_list()
    |> zone_rooms_to_list()
    |> generate_minimap()
  rescue
    exception ->
      reraise LoaderError,
              [
                message: "区域数据处理失败",
                file: zone_file_path(zone.id),
                reason: exception
              ],
              __STACKTRACE__
  end

  # 约定区域文件名与 zones key 一致（liuxi -> data/world/liuxi.ucl）
  defp zone_file_path(zone_id), do: Path.join(@paths.world_path, "#{zone_id}.ucl")

  defp merge_world_data(zone_data) do
    zone_data = string_keys_to_atoms(zone_data)
    [key] = Map.keys(zone_data.zones)
    [{to_string(key), zone_data}]
  end

  defp string_keys_to_atoms(data) do
    case data do
      %{__struct__: _} = struct ->
        struct
      map when is_map(map) ->
        map
        |> Enum.into(%{}, fn {k, v} ->
          {key_to_atom(k), string_keys_to_atoms(v)}
        end)
      list when is_list(list) ->
        Enum.map(list, &string_keys_to_atoms/1)
      other ->
        other
    end
  end

  defp key_to_atom(key) do
    case key do
      k when is_binary(k) -> String.to_existing_atom(k)
      k when is_atom(k) -> k
      other -> other
    end
  end

  defp zone_items_to_list(zone) do
    items = Map.values(zone.items)
    %{zone | items: items}
  end

  defp zone_rooms_to_list(zone) do
    rooms = Map.values(zone.rooms)
    %{zone | rooms: rooms}
  end

  @doc """
  Load help files
  """
  def load_help(path \\ @paths.help_path) do
    ls!(path)
    |> Enum.map(fn file ->
      load_help_file(Path.join(path, file))
    end)
  end

  defp load_help_file(path) do
    [ucl, content] =
      path
      |> File.read!()
      |> String.split("---")

    help_topic =
      ucl
      |> Elias.parse()
      |> Map.put(:content, String.trim(content))

    struct(Kalevala.Help.HelpTopic, help_topic)
  rescue
    exception ->
      reraise LoaderError,
              [message: "帮助文件处理失败", file: path, reason: exception],
              __STACKTRACE__
  end

  @doc """
  Parse verb data into structs
  """
  def parse_verbs(%{verbs: verbs}) do
    verbs
    |> Enum.map(fn {key, verb} ->
      {key, Map.put(verb, :key, key)}
    end)
    |> Enum.map(fn {key, verb} ->
      conditions = struct(Kalevala.Verb.Conditions, verb.conditions)
      {key, Map.put(verb, :conditions, conditions)}
    end)
    |> Enum.map(fn {key, verb} ->
      {key, struct(Kalevala.Verb, verb)}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Parse a zone

  Loads basic data and rooms
  """
  def parse_zone({key, zone_data}, context) do
    zone = %Zone{}
    seed? = Map.get(zone_data, :seed, "true") == "true"

    name = get_in(zone_data.zones, [String.to_atom(key), :name])
    zone = %{zone | id: to_string(key), name: name, seed?: seed?}

    rooms = Map.get(zone_data, :rooms, [])

    rooms =
      Enum.into(rooms, %{}, fn {key, room_data} ->
        parse_room(zone, key, room_data, zone_data)
      end)

    characters = Map.get(zone_data, :characters, [])

    characters =
      Enum.into(characters, %{}, fn {key, character_data} ->
        parse_character(zone, key, character_data, context.brains)
      end)

    items = Map.get(zone_data, :items, [])

    items =
      Enum.into(items, %{}, fn {key, item_data} ->
        parse_item(zone, key, item_data, context.verbs)
      end)

    %{zone | rooms: rooms, characters: characters, items: items}
  end

  @doc """
  Parse room data

  ID is the zone's id concatenated with the room's key
  """
  def parse_room(zone, key, room_data, zone_data) do
    room = %Room{
      id: "#{zone.id}:#{key}",
      key: to_string(key),
      zone_id: zone.id,
      name: room_data.name,
      description: room_data.description,
      map_color: Map.get(room_data, :map_color),
      map_icon: Map.get(room_data, :map_icon),
      x: room_data.x,
      y: room_data.y,
      z: room_data.z,
      flags: parse_flags(Map.get(room_data, :flags)),
      features: parse_features(room_data, zone_data),
      item_desc: parse_item_desc(Map.get(room_data, :item_desc)),
      exit_vetoes: parse_room_vetoes(Map.get(room_data, :valid_leave)),
      behavior: Map.get(room_data, :behavior),
      behavior_config: parse_behavior_config(Map.get(room_data, :behavior_config))
    }

    {key, room}
  end

  # 房间墙上器物/菜单（LPC set("item_desc", ...)）：keyword -> 文本
  # 房间级行为配置（LPC set("behavior_config", ...)），目前只有 guarded_exit。
  #
  # 只认两种方向表达，因为原 LPC 的 valid_leave 就是这两种写法：
  #   guard_directions  = ["north"]   这些方向要盘查
  #   exempt_directions = ["south"]   除这些方向外都盘查
  #
  # 转换器统一记成单个 `direction`，但它不可靠：shenlong:dating / zoulang 上
  # 记的恰好是「豁免的那个方向」（语义相反），hengyang:zhurongdian 与
  # taohua:dating 又只记了两个盘查方向中的一个。所以不能直接采信，见 B 节。
  defp parse_behavior_config(nil), do: nil

  defp parse_behavior_config(cfg) when is_map(cfg) do
    Enum.reduce(cfg, %{}, fn {k, v}, acc ->
      Map.put(acc, behavior_key(k), normalize_behavior_value(v))
    end)
  end

  defp parse_behavior_config(_), do: nil

  defp behavior_key(key) when is_atom(key), do: key
  defp behavior_key(key) when is_binary(key), do: String.to_atom(key)
  defp behavior_key(key), do: key

  defp normalize_behavior_value(v) when is_list(v), do: Enum.map(v, &to_string/1)
  defp normalize_behavior_value(v) when is_binary(v), do: v
  defp normalize_behavior_value(v) when is_atom(v) and not is_nil(v), do: to_string(v)
  defp normalize_behavior_value(v), do: v

  defp parse_item_desc(nil), do: %{}

  defp parse_item_desc(item_desc) when is_map(item_desc) do
    Enum.reduce(item_desc, %{}, fn {key, value}, acc ->
      Map.put(acc, keyword_to_string(key), to_string(value))
    end)
  end

  defp parse_item_desc(_), do: %{}

  # 出口阻挡兜底消息（LPC valid_leave 的 notify_fail）：结构化保留，不做数据驱动拦截
  defp parse_room_vetoes(nil), do: []

  defp parse_room_vetoes(vetoes) when is_list(vetoes) do
    Enum.map(vetoes, fn
      %{} = veto ->
        %{
          direction: to_veto_dir(Map.get(veto, :direction)),
          condition: to_string_or_nil(Map.get(veto, :condition)),
          message: to_string_or_nil(Map.get(veto, :message)),
          # `all_dirs = true` 表示这条条件在 LPC 里本来就拦所有方向
          # （例如厨房里端着汤不许走）。缺这个标记而条件里又没有 dir 时，
          # 按「转换器丢了外层守卫」处理，运行时跳过 —— 宁可少拦，不能锁死玩家。
# 注意：Elias 把 UCL 里的 `true` 解析成**字符串** "true"（不是布尔、也不是原子），
      # 三种形态都接受，避免以后有人手改数据时静默失效。
      all_dirs: Map.get(veto, :all_dirs) in [true, :true, "true"]
        }

      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_room_vetoes(_), do: []

  defp to_veto_dir("~"), do: "*"
  defp to_veto_dir(nil), do: "*"
  defp to_veto_dir(dir), do: to_string(dir)

  defp to_string_or_nil(nil), do: nil
  defp to_string_or_nil(:nil), do: nil
  defp to_string_or_nil(v), do: to_string(v)

  defp keyword_to_string(key) when is_atom(key), do: Atom.to_string(key)
  defp keyword_to_string(key) when is_binary(key), do: key
  defp keyword_to_string(key), do: to_string(key)

  # 房间标志位（A5/D2）：no_fight/outdoors/water/startroom；
  # outdoors/water 本期只存不用（供日后天气/溺水）
  defp parse_flags(nil), do: []
  defp parse_flags(flags) when is_list(flags), do: Enum.map(flags, &to_string/1)
  defp parse_flags(flag) when is_binary(flag), do: [flag]
  defp parse_flags(_), do: []

  def parse_features(%{features: features}, zone_data) when is_list(features) do
    Enum.map(features, fn feature ->
      parse_feature(feature, zone_data)
    end)
  end

  def parse_features(_room, _zone_data), do: []

  defp parse_feature(%{ref: "features." <> ref}, zone_data) do
    feature = Map.get(zone_data.features, String.to_atom(ref))
    parse_feature(feature, zone_data)
  end

  defp parse_feature(feature, _zone_data) do
    %Feature{
      id: feature.keyword,
      keyword: feature.keyword,
      short_description: feature.short,
      description: feature.long
    }
  end

  @doc """
  Parse character data

  ID is the zone's id concatenated with the character's key

  支持可选的 `combat {}` 块描述武侠战斗属性：

      characters "heihu" {
        name = "黑虎"
        combat = {
          attitude = "aggressive"
          max_qi = 900
          str = 30
          combat_exp = 8000
          skills = { unarmed = 80, dodge = 70 }
          map_skill = { sword = "liuxin-jian" }
          apply = { attack = 45, damage = 35, armor = 20 }
        }
      }
  """
  def parse_character(zone, key, character_data, brains) do
    character = %Character{
      id: "#{zone.id}:#{key}",
      name: character_data.name,
      description: character_data.description,
      brain:
        character_data
        |> build_brain(brains),
      meta: %Kantele.Character.NonPlayerMeta{
        zone_id: zone.id,
        initial_events: parse_initial_events(character_data),
        vitals: npc_vitals(Map.get(character_data, :combat)),
        stats: npc_stats(Map.get(character_data, :combat)),
        combat_config: npc_combat_config(Map.get(character_data, :combat)),
        combat: Kantele.Character.Combat.new(),
        goods: parse_goods(Map.get(character_data, :goods)),
        inquiries: parse_inquiries(Map.get(character_data, :inquiries)),
        aliases: parse_aliases(Map.get(character_data, :aliases)),
        teach: parse_teach(Map.get(character_data, :teach)),
        apprentice: parse_apprentice(Map.get(character_data, :apprentice)),
        turn_in: parse_turn_in(Map.get(character_data, :turn_in)),
        quest: parse_quest(Map.get(character_data, :quest)),
        coagents: parse_coagents(Map.get(character_data, :coagents)),
        parts: parse_parts(Map.get(character_data, :parts)),
        no_cut: parse_no_cut(Map.get(character_data, :no_cut)),
        default_clone:
          Map.get(character_data, :default_clone) &&
            to_string(Map.get(character_data, :default_clone)),
        loot: parse_goods(Map.get(character_data, :loot)),
        greetings: parse_greetings(Map.get(character_data, :greetings)),
        init: parse_enter_init(Map.get(character_data, :init)),
        accept: parse_accept_rules(Map.get(character_data, :accept)),
        guarder: parse_guarder(Map.get(Map.get(character_data, :meta, %{}), :guarder)),
        engage: parse_engage(Map.get(character_data, :engage)),
        carry: parse_carry(Map.get(character_data, :carry))
      }
    }

    character = attach_npc_applies(character, Map.get(character_data, :combat))

    {key, character}
  end

  @doc """
  LPC `carry_object(...)`：NPC 出生时随身带的装备。

  转换器把 LPC 的

      carry_object("/clone/weapon/gangdao")->wield();
      carry_object("/clone/cloth/cloth")->wear();

  降级成一条不带动作的列表：

      carry = [ { id = items.gangdao.id }, { id = items.cloth.id } ]

  **`wield()` / `wear()` 的动作信息在转换时丢了**，所以这里只把
  **item_id 列表**存进 `meta.carry`，真正「穿上 / 拿着」由
  `Kantele.Character.SpawnController` 在 NPC 进程起来时做 ——
  那时候 Items cache 已经就绪（见 `Kantele.World.Kickoff`：load 完
  第 138 行才 `cache_item`）。

  ⚠️ 曾经在 loader 里直接装备，结果 `Kantele.World.Items.get/1` 打
  `:ets.lookup` 时 ETS 表还不存在 -> `argument error`，
  整个 `kunming.ucl` 解析失败。**加载期不能碰 cache**。
  """
  def parse_carry(carry) when is_list(carry) do
    Enum.map(carry, fn entry -> entry && entry.id end)
  end

  def parse_carry(_), do: []


  defp build_brain(character_data, brains) do
    brain = Kantele.Brain.process(Map.get(character_data, :brain), brains)

    case chat_node(Map.get(character_data, :chat_chance), Map.get(character_data, :chats)) do
      nil ->
        brain

      node ->
        %Kalevala.Brain{
          root: %Kalevala.Brain.Sequence{
            nodes: [node, brain.root]
          }
        }
    end
  end

  # 概率闲聊：ChatChance 门控（冷却 + 概率）命中后从台词池随机说一条。
  #
  # 必须用 ChatChance 而不是裸的 Conditions.Random：NPC 订阅了所在房间频道，
  # ChatAction 又往同一频道发言，因此「发言 → 收到自己的事件 → 掷骰 → 再发言」
  # 会自激。房间里有 N 个同配置 NPC 时繁殖率 = N × chance/100，mingjiao 的
  # miaorenbuluo（4 个 miaozuwushi × chat_chance 30）达到 1.2 > 1，指数刷屏。
  # ChatChance 的时间冷却把过程变成有界速率。详见该模块的 @moduledoc。
  defp chat_node(chance, chats)
       when is_integer(chance) and chance > 0 and is_list(chats) and chats != [] do
    %Kalevala.Brain.ConditionalSelector{
      nodes: [
        %Kalevala.Brain.Condition{
          type: Kantele.Brain.Conditions.ChatChance,
          data: %{
            chance: chance,
            cooldown_ms: Kantele.Brain.Conditions.ChatChance.default_cooldown_ms()
          }
        },
        %Kalevala.Brain.Action{
          type: Kantele.Character.ChatAction,
          data: %{lines: Enum.map(chats, &to_string/1)},
          delay: 0
        }
      ]
    }
  end

  defp chat_node(_, _), do: nil

  # 商品表：UCL 写法与 room_items 一致（{ id = items.xxx.id } 对象数组），
  # 先存原始引用串，待 parse_characters 阶段有 zones 上下文时再解引用
  defp parse_goods(nil), do: nil

  defp parse_goods(goods) when is_list(goods) do
    Enum.map(goods, fn
      # `{ id = [items.a.id,items.b.id] }` - the converter's alternative list for
      # an LPC runtime pick, e.g. emei/cangjingge.c's
      #     __DIR__"obj/fojing1" + random(2)
      # The driver calls random(2) ONCE, so the room gets exactly one of the two.
      # Expand the list here and pick, rather than letting the converter emit
      # every candidate (which would put two fojings where the MUD puts one).
      %{id: choices} when is_list(choices) ->
        choices
        |> Enum.flat_map(fn
          item when is_binary(item) -> String.split(item, ",")
          _other -> []
        end)
        |> Enum.reject(&(String.trim(&1) == ""))
        |> case do
          [] -> nil
          candidates -> Enum.random(candidates)
        end

      %{id: ref} when is_binary(ref) ->
        ref

      ref when is_binary(ref) ->
        ref

      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_goods(_), do: nil

  # LPC set_name 的 id 表（present/ask/get 的匹配依据）
  defp parse_aliases(nil), do: []

  defp parse_aliases(list) when is_list(list) do
    Enum.map(list, &to_string/1)
  end

  defp parse_aliases(other) when is_binary(other), do: [other]
  defp parse_aliases(_), do: []

  # 商品引用形如 `items.<名>.id`（本区）或 `<区>.items.<名>.id`（跨区）。
  # 跨区是 LPC 原有语义：vendor_goods 里写的是绝对路径（`/d/xiyu/obj/fire`），
  # 哪个区的商人都能卖，因此引用也必须能指向别的区。
  # 只对「点分隔的小写标识符」尝试解引用，普通 id（含 `:`）原样保留。
  @item_ref ~r/^[a-z0-9_]+(?:\.[a-z0-9_]+)+$/

  defp resolve_goods(goods, zone, zones) when is_list(goods) do
    Enum.map(goods, fn
      ref when is_binary(ref) -> deref_item_ref(ref, zone, zones)
      id -> id
    end)
  end

  defp resolve_goods(goods, _zone, _zones), do: goods

  defp deref_item_ref(ref, zone, zones) do
    if Regex.match?(@item_ref, ref) do
      case safe_dereference(zones, zone, ref) do
        {:ok, item_id} when is_binary(item_id) -> item_id
        _ -> ref
      end
    else
      ref
    end
  end

  defp safe_dereference(zones, zone, reference) do
    {:ok, dereference(zones, zone, reference)}
  rescue
    _ -> :error
  end

  # 解引用任务交付物品（items.yupai.id -> "liuxi:yupai"，跨区同 goods）
  defp resolve_turn_in(nil, _zone, _zones), do: nil

  defp resolve_turn_in(turn_in, zone, zones) do
    item =
      case Map.get(turn_in, :item) do
        item when is_binary(item) ->
          case safe_dereference(zones, zone, item) do
            {:ok, item_id} when is_binary(item_id) ->
              item_id

            _ ->
              # 引用形态解不出 -> nil（悬空交付物）；普通 id 原样保留
              if Regex.match?(@item_ref, item), do: nil, else: item
          end

        _ ->
          nil
      end

    %{turn_in | item: item}
  end

  # 问答表：%{关键词 => 回答}，键统一字符串；值可为文本（直接回话）或
  # 脚本化 map（Q6 数据驱动事件：reply/give/learn_skill/family/gongxian）
  defp parse_inquiries(nil), do: nil

  defp parse_inquiries(inquiries) when is_map(inquiries) do
    Enum.into(inquiries, %{}, fn {key, value} ->
      {to_string(key), parse_inquiry_value(value)}
    end)
  end

  defp parse_inquiries(inquiries) when is_list(inquiries) do
    Enum.reduce(inquiries, %{}, fn item, acc ->
      case item do
        %{key: key, value: value} ->
          Map.put(acc, to_string(key), parse_inquiry_value(value))
        _ -> acc
      end
    end)
  end

  defp parse_inquiries(_), do: nil

  defp parse_inquiry_value(value) when is_map(value) do
    Enum.into(value, %{}, fn {key, val} ->
      key = to_string(key)
      {key, normalize_inquiry_field(key, val)}
    end)
  end

  defp parse_inquiry_value(value), do: to_string(value)

  # 授绝招配置的 min_levels 是嵌套 map：键归一为字符串（下划线->连字符，与
  # Stats.skills 键一致），否则 inquiry_grant 的技能门槛查不到等级。
  defp normalize_inquiry_field("min_levels", levels) when is_map(levels) do
    Enum.into(levels, %{}, fn {skill, level} ->
      {String.replace(to_string(skill), "_", "-"), level}
    end)
  end

  defp normalize_inquiry_field(_key, val), do: val

  # 欢迎台词池：UCL greetings = [ { line = "..." } ]，归一为字符串列表
  defp parse_greetings(nil), do: nil

  defp parse_greetings(greetings) when is_list(greetings) do
    Enum.map(greetings, fn
      %{line: line} when is_binary(line) -> line
      line when is_binary(line) -> line
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      lines -> lines
    end
  end

  defp parse_greetings(_), do: nil

  # 入场配置：UCL init = { greet_delay = 1  add_actions = [...]  heartbeat = 5 }
  defp parse_enter_init(nil), do: nil

  defp parse_enter_init(init) when is_map(init) do
    add_actions =
      case Map.get(init, :add_actions) do
        list when is_list(list) -> Enum.map(list, &to_string/1)
        _ -> []
      end

    %{
      greet_delay: Map.get(init, :greet_delay) || 0,
      add_actions: add_actions,
      heartbeat: Map.get(init, :heartbeat) || 0
    }
  end

  defp parse_enter_init(_), do: nil

  # 收受规则（accept_object）：UCL accept = [ { kind = "money" min = 1000 } ... ]
  defp parse_accept_rules(nil), do: nil

  defp parse_accept_rules(rules) when is_list(rules) do
    Enum.map(rules, fn rule when is_map(rule) ->
      kind = Map.get(rule, :kind)

      if kind in ["money", "item_id", "item_name", "any"] do
        %{
          kind: kind,
          min: numeric_or_nil(Map.get(rule, :min)),
          id: string_or_nil(Map.get(rule, :id)),
          name: string_or_nil(Map.get(rule, :name)),
          accept: to_bool(Map.get(rule, :accept, true)),
          msg: accept_msg(Map.get(rule, :msg)),
          fail_msg: accept_msg(Map.get(rule, :fail_msg))
        }
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      clean -> clean
    end
  end

  defp parse_accept_rules(_), do: nil

  # 守卫配置：UCL guarder = { family = "白驼山庄" msgs = { refuse_other = "..." } }
  defp parse_guarder(nil), do: nil

  defp parse_guarder(guarder) when is_map(guarder) do
    family = string_or_nil(Map.get(guarder, :family))
    msgs = Map.get(guarder, :msgs)

    if is_nil(family) do
      nil
    else
      parsed_msgs = if is_map(msgs), do: msgs, else: %{}
      %{
        family: family,
        msgs: parsed_msgs
      }
    end
  end

  defp parse_guarder(_), do: nil

  # 开战接受规则（accept_fight/hit/kill）：
  # UCL engage = {
  #   fight = { accept = false msg = "..." }
  #   hit   = { accept = true retaliate = true msg = "..." }
  #   kill  = { accept = false spawn = ["baobiao"] }
  # }
  defp parse_engage(nil), do: nil

  defp parse_engage(engage) when is_map(engage) do
    parsed =
      Enum.reduce([:fight, :hit, :kill], %{}, fn key, acc ->
        case Map.get(engage, key) do
          nil ->
            acc

          rule when is_map(rule) ->
            accept = parse_engage_accept(Map.get(rule, :accept))

            if is_nil(accept) do
              acc
            else
              Map.put(acc, key, %{
                accept: accept,
                msg: string_or_nil(Map.get(rule, :msg)),
                retaliate: to_bool(Map.get(rule, :retaliate, false)),
                spawn:
                  case Map.get(rule, :spawn) do
                    list when is_list(list) -> Enum.map(list, &to_string/1)
                    item when not is_nil(item) -> [to_string(item)]
                    _ -> []
                  end
              })
            end

          _ ->
            acc
        end
      end)

    case parsed do
      %{} = p when map_size(p) > 0 -> p
      _ -> nil
    end
  end

  defp parse_engage(_), do: nil

  # accept 转布尔：true/false（含字符串形式）之外一律按缺省放行（nil = 无规则）
  defp parse_engage_accept(true), do: true
  defp parse_engage_accept(false), do: false
  defp parse_engage_accept("true"), do: true
  defp parse_engage_accept("false"), do: false
  defp parse_engage_accept(value) when value in [1, "1", 0, "0"] do
    value == 1 or value == "1"
  end
  defp parse_engage_accept(_), do: nil

  defp numeric_or_nil(v) when is_integer(v), do: v
  defp numeric_or_nil(v) when is_binary(v), do: String.to_integer(v)
  defp numeric_or_nil(_), do: nil

  defp string_or_nil(v) when is_binary(v), do: v
  defp string_or_nil(v) when is_atom(v) and not is_nil(v), do: to_string(v)
  defp string_or_nil(_), do: nil

  # accept 规则台词：单条字符串或台词池（列表）→ 统一归一为台词池；空池为 nil
  defp accept_msg(nil), do: nil
  defp accept_msg(v) when is_binary(v), do: [v]
  defp accept_msg(v) when is_list(v) do
    v = Enum.reject(v, &(not is_binary(&1) or &1 == ""))
    if v == [], do: nil, else: v
  end
  defp accept_msg(_), do: nil

  defp to_bool(v) when v in [true, "true", 1, "1"], do: true
  defp to_bool(_), do: false

  # 教学配置（A11/D4）：归一化字符串键，本期只解析落位供门派信息展示，
  # 消费端校验等 b 期 learn 重构接入
  defp parse_teach(nil), do: nil

  defp parse_teach(teach) when is_map(teach) do
    teach_skills =
      case Map.get(teach, :teach_skills) do
        skills when is_map(skills) ->
          Enum.into(skills, %{}, fn {key, conf} ->
            skill_id = String.replace(to_string(key), "_", "-")

            conf =
              case conf do
                %{max: max, gongxian: gongxian} ->
                  %{max: max, gongxian: gongxian}

                %{max: max} ->
                  %{max: max, gongxian: 0}

                _ ->
                  %{max: 0, gongxian: 0}
              end

            {skill_id, conf}
          end)

        _ ->
          %{}
      end

    no_teach =
      case Map.get(teach, :no_teach) do
        list when is_list(list) -> Enum.map(list, &to_string/1)
        _ -> []
      end

    %{
      family: Map.get(teach, :family) && to_string(Map.get(teach, :family)),
      teach_skills: teach_skills,
      no_teach: no_teach
    }
  end

  defp parse_teach(_), do: nil

  # 收徒门槛（F3 切片 1）：镜像 parse_teach/1 的卫句/归约形状。
  # UCL 例 apprentice = {
  #   family = "武当派"
  #   min_shen = 20000  min_exp = 300000
  #   min_skills = { sword = 80  force = 60 }
  #   no_recruit = [ "张翠山" ]
  # }
  defp parse_apprentice(nil), do: nil

  defp parse_apprentice(apprentice) when is_map(apprentice) do
    min_skills =
      case Map.get(apprentice, :min_skills) do
        skills when is_map(skills) ->
          Enum.into(skills, %{}, fn {key, level} ->
            {String.replace(to_string(key), "_", "-"), level}
          end)

        _ ->
          %{}
      end

    no_recruit =
      case Map.get(apprentice, :no_recruit) do
        list when is_list(list) -> Enum.map(list, &to_string/1)
        _ -> []
      end

    # class 继承（F3 切片 6）：LPC attempt_apprentice 成功时 ob->set("class", ...)
    class =
      case Map.get(apprentice, :class) do
        value when is_binary(value) -> value
        value when is_atom(value) and not is_nil(value) -> to_string(value)
        _ -> nil
      end

    %{
      family: Map.get(apprentice, :family) && to_string(Map.get(apprentice, :family)),
      min_shen: Map.get(apprentice, :min_shen) || 0,
      min_exp: Map.get(apprentice, :min_exp) || 0,
      min_skills: min_skills,
      no_recruit: no_recruit,
      class: class
    }
  end

  defp parse_apprentice(_), do: nil

  # 任务交付（A11/N6 v0）：item 为引用串（items.yupai.id），延后到 parse_characters 解
  defp parse_turn_in(nil), do: nil

  defp parse_turn_in(turn_in) when is_map(turn_in) do
    rewards =
      case Map.get(turn_in, :rewards) do
        rewards when is_map(rewards) -> rewards
        _ -> %{}
      end

    %{
      quest: Map.get(turn_in, :quest) && to_string(Map.get(turn_in, :quest)),
      item: Map.get(turn_in, :item) && to_string(Map.get(turn_in, :item)),
      prompt: Map.get(turn_in, :prompt) && to_string(Map.get(turn_in, :prompt)),
      rumor: Map.get(turn_in, :rumor) && to_string(Map.get(turn_in, :rumor)),
      rewards: %{
        exp: Map.get(rewards, :exp) || 0,
        potential: Map.get(rewards, :potential) || 0,
        score: Map.get(rewards, :score) || 0,
        weiwang: Map.get(rewards, :weiwang) || 0,
        coins: Map.get(rewards, :coins) || 0
      }
    }
  end

  defp parse_turn_in(_), do: nil

  # 任务发布（A11/N6 v1 + Q1-T2）：NPC 可发布的任务规格
  # UCL 例：quest = { file = "song-yupai", kill = ["monster1"], item = ["item1"] }
  # 扩展字段（Q1-T2/T4，透传供 quest.ex meta / 阶梯奖励 / 链式前置）：
  # type / level / limit / repeatable / master_name / master_id / chain / mutex
  defp parse_quest(nil), do: nil

  defp parse_quest(quest) when is_map(quest) do
    base = %{
      file: Map.get(quest, :file) && to_string(Map.get(quest, :file)),
      kill: Map.get(quest, :kill) && List.wrap(Map.get(quest, :kill)) |> Enum.map(&to_string/1),
      item: Map.get(quest, :item) && List.wrap(Map.get(quest, :item)) |> Enum.map(&to_string/1)
    }

    extra =
      quest
      |> Map.take([:type, :level, :limit, :repeatable, :master_name, :master_id,
        :chain, :mutex])
      |> Map.update(:chain, [], fn
        nil -> []
        chain -> List.wrap(chain) |> Enum.map(&to_string/1)
      end)
      |> Map.update(:mutex, [], fn
        nil -> []
        mutex -> List.wrap(mutex) |> Enum.map(&to_string/1)
      end)

    Map.merge(base, extra)
  end

  defp parse_quest(_), do: nil

  # 帮手列表（coagent.c）：UCL 例 coagents = ["liuxi:mafu"]，帮手 NPC 的 id 列表
  defp parse_coagents(nil), do: nil

  defp parse_coagents(coagents) do
    coagents
    |> List.wrap()
    |> Enum.map(&to_string/1)
  end

  # 可切割部位（cutable.c）：UCL 例 parts = {
  #   head = { level = 3, unit = "颗", name = "头", name_left = "头",
  #            id_left = "head", verb = "割了下来", clone = "meat" }
  # }
  # 归一化为 8 字段数组对齐 cutable.c：[level, unit, name, name_left, id_left,
  # ass_part, verb, clone]；ass_part 为关联部位 id => 新 id 映射。
  defp parse_parts(nil), do: nil

  defp parse_parts(parts) when is_map(parts) do
    Map.new(parts, fn {id, part} ->
      {to_string(id), normalize_part(part)}
    end)
  end

  defp parse_parts(_), do: nil

  defp normalize_part(part) when is_map(part) do
    [
      Map.get(part, :level) || 0,
      of_binary(Map.get(part, :unit)),
      of_binary(Map.get(part, :name)),
      of_binary(Map.get(part, :name_left)),
      of_binary(Map.get(part, :id_left)),
      parse_ass_part(Map.get(part, :ass_part)),
      of_binary(Map.get(part, :verb)),
      of_binary(Map.get(part, :clone))
    ]
  end

  defp normalize_part(_), do: nil

  defp parse_ass_part(nil), do: nil

  defp parse_ass_part(ass) when is_map(ass) do
    Map.new(ass, fn {k, v} -> {to_string(k), to_string(v)} end)
  end

  defp parse_ass_part(_), do: nil

  # 不可切割部位（cutable.c no_cut）：UCL 例 no_cut = { horn = "这样东西你割不下来。" }
  defp parse_no_cut(nil), do: %{}

  defp parse_no_cut(no_cut) when is_map(no_cut) do
    Map.new(no_cut, fn {k, v} ->
      {to_string(k), if(is_binary(v), do: v, else: true)}
    end)
  end

  defp parse_no_cut(_), do: %{}

  defp of_binary(nil), do: nil
  defp of_binary(value), do: to_string(value)

  defp npc_vitals(nil), do: Kantele.Character.Vitals.new()

  defp npc_vitals(combat) do
    base = Kantele.Character.Vitals.new()

    %Kantele.Character.Vitals{
      qi: Map.get(combat, :max_qi, base.qi),
      max_qi: Map.get(combat, :max_qi, base.max_qi),
      base_qi: Map.get(combat, :max_qi, base.max_qi),
      jing: Map.get(combat, :max_jing, base.jing),
      max_jing: Map.get(combat, :max_jing, base.max_jing),
      base_jing: Map.get(combat, :max_jing, base.max_jing),
      neili: Map.get(combat, :max_neili, base.neili),
      max_neili: Map.get(combat, :max_neili, base.max_neili),
      base_neili: Map.get(combat, :max_neili, base.max_neili)
    }
  end

  defp npc_stats(nil), do: Stats.new()

  defp npc_stats(combat) do
    %Stats{
      str: Map.get(combat, :str, 20),
      dex: Map.get(combat, :dex, 20),
      con: Map.get(combat, :con, 20),
      int: Map.get(combat, :int, 20),
      combat_exp: Map.get(combat, :combat_exp, 0),
      potential: Map.get(combat, :potential, 0),
      score: 0,
      weiwang: 0,
      gongxian: 0,
      shen: 0,
      skills: skill_keys(Map.get(combat, :skills, %{})),
      mapped: skill_keys(Map.get(combat, :map_skill, %{})),
      performs: MapSet.new()
    }
  end

  # UCL 键名不支持横线，约定用下划线书写（liuxin_jian -> liuxin-jian）
  defp skill_keys(map) do
    Enum.into(map, %{}, fn {key, value} ->
      {String.replace(to_string(key), "_", "-"), value}
    end)
  end

  defp npc_combat_config(combat) when combat != nil do
    %Kantele.Character.NPCConfig{
      attitude: Map.get(combat, :attitude),
      no_kill: Map.get(combat, :no_kill) in [true, "true"],
      spawn_room_id: nil,
      respawn_delay: Map.get(combat, :respawn_delay),
      apply:
        Kantele.Character.Combat.new().temp
        |> Map.merge(stringify_apply(Map.get(combat, :apply, %{})))
    }
  end

  defp npc_combat_config(_), do: Kantele.Character.NPCConfig.new()

  defp attach_npc_applies(character, combat) when combat != nil do
    apply = stringify_apply(Map.get(combat, :apply, %{}))

    # 空手攻击读取 unarmed_damage：未单独配置时沿用 damage（LPC NPC 惯例）
    apply =
      case Map.get(apply, :damage) do
        nil -> apply
        dmg -> Map.put_new(apply, :unarmed_damage, dmg)
      end

    combat_state = Kantele.Character.Combat.apply_temp(character.meta.combat, apply)
    meta = Map.put(character.meta, :combat, combat_state)

    %{character | meta: meta}
  end

  defp attach_npc_applies(character, _), do: character

  defp stringify_map(map) do
    Enum.into(map, %{}, fn {key, value} -> {to_string(key), value} end)
  end

  defp stringify_apply(apply) do
    apply
    |> stringify_map()
    |> Enum.into(%{}, fn {key, value} ->
      {String.to_atom(key), value}
    end)
  end

  defp parse_initial_events(%{initial_events: initial_events}) do
    Enum.map(initial_events, fn initial_event ->
      %Kantele.Character.InitialEvent{
        data: initial_event.data,
        delay: initial_event.delay,
        topic: initial_event.topic
      }
    end)
  end

  defp parse_initial_events(_), do: []

  @doc """
  Parse item data

  ID is the zone's id concatenated with the item's key

  支持可选的 `meta = {}` 块描述战斗属性（damage/skill_type/armor/value）
  """
  def parse_item(zone, key, item_data, verbs) do
    item_verbs =
      item_data.verbs
      |> Enum.map(&String.to_atom/1)
      |> Enum.map(fn verb ->
        Map.get(verbs, verb)
      end)

    # LPC 的 id 表写在物品块的**顶层**（与 name 同级，scripts/migrate_aliases.py 的写法），
    # 而 parse_item_meta 只认 meta.aliases —— 两处都读，否则已有数据的别名会被丢掉
    # （`present("<拼音id>", room)` 就匹配不到物品）。
    item_meta = parse_item_meta(Map.get(item_data, :meta))

    item_meta = %{
      item_meta
      | aliases: Enum.uniq((item_meta.aliases || []) ++ parse_aliases(Map.get(item_data, :aliases)))
    }
    item = %Item{
      id: "#{zone.id}:#{key}",
      name: item_data.name,
      description: item_data.description,
      verbs: item_verbs,
      callback_module: Kantele.World.Item,
      meta: item_meta
    }

    {key, item}
  end

  defp parse_item_meta(nil), do: %Kantele.World.Item.Meta{}

  defp parse_item_meta(meta) do
    # 注意不能用 %Item.Meta{}：本模块顶部 alias 的 Item 指 Kalevala.World.Item
    meta = %Kantele.World.Item.Meta{
      damage: Map.get(meta, :damage),
      skill_type: Map.get(meta, :skill_type),
      armor: Map.get(meta, :armor),
      value: Map.get(meta, :value),
      weight: Map.get(meta, :weight),
      unit: Map.get(meta, :unit),
      material: Map.get(meta, :material),
      food: Map.get(meta, :food),
      medicine: parse_medicine(Map.get(meta, :medicine)),
      book: parse_book(Map.get(meta, :book)),
      armor_type: Kantele.World.Item.Meta.normalize_armor_type(Map.get(meta, :armor_type)),
      weapon_prop: Kantele.World.Item.Meta.sanitize_prop(Map.get(meta, :weapon_prop)),
      armor_prop: Kantele.World.Item.Meta.sanitize_prop(Map.get(meta, :armor_prop)),
      flag: Map.get(meta, :flag) || 1,
      storage_bag: Map.get(meta, :storage_bag),
      no_sell: Map.get(meta, :no_sell),
      no_put: Map.get(meta, :no_put),
      owner: Map.get(meta, :owner),
      owner_id: Map.get(meta, :owner_id),
      aliases: parse_aliases(Map.get(meta, :aliases))
    }

    meta
  end

  # 药效原样透传（qi/jing/neili/stats 等键由消费端定义），非 map 一律丢弃
  defp parse_medicine(nil), do: nil
  defp parse_medicine(medicine) when is_map(medicine), do: medicine
  defp parse_medicine(_), do: nil

  defp parse_book(nil), do: nil

  defp parse_book(book) when is_map(book) do
    %Kantele.World.Item.Meta.Book{
      skill: Map.get(book, :skill),
      min_skill: Map.get(book, :min_skill),
      max_skill: Map.get(book, :max_skill),
      exp_required: Map.get(book, :exp_required),
      jing_cost: Map.get(book, :jing_cost),
      difficulty: Map.get(book, :difficulty)
    }
  end

  defp parse_book(_), do: nil

  @doc """
  Collapse a runtime-picked exit target to a single room reference.

  Some LPC rooms choose their destination at run time, e.g. gaochang/shulin1.c

      "east" : __DIR__"shulin" + (random(10) + 2),

  which names one of shulin2..shulin11.  lpc_converter.py expands the whole set
  into a bracketed UCL list of candidates:

      east = [rooms.shulin2.id,rooms.shulin3.id,...,rooms.shulin11.id]

  elias parses that as a one-element array whose single element is the whole
  comma-joined string (it has no nested-reference grammar), so unwrap it, split
  on commas, and pick one - the same choice `random(n) + k` made in the driver.
  The pick happens once, at load time, so a room's exits are stable for the
  lifetime of the world rather than changing on every step.
  """
  defp pick_runtime_exit(value) when is_list(value) do
    value
    |> Enum.flat_map(fn
      item when is_binary(item) -> String.split(item, ",")
      _other -> []
    end)
    |> Enum.reject(&(String.trim(&1) == ""))
    |> case do
      [] -> nil
      candidates -> Enum.random(candidates)
    end
  end

  defp pick_runtime_exit(value), do: value

  @doc """
  Parse exits for zones

  Dereferences the exit exit_names, creates structs for each exit_name,
  and attaches them to the matching room.
  """
  def parse_exits(zone, data, zones) do
    zone_data = Map.get(data, zone.id)

    room_exits = Map.get(zone_data, :room_exits, [])

    exits =
      Enum.flat_map(room_exits, fn {_key, room_exit} ->
        room_exit =
          Enum.into(room_exit, %{}, fn {key, value} ->
            {key, dereference(zones, zone, pick_runtime_exit(value))}
          end)

        room_id = room_exit.room_id
        room_exit = Map.delete(room_exit, :room_id)

        room_exit
        |> Enum.filter(fn {_key, value} -> not is_nil(value) end)
        |> Enum.map(fn {key, value} ->
          %Kalevala.World.Exit{
            id: "#{room_id}:#{key}",
            exit_name: to_string(key),
            start_room_id: room_id,
            end_room_id: value
          }
        end)
      end)

    Enum.reduce(exits, zone, fn exit, zone ->
      {room_key, room} =
        Enum.find(zone.rooms, fn {_key, room} ->
          room.id == exit.start_room_id
        end)

      room = %{room | exits: [exit | room.exits]}

      rooms = Map.put(zone.rooms, room_key, room)
      %{zone | rooms: rooms}
    end)
  end

  @doc """
  Parse characters for zones

  Dereferences the world characters, creates structs and attachs them to the
  matching room.
  """
  def parse_characters(zone, data, zones) do
    zone_data = Map.get(data, zone.id)

    room_characters = Map.get(zone_data, :room_characters, [])

    characters =
      Enum.flat_map(room_characters, fn {_key, room_character} ->
        room_id = dereference(zones, zone, room_character.room_id)

        room_character.characters
        |> Enum.with_index()
        |> Enum.flat_map(fn {character_data, index} ->
          case find_character_for_room(zones, zone, character_data.id) do
            {_key, character} ->
              meta = character.meta
              combat_config = Map.get(meta, :combat_config)

              combat_config =
                case combat_config do
                  %Kantele.Character.NPCConfig{} ->
                    %{combat_config | spawn_room_id: room_id}

                  _ ->
                    combat_config
                end

              meta = %{meta | combat_config: combat_config}

              # 商品引用此时才有 zones 上下文可解（A10/N2）
              meta = %{meta | goods: resolve_goods(Map.get(meta, :goods), zone, zones)}

              # 任务交付物品引用同上（A11/N6）；掉落表同商品解引用
              meta = %{meta | turn_in: resolve_turn_in(Map.get(meta, :turn_in), zone, zones)}
              meta = %{meta | loot: resolve_goods(Map.get(meta, :loot), zone, zones)}

              # 随身装备的物品引用同商品：此时才有 zones 上下文可解。
              # 之前没解，meta.carry 里存的是原始引用串 `"items.cloth.id"`，
              # 到 SpawnController 按 item_id 查 Items cache 时全都 not_found。
              meta = %{meta | carry: resolve_goods(Map.get(meta, :carry), zone, zones)}
              meta = %{meta | quest: Map.get(meta, :quest)}

              [
                %Character{
                  character
                  | id: "#{room_id}:#{character.id}:#{index}",
                    name: Map.get(character_data, :name, character.name),
                    room_id: room_id,
                    meta: meta
                }
              ]

            nil ->
              # NPC 数据缺失（引用不存在）时跳过，避免悬挂引用。
              #
              # 但**必须 warn** —— 静默跳过会让「数据里写了引用、运行时其实
              # 不存在」这类问题长期查不出来。转换器把 LPC
              # `set("objects", ...)` 里的 NPC 错写成 `items.X` 时就是这么
              # 藏了很久的：房间一直是空的，相关 valid_leave 门禁永不触发，
              # 而加载日志一个字都没有。见 docs/dangling-room-items-report.zh-CN.md。
              warn_unresolved(:character, zone.id, room_id, character_data.id)

              []
          end
        end)
      end)

    Enum.reduce(characters, zone, fn character, zone ->
      {room_key, room} =
        Enum.find(zone.rooms, fn {_key, room} ->
          room.id == character.room_id
        end)

      characters = Map.get(room, :characters, [])
      character = %{character | id: Character.generate_id()}
      room = Map.put(room, :characters, [character | characters])

      rooms = Map.put(zone.rooms, room_key, room)
      %{zone | rooms: rooms}
    end)
  end

  defp match_character({_key, character}, character_id), do: character.id == character_id

  # 房间摆放的 NPC：**本区优先，找不到才去 clone_lib**。
  #
  # 对应 LPC 里作者图省事的跨区引用（`d/baituo/jiudian.c` 写
  # `"/d/city/npc/xiaoer2"`）。按 clone/ 约定这类共享角色应该在 clone_lib，
  # 所以那边备了一份；UCL 里**保持 `characters.x.id` 的裸引用**，
  # 不改成 `clone_lib.characters.x.id` —— 那样虽然也能work，但有两个坏处：
  #   1. 数据里出现区名前缀，与转换器产物不一致，重转就会漂移；
  #   2. 同名不同人的情况会被抹平。实测 `bing` 在 clone_lib 是「官兵」，
  #      而 dali 自己的 bing 是「士兵」、xiangyang 的是「宋兵 exp20000」——
  #      这些区有本地定义，本就该用自己的。
  #
  # `dereference/3` 里已经会对 characters/rooms/items 统一回退到 clone_lib，
  # 这里补的是**拿到 id 之后按 id 找定义**的那一步 —— 之前只在 `zone.characters`
  # 里找，clone_lib 的 id 匹配不上，于是共享角色仍被当成悬空丢掉。
defp find_character_for_room(zones, zone, reference) do
    character_id = dereference(zones, zone, reference)

    case Enum.find(zone.characters, &match_character(&1, character_id)) do
      nil ->
        # 本区没有 -> clone_lib（find_character/3 按 "#{zone.id}:#{name}" 拼 id，
        # 所以这里要传 clone 自己，否则会拼成本区的 id）
        clone = Enum.find(zones, fn z -> z.id == @clone_zone_id end)

        if clone && clone.id != zone.id do
          Enum.find(clone.characters, &match_character(&1, character_id))
        end

      found ->
        found
    end
  end

  @doc """
  Parse items for zones

  Dereferences the world items, creates structs and attachs them to the
  matching room.
  """
  def parse_items(zone, data, zones) do
    zone_data = Map.get(data, zone.id)

    room_items = Map.get(zone_data, :room_items, [])

    Enum.reduce(room_items, zone, fn {_key, room_item}, zone ->
      room_id = dereference(zones, zone, room_item.room_id)

      Enum.reduce(room_item.items, zone, fn item_data, zone ->
        # `{ id = [items.a.id,items.b.id] }` - the converter's alternative list for
        # an LPC runtime pick, e.g. emei/cangjingge.c's
        #     __DIR__"obj/fojing1" + random(2)
        # The driver calls random(2) ONCE per key, so the room ends up with exactly
        # one of the two.  Picking here (rather than letting the converter emit
        # every candidate) keeps the room's contents the same size as the MUD's.
        item_id =
          case item_data do
            %{id: choices} when is_list(choices) ->
              choices
              |> Enum.flat_map(fn
                choice when is_binary(choice) -> String.split(choice, ",")
                _other -> []
              end)
              |> Enum.reject(&(String.trim(&1) == ""))
              |> case do
                [] -> nil
                candidates -> Enum.random(candidates)
              end

            _ ->
              item_data.id
          end

        item_id = dereference(zones, zone, item_id)

        # 物品数据缺失（引用不存在）时跳过，避免悬挂引用。
        # 同样**必须 warn**，理由见 parse_characters 里的注释。
        if is_nil(item_id) do
          warn_unresolved(:item, zone.id, room_id, item_data.id)
          zone
        else
          parse_room_item(zone, room_id, item_id)
        end
      end)
    end)
  end

  @doc """
  记录一个解析不到的 `room_items` / `room_characters` 引用。

  **不在这里打印** —— 一条 `IO.warn` 会连着 10 行 stacktrace，
  而悬空引用实测一次加载就有 805 条（合起来 16000 行日志），
  那样会把真正的告警淹掉。改为只累计，最后由 `report_unresolved/0`
  打一份汇总。

  按 (zone, kind, ref) 去重计数（`room_id` 留首个出现的用于定位）。
  计数放在进程字典里：`Loader.load/1` 本来就是在单个进程里同步跑完的
  （脚本、测试、`Kantele.World.Kickoff` 那个 GenServer 都是），
  所以不需要 ETS —— 早先试过 ETS，`:ets.new` 的具名表失败被 rescue 之后
  `:ets.insert/3` 会报 "undefined or private"，反而把整个加载搞崩。
  """
  def warn_unresolved(kind, zone_id, room_id, ref) do
    # 注意：`:erlang.get/1` 缺键时返回 **`:undefined`**，不是 `nil`。
    # 而 `:undefined` 在 Elixir 里是真值，所以 `x || %{}` 兜不住 ——
    # 早先就因为这个直接 `Map.get(:undefined, ...)` 把整个加载搞崩了。
    seen =
      case :erlang.get(:world_unresolved) do
        m when is_map(m) -> m
        _ -> %{}
      end

    key = {zone_id, kind, ref}

    entry =
      case Map.get(seen, key) do
        {count, _first} -> {count + 1, room_id}
        nil -> {1, room_id}
      end

    :erlang.put(:world_unresolved, Map.put(seen, key, entry))
    :ok
  end

  @doc """
  打印悬空引用汇总。由 `load/1` 在最后调用。
  """
  def report_unresolved do
    seen =
      case :erlang.get(:world_unresolved) do
        m when is_map(m) -> m
        _ -> %{}
      end

    if map_size(seen) == 0 do
      :ok
    else
      total = seen |> Map.values() |> Enum.map(fn {c, _} -> c end) |> Enum.sum()

      by_kind =
        Enum.reduce(seen, %{}, fn {{_z, kind, _r}, {c, _room}}, acc ->
          Map.update(acc, kind, {c, 1}, fn {cc, n} -> {cc + c, n + 1} end)
        end)

      head = [
        "[world] 悬空引用汇总：#{total} 条 / #{map_size(seen)} 个 (zone, kind, ref) 组合，全部已跳过"
      ]

      kinds =
        Enum.map(by_kind, fn {k, {c, n}} ->
          "    #{k} #{c} 条 / #{n} 个"
        end)

      top =
        seen
        |> Enum.sort_by(fn {_, {c, _}} -> -c end)
        |> Enum.take(15)
        |> Enum.map(fn {{z, k, r}, {c, room}} ->
          "    #{String.pad_trailing(to_string(c), 5)} " <>
            "#{String.pad_trailing(z, 14)} #{String.pad_trailing(to_string(k), 10)} " <>
            "#{inspect(r)}  例 #{room}"
        end)

      tail = [
        "  （每条 IO.warn 会带 10 行 stacktrace，所以只打汇总；完整清单见",
        "   docs/dangling-room-items-report.zh-CN.md）",
        "  典型成因：转换器把 LPC set(\"objects\") 写错位置 —— 人物被写进了 items，",
        "  或引用了本区没有定义的 id（characters / items 都只在本区解析）"
      ]

      IO.puts(Enum.join(head ++ kinds ++ top ++ tail, "\n"))
      :ok
    end
  end

  @doc false
  def reset_unresolved_warnings do
    :erlang.erase(:world_unresolved)
    :ok
  end

  defp parse_room_item(zone, room_id, item_id) do
    instance = %Item.Instance{
      id: Item.Instance.generate_id(),
      item_id: item_id,
      created_at: DateTime.utc_now()
    }

    {room_key, room} =
      Enum.find(zone.rooms, fn {_key, room} ->
        room.id == room_id
      end)

    item_instances = Map.get(room, :item_instances, [])
    room = Map.put(room, :item_instances, [instance | item_instances])

    rooms = Map.put(zone.rooms, room_key, room)
    %{zone | rooms: rooms}
  end

  @doc """
  Strip a zone of extra information that Kalevala doesn't care about
  """
  def strip_zone(zone) do
    zone
    |> Map.put(:characters, [])
    |> Map.put(:items, [])
    |> Map.put(:rooms, [])
  end

@doc """
Dereference a variable to it's value

If a known key is found, use the current zone
"""
  def dereference(zones, zone, reference) do
    [key | reference] = String.split(reference, ".")

    case key in ["characters", "rooms", "items"] do
      true ->
        zone
        |> flatten_characters()
        |> flatten_items()
        |> flatten_rooms()
        |> dereference([key | reference])
        |> case do
          nil -> dereference_in_clone(zones, zone, [key | reference])
          found -> found
        end

      false ->
        zone =
          Enum.find(zones, fn z ->
            z.id == key
          end)

        case zone do
          nil ->
            nil

          found_zone ->
            found_zone
            |> flatten_characters()
            |> flatten_items()
            |> flatten_rooms()
            |> dereference(reference)
        end
    end
  end

  # ---- clone_lib 回退：对应 LPC 的 /clone/** 共享对象层 ----

  @clone_zone_id "clone_lib"

  # LPC 的 `clone/` 目录（1003 个 .c）是全服共享对象，每个只有一份。
  # 我们这边就是 `data/world/clone_lib.ucl`。
  #
  # 解析顺序：**本区优先，找不到才回退 clone_lib**。这跟 LPC 的
  # `carry_object("/clone/weapon/blade")` 一致：NPC 自己区里的东西优先，
  # 没有才用共享的那份。
  #
  # clone_lib 现在同时收**物品和 NPC**：
  #   - 物品：`/clone/**` 语义上的全服共享（530 个）
  #   - NPC：**被多个区共用的角色**。LPC 作者图省事直接跨区引私有路径
  #     （`d/baituo/jiudian.c` 写 `"/d/city/npc/xiaoer2"`），实测 53 个 NPC
  #     被 2~11 个区引用、共 215 处。按 LPC 自己的 clone/ 约定它们本就该是共享的，
  #     所以补进 clone_lib 而不是让每个区各抄一份。
  #
  # 为什么只回退到 clone_lib、而不是「随便找个有定义的区」：
  # `jitui` 在 7 个区有 **4 个不同变体**（changan=炸鸡腿 / wudu=烤山鸡腿 /
  # 其余=烤鸡腿），按短 id 猜会静默拿错东西。
  # clone_lib 是**唯一权威的共享层**，它内部不可能有同名两份（一个 UCL 文件里
  # 不会有两个同 key 的块），所以回退到它是确定性的。
  #
  # 剩下**区间引用**（`obj/jitui` 这种区特有物品被别的区引用）不在此列 ——
  # 见 docs/lpc-port-gaps.zh-CN.md §七。
  defp dereference_in_clone(zones, zone, reference) do
    # 本区就是 clone_lib 时不必再回退自己
    if zone.id == @clone_zone_id do
      nil
    else
      case Enum.find(zones, fn z -> z.id == @clone_zone_id end) do
        nil ->
          nil

        clone ->
          # find_item/3 是按 "#{zone.id}:#{name}" 拼 id 的，
          # 所以这里必须传 clone 自己，否则会拼成 "<本区>:<name>" 匹配不上。
          clone
          |> flatten_characters()
          |> flatten_items()
          |> flatten_rooms()
          |> dereference(reference)
      end
    end
  end

  defp flatten_characters(zone) do
    characters = Map.values(zone.characters)
    Map.put(zone, :characters, characters)
  end

  defp flatten_items(zone) do
    items = Map.values(zone.items)
    Map.put(zone, :items, items)
  end

  defp flatten_rooms(zone) do
    rooms = Map.values(zone.rooms)
    Map.put(zone, :rooms, rooms)
  end

  @doc """
  Convert zones into a world struct
  """
  def parse_world(zones) do
    world = %Kantele.World{
      zones: zones
    }

    world
    |> split_out_rooms()
    |> split_out_characters()
    |> split_out_items()
  end

  defp split_out_rooms(world) do
    Enum.reduce(world.zones, world, fn zone, world ->
      rooms =
        Enum.map(zone.rooms, fn room ->
          Map.delete(room, :characters)
        end)

      Map.put(world, :rooms, rooms ++ world.rooms)
    end)
  end

  defp split_out_characters(world) do
    Enum.reduce(world.zones, world, fn zone, world ->
      characters =
        Enum.flat_map(zone.rooms, fn room ->
          Map.get(room, :characters, [])
        end)

      Map.put(world, :characters, characters ++ world.characters)
    end)
  end

  defp split_out_items(world) do
    Enum.reduce(world.zones, world, fn zone, world ->
      Map.put(world, :items, zone.items ++ world.items)
    end)
  end

  def generate_minimap(zone) do
    mini_map = %Kantele.MiniMap{id: zone.id}

    cells =
      Enum.map(zone.rooms, fn room ->
        %Kantele.MiniMap.Cell{
          id: room.id,
          map_color: room.map_color,
          map_icon: room.map_icon,
          name: room.name,
          x: room.x,
          y: room.y,
          z: room.z,
          connections: %Kantele.MiniMap.Connections{
            north: exit_id(room.exits, :north),
            south: exit_id(room.exits, :south),
            east: exit_id(room.exits, :east),
            west: exit_id(room.exits, :west),
            up: exit_id(room.exits, :up),
            down: exit_id(room.exits, :down)
          }
        }
      end)

    mini_map =
      Enum.reduce(cells, mini_map, fn cell, mini_map ->
        cells = Map.put(mini_map.cells, {cell.x, cell.y, cell.z}, cell)
        %{mini_map | cells: cells}
      end)

    %{zone | mini_map: mini_map}
  end

  defp exit_id(exits, direction) do
    room_exit =
      Enum.find(exits, fn room_exit ->
        room_exit.exit_name == to_string(direction)
      end)

    case room_exit != nil do
      true ->
        room_exit.end_room_id

      false ->
        nil
    end
  end

  @doc """
  Dereference a variable for a specific zone
  """
  def dereference(zone, reference) when is_list(reference) do
    case reference do
      ["characters" | character] ->
        [character_name, character_key] = character

        case find_character(zone.characters, zone, character_name) do
          nil -> nil
          char -> Map.get(char, String.to_atom(character_key))
        end

      ["items" | item] ->
        [item_name, item_key] = item

        case find_item(zone.items, zone, item_name) do
          nil -> nil
          found_item -> Map.get(found_item, String.to_atom(item_key))
        end

      ["rooms" | room] ->
        [room_name, room_key] = room

        case find_room(zone.rooms, zone, room_name) do
          nil -> nil
          found_room -> Map.get(found_room, String.to_atom(room_key))
        end
    end
  end

  defp find_character(characters, zone, character_name) do
    Enum.find(characters, fn character ->
      character.id == "#{zone.id}:#{character_name}"
    end)
  end

  defp find_item(items, zone, item_name) do
    Enum.find(items, fn item ->
      item.id == "#{zone.id}:#{item_name}"
    end)
  end

  defp find_room(rooms, zone, room_name) do
    Enum.find(rooms, fn room ->
      room.id == "#{zone.id}:#{room_name}"
    end)
  end
end
