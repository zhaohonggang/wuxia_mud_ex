defmodule Kantele.World.NpcActionHandlers do
  @moduledoc """
  NPC `add_action` handler 注册表(P5-1c)。

  LPC NPC 通过 `add_action("verb", "do_*")` 注册自定义动词，handler 是 LPC
  函数名。回填(P5-1a)已把 NPC 的 `init.add_actions` 写入 UCL。本模块负责
  把 **handler 名** 解析为可执行的 Elixir `{module, function}`，由 P5-1c-2
  的对象级分发路由调用。

  ## 注册策略

  registry 是**房间级**：`room_id => %{verb => {module, function}}`。
  `room_id` 为 UCL 房间 id（`zone:key`，重启不变），**不使用**
  `Character.generate_id()`（重启后会变动）。按房间区分，避免不同房间
  同名 NPC 的动词互相干扰。

  ## 注册示例

      @registry %{
        "tulong:huichang_back" => %{
          "yun" => {Kantele.World.NpcActions.Yun, :run}
        }
      }

  ## 安全性(P7)

  未注册的房间/verb 经 `lookup/2` 返回 `{:unimplemented, verb}`，分发路由
  据此给出 `:not_handled` 放行全局命令，**对全局命令零行为影响**。
  仅当某房间某 NPC verb 的 handler 被真正移植并注册后，该动作才被
  拦截激活。

  ## 已注册(P5-1c-3 首个样板 `yun`)

  `yun` 是纯输出动作（`arg == "roar"` 广播一条 vision 文案，否则 `return 0`
  放行），零状态变更，四个 NPC 注册了它：
    - 殷素素：tulong:huichang_back、tulong:huichang
    - 赵一伤：tulong:jiulou、tulong:was_dayuan
  """
  # 房间级注册表：room_id -> (verb -> {module, function})。
  @registry %{
    "tulong:huichang_back" => %{
      "yun" => {Kantele.World.NpcActions.Yun, :run}
    },
    "tulong:huichang" => %{
      "yun" => {Kantele.World.NpcActions.Yun, :run}
    },
    "tulong:jiulou" => %{
      "yun" => {Kantele.World.NpcActions.Yun, :run}
    },
    "tulong:was_dayuan" => %{
      "yun" => {Kantele.World.NpcActions.Yun, :run}
    }
  }

  @doc """
  解析 (room_id, verb) 到 Elixir `{module, function}`。

  返回 `{:ok, {module, function}}` 或 `{:unimplemented, verb}`。
  房间未注册 / verb 未在该房间移植 → 均视为未实现（安全降级）。
  """
  def lookup(room_id, verb) when is_binary(room_id) and is_binary(verb) do
    case Map.get(@registry, room_id) do
      nil ->
        {:unimplemented, verb}

      room_map ->
        case Map.get(room_map, verb) do
          nil -> {:unimplemented, verb}
          {module, function} -> {:ok, {module, function}}
        end
    end
  end

  def lookup(_room_id, _verb), do: {:unimplemented, :unknown}

  @doc "该房间的 verb 是否已有 Elixir 实现（已注册）。"
  def registered?(room_id, verb), do: match?({:ok, _}, lookup(room_id, verb))

  @doc "当前已注册的房间 id 列表，用于覆盖度统计。"
  def registered_rooms(), do: Map.keys(@registry)
end
