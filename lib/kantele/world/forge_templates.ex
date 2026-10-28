defmodule Kantele.World.ForgeTemplates do
  @moduledoc """
  自定义锻造物品模板的落盘与启动恢复（`docs/forging-subsystem-plan.zh-CN.md` §1.5）。

  `ForgeCustomizeCommand` 在 `finish` 时把生成物模板写进 ETS（`Kantele.World.Items`），
  并落盘 `data/forge/<item_id>.json`；本模块是这两件事的唯一实现。启动时由
  `Kantele.World.Items.initialize/1` 调 `load_all/1` 把模板重新灌回缓存，
  这样玩家重登/重启后背包里的自制装备仍然解析得到定义。

  ## 为什么不能直接 `Jason.encode!(%Kalevala.World.Item{})`

  `Kalevala.World.Item` 的 `Jason.Encoder` 走的是 `Kalevala.Meta.Trim`，而
  `Kantele.World.Item.Meta` 的 trim 只保留 `:damage` / `:armor`
  （`lib/kantele/world/item.ex` L406）—— 那是给**事件传输**裁剪用的，不是持久化。

  直接拿它落盘会丢掉 `item_make` / `owner_id` / `owner` / `skill_type` / `unit` /
  `weight` / `value` / `material` / `material_name` / `messages`，后果是重启后：

    * `discard` 退款失效（要求 `item_make == true and owner_id == 玩家`）；
    * 自定义 wield/unwield 文案消失，退回默认文案；
    * 伤害/护甲之外的属性全丢。

  所以这里用**显式字段编码 + `version`**，不依赖 struct 的 `Jason.Encoder`。

  ## 不序列化 `verbs`

  锻造模板由 `handle_finish/3` 生成，固定 `verbs: []`（LPC 侧也没有给自制装备挂动词）。
  恢复时同样写 `verbs: []`。
  """

  require Logger

  alias Kalevala.World.Item, as: ItemDef
  alias Kantele.World.Item, as: ItemCallbacks
  alias Kantele.World.Item.Meta
  alias Kantele.World.Items

  @version 1
  @default_dir "data/forge"

  @doc """
  落盘目录。默认 `data/forge`，测试可用 `config :ex_venture, :forge_dir, ...` 覆盖，
  避免把测试产物写进仓库。
  """
  def dir, do: Application.get_env(:ex_venture, :forge_dir, @default_dir)

  @doc """
  把模板编码成可落盘的 map（JSON 安全）。

  保留 `meta` 的**全部**字段（`Map.from_struct/1`），而不是 trim 后的子集。
  """
  def encode(%ItemDef{} = item) do
    %{
      "version" => @version,
      "id" => item.id,
      "name" => item.name,
      "description" => item.description,
      "meta" => encode_meta(item.meta)
    }
  end

  defp encode_meta(%Meta{} = meta), do: Map.from_struct(meta)
  defp encode_meta(meta) when is_map(meta), do: Map.new(meta)
  defp encode_meta(nil), do: %{}

  @doc """
  把落盘 map 还原成 `%Kalevala.World.Item{}` 模板。

  未知键（未来版本新增的 meta 字段）会被忽略；`meta.messages` 的键还原成 atom，
  因为消费端 `wield_command.ex` 用 `Map.get(messages, :wield)` 取值。
  """
  def decode(%{"id" => id} = map) when is_binary(id) do
    {:ok,
     %ItemDef{
       id: id,
       name: map["name"],
       description: map["description"],
       callback_module: ItemCallbacks,
       verbs: [],
       meta: decode_meta(map["meta"] || %{})
     }}
  end

  def decode(other), do: {:error, {:invalid_template, other}}

  defp decode_meta(meta) when is_map(meta) do
    known = Meta.__struct__() |> Map.from_struct() |> Map.keys()

    attrs =
      Enum.reduce(meta, %{}, fn {key, value}, acc ->
        case existing_atom(key) do
          nil ->
            acc

          atom ->
            if atom in known do
              Map.put(acc, atom, normalize(atom, value))
            else
              acc
            end
        end
      end)

    struct(Meta, attrs)
  end

  defp decode_meta(_), do: %Meta{}

  defp normalize(:messages, value) when is_map(value), do: atomize_keys(value)
  defp normalize(_key, value), do: value

  defp atomize_keys(map) do
    Map.new(map, fn {key, value} -> {existing_atom(key) || key, value} end)
  end

  defp existing_atom(key) when is_atom(key), do: key

  defp existing_atom(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end

  defp existing_atom(_), do: nil

  @doc """
  落盘文件名。

  `item_id` 形如 `forge:<owner_id>-<sid>`，其中的 `:` 在 Windows 上是**非法文件名字符**：
  Docker Desktop 的绑定挂载会把它写成私用区字符 `U+F03A`，仓库里就因此出现过
  `data/forge/forge\\uF03Aplayer-....json` 这种文件。这里统一换成 `-`，宿主机上就是
  正常文件名。

  文件名只用于定位，`id` 仍从 JSON **内容**里读（`decode/1`），所以改名不影响恢复。
  """
  def file_name(item_id), do: String.replace(item_id, ":", "-") <> ".json"

  @doc """
  落盘一个模板到 `<dir>/<file_name(item.id)>`。

  返回 `{:ok, path}` / `{:error, reason}`；写盘失败不应让 `finish` 崩掉玩家连接，
  调用方按需忽略。
  """
  def save(%ItemDef{} = item, dir \\ dir()) do
    path = Path.join(dir, file_name(item.id))

    with :ok <- File.mkdir_p(dir),
         {:ok, body} <- Jason.encode(encode(item)),
         :ok <- File.write(path, body) do
      {:ok, path}
    else
      {:error, reason} = error ->
        Logger.warning("forge template save failed: #{path} #{inspect(reason)}")
        error
    end
  end

  @doc """
  读取 `dir` 下所有 `*.json` 模板并注册进 `Kantele.World.Items`。

  单个文件坏掉只跳过并记 warning，不影响其余模板，也不影响启动。
  返回成功加载的条数。
  """
  def load_all(dir \\ dir()) do
    case File.ls(dir) do
      {:ok, names} ->
        names
        |> Enum.filter(&String.ends_with?(&1, ".json"))
        |> Enum.reduce(0, fn name, acc ->
          case load_file(Path.join(dir, name)) do
            {:ok, _item} -> acc + 1
            :error -> acc
          end
        end)

      {:error, _reason} ->
        0
    end
  end

  defp load_file(path) do
    with {:ok, body} <- File.read(path),
         {:ok, map} <- Jason.decode(body),
         {:ok, item} <- decode(map) do
      Items.put(item.id, item)
      {:ok, item}
    else
      error ->
        Logger.warning("forge template load failed: #{path} #{inspect(error)}")
        :error
    end
  end
end
