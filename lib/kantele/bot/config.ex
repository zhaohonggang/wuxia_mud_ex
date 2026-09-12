defmodule Kantele.BotConfig do
  @moduledoc """
  机器人配置：解析 `data/bots/*.ucl`

  每个文件须含 `bots { <name> { ... } }` 表，字段都是可选（有默认值）：

  - `enabled`(bool, 默认 true)      是否随世界启动
  - `account` / `password` / `name`  登录三要素（name 是角色名，唯一）
  - `who`(bool, 默认 true)           是否在 `who` 列表可见
  - `tick_ms`(int, 默认 800)         每拍动作间隔
  - `march`([出口名], 默认 [])       巡逻路线（缺省则随机出口游荡）
  - `hunt`([NPC 名], 默认 [])        本房间命中即开打的目标名单
  - `hunt_rooms`([房间引用], 默认 []) 允许打猎的房间（空 = 任意非禁斗房间）
  - `heal_qi`(0..1, 默认 0.5)        战斗中气血低于此比例 -> halt
  - `flee_qi`(0..1, 默认 0.35)       战斗中气血低于此比例 -> 逃跑
  - `train`([命令串], 默认 [])       打坐/拜师/练习指令（条件满足时逐个执行）
  - `train_jing`(0..1, 默认 0.5)     精力比例高于此值才执行 train
  - `train_potential`(int, 默认 10)  可用潜能高于此值才执行 train
  - `save_every`(int, 默认 60)       每 N 拍主动 save 存档
  - `relog`(bool, 默认 true)         foreman 意外退出是否自动重登
  """

  @bots_path "data/bots"

  defstruct [
    :key,
    :account,
    :password,
    :name,
    enabled: true,
    who: true,
    tick_ms: 800,
    march: [],
    hunt: [],
    hunt_rooms: [],
    train: [],
    heal_qi: 0.5,
    flee_qi: 0.35,
    train_jing: 0.5,
    train_potential: 10,
    save_every: 60,
    relog: true
  ]

  @type t() :: %__MODULE__{}

  @doc """
  读取 `data/bots` 下全部 .ucl，解析为 `{:ok, key => %Config{}}` 或 `{:error, reason}`
  """
  def load_all(path \\ @bots_path) do
    try do
      configs =
        path
        |> File.ls!()
        |> Enum.filter(&String.ends_with?(&1, ".ucl"))
        |> Enum.flat_map(fn file ->
          full = Path.join([path, file])
          content = File.read!(full)
          case Elias.parse(content) do
            %{bots: bots} when is_map(bots) ->
              Enum.map(bots, fn {key, data} -> {to_string(key), from_parsed(to_string(key), data)} end)

            _ ->
              []
          end
        end)
        |> Enum.into(%{})

      {:ok, configs}
    catch
      :error, reason -> {:error, reason}
    end
  end

  @doc """
  转型单个 bot 定义（Elias 值 -> Config 结构）
  """
  def from_parsed(key, data) do
    %__MODULE__{
      key: key,
      account: String.trim(value(data, :account, key)),
      password: String.trim(value(data, :password, "")),
      name: String.trim(value(data, :name, key)),
      enabled: bool(value(data, :enabled, true)),
      who: bool(value(data, :who, true)),
      tick_ms: int(value(data, :tick_ms, 800)),
      march: strings(value(data, :march, [])),
      hunt: strings(value(data, :hunt, [])),
      hunt_rooms: strings(value(data, :hunt_rooms, [])),
      train: strings(value(data, :train, [])),
      heal_qi: float(value(data, :heal_qi, 0.5)),
      flee_qi: float(value(data, :flee_qi, 0.35)),
      train_jing: float(value(data, :train_jing, 0.5)),
      train_potential: int(value(data, :train_potential, 10)),
      save_every: int(value(data, :save_every, 60)),
      relog: bool(value(data, :relog, true))
    }
  end

  defp value(data, key, default) do
    Map.get(data, key, default)
  end

  # Elias 把裸 false 解析成字符串 "false"，统一按布尔归一
  defp bool(v) when is_boolean(v), do: v
  defp bool(v) when is_binary(v), do: v in ["true", "1"]
  defp bool(_), do: false

  defp int(v) when is_integer(v), do: v

  defp int(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, ""} -> n
      _ -> 0
    end
  end

  defp int(_), do: 0

  defp float(v) when is_number(v), do: v / 1

  defp float(v) when is_binary(v) do
    case Float.parse(v) do
      {n, ""} -> n
      _ -> 0.0
    end
  end

  defp float(_), do: 0.0

  defp strings(list) when is_list(list), do: Enum.map(list, &to_string/1)
  defp strings(_), do: []
end