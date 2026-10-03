defmodule Kantele.World.ExitVetoContext do
  @moduledoc """
  为 `Kantele.World.LpcCondition` 构造求值上下文

  阻挡条件里的 LPC 内建（`present` / `environment` / `objectp` / `living` /
  `userp` / `wizardp` / `id`）与方法调用（`->query` / `->query_temp` /
  `->query_skill` / `->query_condition`）在这里落到真实游戏状态上。

  语义对齐 MudOS：
    - `present(id, environment(me))` 房里按 id 找活物/物品
    - `present(id, me)`              身上（inventory）按 id 找
    - `me->query("a/b")`             LPC set() 属性仓库（`meta.env`），
                                      路径式读取走 `Kantele.Util.TreeMap`
    - `me->query_temp("k")`          `meta.temp`（会话态，`rent_paid` 等）
    - `me->query_skill("k")`         技能等级
    - `me->query_condition("k")`     状态（中毒/媚药等）

  任何查不到的东西一律返回 nil（条件为假），与 LPC 里「找不到即 0」一致。
  """

  alias Kantele.Util.TreeMap

  @doc "按 `%{dir:, me:, room:, context:}` 构造 ctx"
  def build(opts) do
    room = Keyword.get(opts, :room)

    %{
      dir: Keyword.get(opts, :dir),
      me: Keyword.get(opts, :me),
      room: room,
      vars: %{},
      resolver: resolver(Keyword.get(opts, :context), room)
    }
  end

  defp resolver(context, room) do
    %{
      present: fn id, scope -> present(context, room, id, scope) end,
      # environment(me) = 玩家当前所在房，也就是正在离开的这间（veto 所在房）
      environment: fn _target -> {:ok, room} end,
      living: fn target -> living?(target) end,
      wizardp: fn target -> wizard?(target) end,
      userp: fn target -> userp?(target) end,
      id: fn target -> target_id(target) end,
      call: fn target, method, args -> call(target, method, args) end
    }
  end

  # ---- present(id, scope) ----

  defp present(context, room, id, scope) when is_binary(id) do
    cond do
      scope_is_room?(scope) -> find_in_room(context, room, id)
      true -> find_in_inventory(context, id)
    end
  end

  defp present(_context, _room, _id, _scope), do: :error

  # LPC 的 environment(me) 传进来的是房间 struct（resolver 里固定回当前房）
  defp scope_is_room?(%{__struct__: _} = scope), do: match?(%{exits: _}, scope)
  defp scope_is_room?(_), do: false

defp find_in_room(context, room, id) do
    # 优先用上下文的角色表（运行时就是该房间在场的人），退回房间自身的 characters
    characters =
      case Map.get(context, :characters) do
        list when is_list(list) -> list
        _ -> Map.get(room || %{}, :characters) || []
      end

    case Enum.find(characters, fn c -> name_matches?(c, id) end) do
      nil ->
        # LPC 的 present(id, room) 搜的是房里的一切，**含物品**。
        # 例：shaolin:dmyuan2 的 `present("xisui jing", this_object())`
        # 指的是房里那本 心法书（items.xisuijing），房里没人 —— 只搜角色会恒 nil，
        # 条件 `! present(...)` 就恒真，会把人锁死在房中。
        instances =
          case Map.get(context, :item_instances) do
            # 注意：`[] || fallback` 在 Elixir 里是 []（空列表为真值），必须显式判空
            list when is_list(list) and list != [] -> list
            _ -> Map.get(room || %{}, :item_instances) || []
          end

        case Enum.find(instances, fn i -> instance_matches?(i, id) end) do
          nil -> :error
          instance -> {:ok, instance}
        end

      character ->
        {:ok, character}
    end
  end

  defp find_in_inventory(context, id) do
    case Map.get(context, :character) do
      nil ->
        :error

      character ->
        items = Map.get(character, :inventory, []) || []

        case Enum.find(items, fn i -> instance_matches?(i, id) end) do
          nil -> :error
          instance -> {:ok, instance}
        end
    end
  end

  # LPC 的 present(id, ...) 按 `set_name` 的 id 表匹配，不是按中文名。
  # 名字与 aliases（迁移时从源 .c 回填的拼音 id）都算命中。
  defp name_matches?(character, id) do
    keyword = normalize_id(id)
    name = character |> Map.get(:name, "") |> to_string() |> normalize_id()
    aliases = character |> Map.get(:meta, %{}) |> aliases_of() |> Enum.map(&normalize_id/1)

    name == keyword or String.starts_with?(name, keyword <> " ") or
      Enum.any?(aliases, &(&1 == keyword))
  end

  defp normalize_id(s), do: s |> to_string() |> String.downcase() |> String.trim()

  defp aliases_of(meta) when is_map(meta) do
    case Map.get(meta, :aliases) do
      list when is_list(list) -> list
      _ -> []
    end
  end

  defp aliases_of(_), do: []

  defp instance_matches?(instance, id) do
    keyword = normalize_id(id)

    short =
      case Map.get(instance, :item_id) do
        nil -> nil
        item_id -> item_id |> String.split(":") |> List.last()
      end

    cond do
      is_nil(short) ->
        false

      normalize_id(short) == keyword ->
        true

      true ->
        # 物品也可能有 set_name 别名（如 xisuijing 的 LPC id 是 xisui jing）。
        # 从 ZoneCache 的世界数据取，而不是 Kantele.World.Items —— 后者依赖运行中的
        # 物件注册表，测试环境下并不存在。
        Enum.any?(item_aliases(Map.get(instance, :item_id)), &(normalize_id(&1) == keyword))
    end
  end

  defp item_aliases(item_id) when is_binary(item_id) do
    case String.split(item_id, ":") do
      [zone_id | _] ->
        case Kantele.World.ZoneCache.get(zone_id) do
          {:ok, zone} ->
            (Map.get(zone, :items) || [])
            |> Enum.find(&(&1.id == item_id))
            |> case do
              nil -> []
              item -> Map.get(item.meta, :aliases) || []
            end

          _ ->
            []
        end

      _ ->
        []
    end
  end

  defp item_aliases(_), do: []

  # ---- 对象判定 ----

  # 只有 NPC（房间里除自己以外的活物）算 living
  defp living?(%{pid: pid}) when is_pid(pid), do: true
  defp living?(_), do: false

  defp wizard?(target), do: is_map(target) and Map.get(target, :option, nil) == "wizard"

  defp userp?(%{pid: pid}) when is_pid(pid), do: true
  defp userp?(_), do: false

  defp target_id(%{id: id}) when is_binary(id), do: id
  defp target_id(_), do: nil

  # ---- 方法调用 ----

  # LPC 的 query 走 set() 属性仓库（meta.env），路径式读取用 TreeMap
  defp call(target, "query", [key]) when is_binary(key) do
    {:ok, query_prop(target, key)}
  end

  defp call(target, "query", _args), do: :error

  defp call(target, "query_temp", [key]) when is_binary(key) do
    {:ok, Map.get(temp_of(target), key)}
  end

  defp call(target, "query_temp", _args), do: :error

  defp call(target, "query_skill", [key]) when is_binary(key) do
    {:ok, skill_level(target, key)}
  end

  defp call(target, "query_skill", _args), do: :error

  defp call(target, "query_condition", [key]) when is_binary(key) do
    {:ok, Kantele.Character.Conditions.query_condition(meta_of(target), key)}
  end

  defp call(target, "query_condition", _args), do: :error

  # 其余方法（如 ob->refuse(me)、ob->query("weapon_prop")）本项目未实现，
  # 返回 nil 而不是报错：条件为假即放行。
  defp call(_target, _method, _args), do: :error

  defp meta_of(%{meta: meta}), do: meta
  defp meta_of(_), do: %{}

  # 会话态：LPC get_temp/put_temp 的落点（PlayerMeta.temp / NonPlayerMeta.temp）
  defp temp_of(target) do
    case meta_of(target) do
      %{temp: temp} when is_map(temp) -> temp
      _ -> %{}
    end
  end

  defp query_prop(target, key) do
    meta = meta_of(target)
    env = Map.get(meta, :env, %{}) || %{}

    case TreeMap.query(env, path_parts(key)) do
      nil -> fallback_prop(target, key)
      value -> value
    end
  end

  # LPC set() 里没存过的键，回落到结构体常见字段
  defp fallback_prop(target, key) do
    meta = meta_of(target)

    case key do
      "gender" -> Map.get(meta, :option) && Map.get(meta, :family, %{}).family_name
      "born_family" -> family_name(Map.get(meta, :born_family))
      "family/family_name" -> family_name(Map.get(meta, :family))
      "combat_exp" -> exp_of(target)
      _ -> nil
    end
  end

  defp family_name(nil), do: nil

  defp family_name(%{family_name: name}), do: name
  defp family_name(name) when is_binary(name), do: name
  defp family_name(_), do: nil

  defp exp_of(%{meta: %{stats: %{combat_exp: exp}}}), do: exp
  defp exp_of(_), do: nil

  def debug_skill(target, key), do: skill_level(target, key)

  defp skill_level(target, key) do
    meta = meta_of(target)

    # 不能用 get_in/2：它走 Access 协议，而 meta 是**结构体**
    # （%PlayerMeta{} / %NonPlayerMeta{}），没有实现 Access，会抛
    # "Kalevala.Meta.Trimmed.fetch/2 is undefined" —— 线上表现为条件恒假、
    # 阻挡被静默跳过。Map.get 对结构体是安全的。
    skills =
      meta
      |> Map.get(:stats)
      |> case do
        nil -> nil
        stats -> Map.get(stats, :skills)
      end

    case skills do
      skills when is_map(skills) ->
        case Map.get(skills, key) do
          %{level: level} -> level
          level when is_integer(level) -> level
          _ -> 0
        end

      _ ->
        0
    end
  end

  defp path_parts(key), do: key |> String.split("/") |> Enum.map(&String.to_atom/1)
end