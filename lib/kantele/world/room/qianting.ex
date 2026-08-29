defmodule Kantele.World.Room.Qianting do
  @moduledoc """
  千厅大门房间（对应 ExKantele.World.Room.Qianting / feature/room_qianting.c）

  功能：
  - 大门开关状态机（:close/:open）
  - 推门/关门动作，自动 10s 关门定时器
  - 跨房间同步（zoudao 走道出口同步）
  - valid_leave 权限拦截（主人/许可可进）
  - 动态 room long 生成（大门状态 + 老仆扫地）
  """
  alias Kantele.World.Room
  alias Kantele.Scheduler
  alias Kalevala.Character.Conn

  @gate_states [:close, :open]
  @auto_close_delay 10_000
  @zoudao_path "/d/room/panlong/zoudao"
  @laopu_name "老仆"

  @push_msgs %{
    owner: "主人推门",
    laopu_for_owner: "老仆帮主人开门",
    laopu_for_permit: "拦住 {respect} 请回",
    laopu_opens: "老仆开门",
    nobody: "大门被打开"
  }

  @close_msgs %{
    owner: "主人关门",
    laopu_for_owner: "老仆帮主人关门",
    owner_self: "自己关门",
    laopu_closes: "老仆关门",
    nobody: "大门被关上"
  }

  @broadcast_push "大门被推开"
  @broadcast_close "大门被关上"

  @valid_leave_msgs %{
    owner: "请进",
    permit: "朋友请进",
    deny: "非请莫入"
  }

  @doc "初始化房间状态"
  def init_room do
    %{
      gate: :close,
      exits: ["south", "east", "west"],
      laopu_present: true,
      laopu_living: true
    }
  end

  @doc "推门（玩家主动 push）"
  def do_push(room, player, laopu) do
    if room.state.gate == :open do
      {:error, "大门开着呢，你还推什么？"}
    else
      {new_room, msgs} = _do_push(room, player, laopu)
      {:ok, new_room, msgs}
    end
  end

  @doc "关门（玩家主动或自动关门）"
  def do_close(room, player, laopu, auto_close \\ false) do
    if room.state.gate == :close do
      {:error, "大门关着呢，你还再再关一过？"}
    else
      {new_room, msgs} = _do_close(room, player, laopu, auto_close)
      {:ok, new_room, msgs}
    end
  end

  @doc "自动关门定时器回调"
  def auto_close_timer(room, laopu) do
    if room.state.gate == :open do
      do_close(room, nil, laopu, true)
    else
      {:noop, room}
    end
  end

  @doc "valid_leave 权限拦截（往 north 方向移动 = 进入宅院）"
  def check_valid_leave(room, player, dir, laopu) do
    if dir != "north" or not laopu_living(room) do
      {:passthrough}
    else
      cond do
        laopu_owner?(room, player) -> {:allow, "请进"}
        laopu_owner_permit?(room, player) -> {:allow, "朋友请进"}
        true -> {:deny, "非请莫入"}
      end
    end
  end

  @doc "生成动态 room long（大门状态 + 老仆扫地）"
  def generate_long(base_long, room, laopu_present) do
    msg = "    "
    if laopu_present do
      msg = msg <> "老仆人扫扫"
    end
    msg = msg <> (if room.state.gate == :open, do: "大门敞开", else: "大门紧闭")
    base_long <> sort_string(msg, 60, 0)
  end

  # ---- 内部实现 ----

  defp laopu_living(room) do
    room.state.laopu_living
  end

  defp laopu_owner?(room, player) do
    room.state.laopu_owner_id == player.id
  end

  defp laopu_owner_permit?(room, player) do
    player.id in room.state.laopu_owner_permits
  end

  defp laopu_owner(room) do
    room.state.laopu_owner_id
  end

  defp laopu_living(room) do
    room.state.laopu_living
  end

  defp laopu_present(room) do
    room.state.laopu_present
  end

  # ---- 内部实现 ----

  defp _do_push(room, player, laopu) do
    msg_type = cond do
      laopu_owner?(room, player) -> :owner
      not laopu_living(room) or not laopu_present(room) -> :nobody
      not laopu_owner?(room, player) and not laopu_owner_permit?(room, player) -> :laopu_for_permit
      laopu_living(room) -> :laopu_opens
      true -> :nobody
    end

    room_msg = case msg_type do
      :owner -> format_msg("主人推门", player)
      :laopu_for_owner -> format_msg("老仆帮主人开门", player)
      :laopu_for_permit -> format_msg("拦住 {respect} 请回", player, respect_title(player))
      :laopu_opens -> format_msg("老仆开门", player)
      :nobody -> "大门被打开"
    end

    # 组装消息
    msgs = [
      %{
        type: :vision,
        target: :room,
        text: room_msg
      }
    ]

    # 广播到走道
    msgs = [
      %{
        type: :broadcast,
        target: :zoudao,
        text: "大门被推开"
      }
    ] ++ msgs

    # 更新房间状态：开门，增加 north 出口
    new_state = %{
      room.state
      | gate: :open,
      exits: room.state.exits ++ ["north"]
    }

    # 跨房间同步到 zoudao
    msgs = [
      %{
        type: :sync_room,
        target: "/d/room/panlong/zoudao",
        updates: %{
          "exits/south" => "qianting.ex",
          "gate" => :open
        }
      }
    ] ++ msgs

    # 取消旧定时器，设置 10s 自动关门
    msgs = [
      %{
        type: :cancel_timer,
        name: :qianting_auto_close
      }
    ] ++ msgs

    msgs = [
      %{
        type: :set_timer,
        name: :qianting_auto_close,
        delay: 10_000,
        callback: {__MODULE__, :auto_close_timer, []}
      }
    ] ++ msgs

    new_room = %{room | state: new_state}
    {new_room, Enum.reverse(msgs)}
  end

  defp _do_close(room, player, laopu, auto_close) do
    msg_type = cond do
      auto_close -> :nobody
      laopu_owner?(room, player) -> :owner_self
      not laopu_living(room) or not laopu_present(room) -> :nobody
      laopu_owner?(room, player) -> :laopu_for_owner
      laopu_living(room) -> :laopu_closes
      true -> :nobody
    end

    room_msg = case msg_type do
      :owner -> format_msg("主人关门", player)
      :owner_self -> format_msg("自己关门", player)
      :laopu_for_owner -> format_msg("老仆帮主人关门", player)
      :laopu_closes -> format_msg("老仆关门", player)
      :nobody -> "大门被关上"
    end

    msgs = [
      %{
        type: :vision,
        target: :room,
        text: room_msg
      }
    ]

    msgs = [
      %{
        type: :broadcast,
        target: :zoudao,
        text: "大门被关上"
      }
    ] ++ msgs

    new_state = %{
      room.state
      | gate: :close,
      exits: room.state.exits -- ["north"]
    }

    msgs = [
      %{
        type: :sync_room,
        target: "/d/room/panlong/zoudao",
        updates: %{
          "exits/south" => :delete,
          "gate" => :close
        }
      }
    ] ++ msgs

    new_room = %{room | state: new_state}
    {new_room, Enum.reverse(msgs)}
  end

  defp format_msg(template, player, extra \\ []) do
    s = template
    |> String.replace("$N", player.name)
    |> String.replace("$n", "老仆")
    |> String.replace("{respect}", respect_title(player))
    Enum.reduce(extra, s, fn {k, v}, acc -> String.replace(acc, "{" <> k <> "}", v) end)
  end

  @doc "根据声望获取称谓（公开接口，供外部调用）"
  def respect_title(player) do
    case player.shen do
      s when s > 10000 -> "大传"
      s when s > 5000 -> "传士"
      s when s > 500 -> "良善"
      s when s > -500 -> "少传"
      s when s > -5000 -> "恶徒"
      _ -> "魔头"
    end
  end

  defp sort_string(str, width, indent) do
    String.replace(str, "。", "。\n")
    |> String.split("\n")
    |> Enum.map(&String.pad_leading(&1, width))
    |> Enum.join("\n")
  end
end