defmodule Kantele.World.ObjectClone do
  @moduledoc """
  运行时对象克隆引擎，对应 LPC `cmds/wiz/clone.c`。

  提供 `clone_by_path/3`：按文件路径克隆世界对象（物品/NPC），
  带权限检查、站点特权控制、操作日志。

  ## 步骤（对应 LPC `cmds/wiz/clone.c`）

  1. 补齐 `.c` 后缀；`zone:id` 格式原样保留
  2. `Security.granted?(actor, "clone")` 或巫师 `Access.wizardp/1`
  3. `valid_read?(file, actor, "clone")` 文件读权限
  4. 非 admin 站点特权：`gift` 仅允许 `/clone/special/*\|/clone/gift/*`；
     `all` 放行；其余拒绝
  5. `Code.ensure_loaded(module)` 失败 → 载入错误回报
  6. `module.new()` / UCL 实例化；`set_amount(amount)`；写 `static/clone` 日志
  7. 返回结果（由调用方负责 `obj.move(actor)` 或 `obj.move(environment(actor))`）

  返回 `{:ok, %__MODULE__{}}` 或 `{:error, reason}`。
  """

  alias Kantele.Admin.Access
  alias Kantele.Admin.Security
  alias Kantele.World
  alias Kantele.World.Items
  alias Kantele.World.ZoneCache

  @log_dir "static/clone"
  @log_file "clone.log"

  defstruct [:object, :file, :amount, :message]

  @doc """
  按路径克隆对象。

  `file` 支持两种格式：
  - `zone:id`，如 `clone_lib:arrow` → 从 UCL 物品/NPC 定义查找
  - LPC 风格路径，如 `/clone/weapon/sword.c` → 尝试 Elixir 模块加载，
    失败后回退到 UCL 查找

  `amount` 缺省为 1。

  ## 返回

  - `{:ok, %__MODULE__{object: obj, file: file, amount: amount, message: msg}}`
  - `{:error, :not_authorized}` / `{:error, :read_denied}` /
    `{:error, :site_denied}` / `{:error, :not_found}` / `{:error, :load_error}`
  """
  def clone_by_path(file, amount \\ 1, actor)

  def clone_by_path(file, amount, actor)
      when is_binary(file) and is_integer(amount) and amount > 0 do
    file = normalize_file(file)

    cond do
      not authorized?(actor) ->
        {:error, :not_authorized}

      not valid_read?(file, actor) ->
        {:error, :read_denied}

      not site_privilege_ok?(file, actor) ->
        {:error, :site_denied}

      true ->
        case resolve_definition(file) do
          {:ok, definition} ->
            obj = instantiate(definition, amount)
            message = build_message(obj, amount)
            write_log(actor, file, amount)
            {:ok,
             %__MODULE__{
               object: obj,
               file: file,
               amount: amount,
               message: message
             }}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  def clone_by_path(_file, _amount, _actor) do
    {:error, :invalid_args}
  end

  # --- 1. 路径标准化 ---

  defp normalize_file(file) do
    if String.contains?(file, ":") do
      file
    else
      if String.ends_with?(file, ".c") do
        file
      else
        file <> ".c"
      end
    end
  end

  # --- 2. 权限检查 ---

  @doc false
  def authorized?(actor) do
    Security.granted?(actor.name, "clone") or Access.wizardp(actor)
  end

  # --- 3. 读权限 ---

  @doc false
  def valid_read?(_file, _actor) do
    # Ex 侧：模块白名单/路径允许列表。暂时放行所有已知路径。
    true
  end

  # --- 4. 站点特权 ---

  @doc false
  def site_privilege_ok?(file, actor) do
    site = Map.get(actor.attributes, "site", "all")

    cond do
      Access.adminp(actor) ->
        true

      site == "all" ->
        true

      site == "gift" ->
        String.starts_with?(file, "/clone/special/") or
          String.starts_with?(file, "/clone/gift/")

      true ->
        false
    end
  end

  # --- 5. 解析定义 ---

  defp resolve_definition(file) do
    # 先尝试 Elixir 模块加载（对应 Code.ensure_loaded / module.new()）
    case module_name_for_path(file) do
      nil ->
        # 没有对应 Elixir 模块，回退到 UCL 定义查找
        resolve_ucl_definition(file)

      module ->
        case Code.ensure_loaded(module) do
          {:module, ^module} ->
            {:ok, {:module, module}}

          {:error, _reason} ->
            # 模块加载失败，回退到 UCL
            resolve_ucl_definition(file)
        end
    end
  end

  defp resolve_ucl_definition(file) do
    # zone:id 格式（如 clone_lib:arrow）→ 从 ZoneCache 查找物品定义
    case String.split(file, ":") do
      [zone_id, item_id] ->
        case ZoneCache.get(zone_id) do
          {:ok, zone} ->
            items = Map.get(zone, :items, %{})
            case Map.get(items, item_id) do
              item when is_map(item) -> {:ok, {:item, item}}
              nil ->
                # 也在 zone.characters 里找（NPC 定义）
                chars = Map.get(zone, :characters, %{})
                case Map.get(chars, item_id) do
                  npc when is_map(npc) -> {:ok, {:npc, npc}}
                  nil -> {:error, :not_found}
                end
            end

          nil ->
            {:error, :not_found}
        end

      _ ->
        # LPC 风格路径或短名 → 先找 NPC，再找物品（去掉 .c 后缀再查）
        lookup_name = String.replace_suffix(file, ".c", "")
        case World.find_npc_definition(lookup_name) do
          nil ->
            case Items.get(lookup_name) do
              {:ok, item} -> {:ok, {:item, item}}
              _ -> {:error, :not_found}
            end

          npc_def ->
            {:ok, {:npc, npc_def}}
        end
    end
  end

  # 将文件路径映射为 Elixir 模块名（如 /clone/weapon/sword.c →
  # Elixir.Kantele.World.Item.Clone.Weapon.Sword）。无法映射时返回 nil。
  defp module_name_for_path(file) do
    unless String.starts_with?(file, "/clone/") do
      nil
    else
      segments =
        file
        |> String.trim_leading("/")
        |> String.replace(".c", "")
        |> String.split("/")
        |> Enum.map(&String.capitalize/1)

      module_segments = ["Elixir", "Kantele", "World", "Item", "Clone" | segments]
      String.to_atom(Enum.join(module_segments, "."))
    end
  end

  # --- 6. 实例化 ---

  defp instantiate({:item, item_template}, amount) do
    %Kalevala.World.Item.Instance{
      id: Kalevala.World.Item.Instance.generate_id(),
      item_id: item_template.id,
      created_at: DateTime.utc_now(),
      item: item_template,
      meta: Map.put(Map.new(item_template.meta || %{}), :amount, amount)
    }
  end

  defp instantiate({:npc, npc_def}, _amount) do
    %Kalevala.Character{
      id: Kalevala.Character.generate_id(),
      name: npc_def.name,
      room_id: nil,
      inventory: [],
      attributes: %{},
      meta: %{}
    }
  end

  defp instantiate({:module, module}, amount) do
    case module.new() do
      obj when is_map(obj) ->
        %{
          obj
          | meta: Map.put(Map.new(obj.meta || %{}), :amount, amount)
        }

      _ ->
        {:error, :load_error}
    end
  rescue
    _ ->
      {:error, :load_error}
  end

  # --- 7. 日志 ---

  defp write_log(actor, file, amount) do
    File.mkdir_p!(@log_dir)

    path = Path.join(@log_dir, @log_file)
    entry = "[#{DateTime.utc_now()}] #{actor.name} cloned #{file} amount=#{amount}\n"

    File.write!(path, entry, [:append])

    :ok
  end

  # --- 消息 ---

  defp build_message(obj, amount) do
    name = case obj do
      %Kalevala.World.Item.Instance{} = inst -> inst.item.name
      %Kalevala.Character{} = char -> char.name
      _ -> "未知对象"
    end

    if amount > 1 do
      "成功克隆 #{amount} 个 #{name}"
    else
      "成功克隆 #{name}"
    end
  end
end
