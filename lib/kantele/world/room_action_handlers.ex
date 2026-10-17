defmodule Kantele.World.RoomActionHandlers do
  @moduledoc """
  房间 `add_action` handler 注册表（P5-1b）。

  LPC 房间通过 `add_action("verb", "handler")` 注册自定义动词，handler 是 LPC
  函数名（如 `do_move`、`do_climb`）。回填（P5-1a2）已把 304 个房间的
  `verb → handler` 写入 UCL `Room.actions`。本模块负责把 **handler 名** 解析为
  可执行的 Elixir `{module, function}`，由 P5-1b-2 的对象级分发路由调用。

  ## 移植策略（P5-1b-3 重大修正）
  LPC 同名 handler（`do_move`/`do_climb`/...）在**每个房间 `.c` 是各自独立的函数体**，
  绝非共享（例：`d/baituo/neishi.c` 的 `do_move` 开密道、`d/death/lunhuisi.c` 的
  `do_move` 推石桌，互不相干）。因此注册表必须是**房间级**：`lookup(room_id, handler_name)`
  按 `room_id` 区分同名 handler。每个房间移植其独有 `do_*` 为一个
  `use Kantele.World.RoomAction` 的模块，注册到下方 `@registry` 的对应房间桶。

  ## 注册示例
      @registry %{
        "baituo:neishi" => %{
          "do_move" => {Kantele.World.RoomActions.Baituo.Neishi.Move, :run}
        }
      }

  ## 安全性（P7）
  未注册的房间/handler 经 `lookup/2` 返回 `{:unimplemented, name}`，分发路由据此
  给出 `:not_handled` 放行全局命令，**对全局命令零行为影响**。仅当某房间某 verb 的
  handler 被真正移植并注册后，该房间的该动作才被拦截激活。
  """
  # 房间级注册表：room_id -> (handler_name -> {module, function})。
  # 已注册的动词均**不在全局命令表**、激活后不影响任何全局命令：
  #   - huashan:lianhua do_tiao：纯 write 文本（专用模块 Tiao）
  #   - emei:shierpan3 do_clap：message_vision 房间广播（专用模块 Clap）
  #   - hangzhou:liuzhuang do_knock / huanggong:inwell do_reach：纯消息/分支
  #     （数据驱动 MessageOnly，见 room_actions/message_only.ex）
  #   - baituo:neishi do_move：状态变更（开/关 down 密道）专用模块 Move
  @registry %{
    "huashan:lianhua" => %{
      "do_tiao" => {Kantele.World.RoomActions.Huashan.Lianhua.Tiao, :run}
    },
    "emei:shierpan3" => %{
      "do_clap" => {Kantele.World.RoomActions.Emei.Shierpan3.Clap, :run}
    },
    # 纯消息 / 简单分支：走数据驱动的 MessageOnly（见 room_actions/message_only.ex）
    "hangzhou:liuzhuang" => %{
      "do_knock" => {Kantele.World.RoomActions.MessageOnly, :run}
    },
    "huanggong:inwell" => %{
      "do_reach" => {Kantele.World.RoomActions.MessageOnly, :run}
    },
    # 状态变更样板：开/关密道（set/delete("exits/down") + 查 born_family + 广播）
    "baituo:neishi" => %{
      "do_move" => {Kantele.World.RoomActions.Baituo.Neishi.Move, :run}
    },
    # 房间动作覆盖全局命令的样板（完整移植，非残缺）：禁止吃喝/给/扔/自杀
    "chengdu:guangchang" => %{
      "do_drink" => {Kantele.World.RoomActions.MessageOnly, :run},
      "do_eat" => {Kantele.World.RoomActions.MessageOnly, :run}
    },
    "register:prison" => %{
      "do_eat" => {Kantele.World.RoomActions.MessageOnly, :run},
      "do_drink" => {Kantele.World.RoomActions.MessageOnly, :run},
      "do_suicide" => {Kantele.World.RoomActions.MessageOnly, :run},
      "do_give" => {Kantele.World.RoomActions.MessageOnly, :run},
      "do_drop" => {Kantele.World.RoomActions.MessageOnly, :run}
    },
    # 位移样板（me->move(__DIR__"x") → Helpers.move_to/2 → Teleport.teleport/2）
    "lingxiao:juegu" => %{
      "do_pan" => {Kantele.World.RoomActions.Lingxiao.Juegu.Pan, :run}
    },
    "hengyang:furong1" => %{
      "do_climb" => {Kantele.World.RoomActions.Hengyang.Furong1.Climb, :run}
    },
    "changan:kzsleep" => %{
      "do_bed" => {Kantele.World.RoomActions.Changan.Kzsleep.Bed, :run}
    },
    "xiakedao:xiaowu" => %{
      "do_move" => {Kantele.World.RoomActions.Xiakedao.Xiaowu.Move, :run}
    },
    # 批量机制 #2：数据驱动「文案 + 位移 + 文案」（VisionMove 表）
    "mingjiao:gudi3" => %{
      "do_enter" => {Kantele.World.RoomActions.VisionMove, :run}
    },
    "gumu:taiyi1" => %{
      "do_jump" => {Kantele.World.RoomActions.VisionMove, :run}
    },
    "gumu:taiyi2" => %{
      "do_climb" => {Kantele.World.RoomActions.VisionMove, :run}
    },
    "emei:hcawest" => %{
      "do_jump" => {Kantele.World.RoomActions.VisionMove, :run}
    },
    "emei:xiaoshulin1" => %{
      "do_jump" => {Kantele.World.RoomActions.VisionMove, :run}
    }
  }

  @doc """
  解析 (room_id, handler_name) 到 Elixir `{module, function}`。

  返回 `{:ok, {module, function}}` 或 `{:unimplemented, handler_name}`。
  房间不存在 / handler 未在该房间移植 → 均视为未实现（安全降级）。
  """
  def lookup(room_id, handler_name) when is_binary(room_id) and is_binary(handler_name) do
    case Map.get(@registry, room_id) do
      nil ->
        {:unimplemented, handler_name}

      room_map ->
        case Map.get(room_map, handler_name) do
          nil -> {:unimplemented, handler_name}
          {module, function} -> {:ok, {module, function}}
        end
    end
  end

  def lookup(_room_id, handler_name), do: {:unimplemented, handler_name}

  @doc "该房间的 handler 是否已有 Elixir 实现（已注册）。"
  def registered?(room_id, handler_name), do: match?({:ok, _}, lookup(room_id, handler_name))

  @doc "当前已注册的房间 id 列表，用于覆盖度统计。"
  def registered_rooms(), do: Map.keys(@registry)
end
