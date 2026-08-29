defmodule Kantele.World.Room.Qiyuan do
  @moduledoc """
  棋苑棋房（对应 ExKantele.World.Room.Qiyuan / qiyuan.ex）

  功能：
  - 围棋/五子棋对弈状态机
  - 座位管理（black/white）
  - 游戏状态存储（Game struct）
  - 命令分发 (sit/leave/play/pass/new/undo/refresh)
  - 消息广播
  - 定时清理
  """
  alias Kantele.World.Room
  alias Kantele.Scheduler
  alias Kalevala.Character.Conn

  defstruct [
    :id,
    :key,
    :zone_id,
    :name,
    :description,
    :map_color,
    :map_icon,
    :x,
    :y,
    :z,
    exits: [],
    features: [],
    flags: [],
    # 棋房专用字段
    game: nil,
    seats: %{},
    players: %{}
  ]

  @doc "初始化棋房状态"
  def init_room do
    %{
      game: nil,
      seats: %{"black" => nil, "white" => nil},
      players: %{},
      exits: ["south"],
      features: ["qiyuan_table"],
      flags: []
    }
  end

  @doc "玩家入座"
  def sit(room, player, seat) do
    cond do
      not Map.has_key?(room.seats, seat) ->
        {:error, "无效座位：#{seat}"}

      room.seats[seat] != nil ->
        {:error, "座位已被占用"}

      player.id in Map.values(room.seats) ->
        {:error, "你已经坐在另一位置了"}

      true ->
        new_room = %{room | seats: Map.put(room.seats, seat, player.id)}
        {:ok, new_room, [
          %{
            type: :vision,
            target: :room,
            text: "#{player.name} 在 #{seat} 位坐下了。"
          }
        ]}
    end
  end

  @doc "玩家离座"
  def leave(room, player) do
    seat = Enum.find(Map.keys(room.seats), fn seat -> room.seats[seat] == player.id end)
    if seat do
      new_room = %{room | seats: Map.put(room.seats, seat, nil)}
      {:ok, new_room, [
        %{
          type: :vision,
          target: :room,
          text: "#{player.name} 站了起来。"
        }
      ]}
    else
      {:error, "你没坐在棋桌上"}
    end
  end

  @doc "开始新局"
  def new_game(room, player, arg \\ "") do
    if room.game do
      {:error, "已有进行中的棋局"}
    else
      cond do
        room.seats["black"] == nil or room.seats["white"] == nil ->
          {:error, "双方玩家都入座后才能开始"}

        true ->
          # 使用纯函数引擎创建新游戏
          game = ExKantele.World.Room.Qiyuan.Game.new_game(arg)
          game = %{game | black_id: room.seats["black"], white_id: room.seats["white"]}
          {:ok, %{room | game: game}, [
            %{
              type: :vision,
              target: :room,
              text: "新棋局开始！#{room.seats["black"]} 执黑，#{room.seats["white"]} 执白。"
            }
          ]}
      end
    end
  end

  @doc "落子"
  def play(room, player, coord) do
    cond do
      not room.game ->
        {:error, "没有进行中的棋局"}

      room.game.turn != player.id ->
        {:error, "还没轮到你落子"}

      true ->
        # 使用纯函数引擎
        case ExKantele.World.Room.Qiyuan.Game.play(room.game, coord) do
          {:error, msg} ->
            {:error, msg}

          {game, {:moved, mv}} ->
            {:ok, %{room | game: game}, [
              %{
                type: :vision,
                target: :room,
                text: "#{player.name} 在 #{coord} 落子。"
              }
            ]}

          {game, {:win, winner}} ->
            {:ok, %{room | game: nil}, [
              %{
                type: :vision,
                target: :room,
                text: "#{winner} 获胜！棋局结束。"
              }
            ]}
        end
    end
  end

  @doc "悔棋（仅五子棋）"
  def undo(room, player) do
    cond do
      not room.game ->
        {:error, "没有进行中的棋局"}

      room.game.status != :playing_wuzi ->
        {:error, "目前只提供五子棋的悔棋功能"}

      room.game.turn != player.id ->
        {:error, "不是你的回合"}

      not room.game.started ->
        {:error, "一步都没走，悔什么棋。"}

      room.game.undoable ->
        {:error, "一次只能悔一步棋。"}

      true ->
        case ExKantele.World.Room.Qiyuan.Game.undo(room.game) do
          {game, {:ok, msg}} ->
            {:ok, %{room | game: game}, [
              %{
                type: :vision,
                target: :room,
                text: msg
              }
            ]}

          {game, {:error, msg}} ->
            {:error, msg}
        end
    end
  end

  @doc "旁观/刷新棋盘"
  def refresh(room, player) do
    cond do
      not room.game ->
        {:error, "没有进行中的棋局"}

      true ->
        board_text = ExKantele.World.Room.Qiyuan.Game.show_game(room.game)
        {:ok, room, [
          %{
            type: :tell,
            target: player.id,
            text: "当前棋局：\n" <> ExKantele.World.Room.Qiyuan.Game.show_game(room.game)
          }
        ]}
    end
  end

  @doc "旁观者加入/离开通知"
  def notify_join(room, player) do
    {:ok, room, [
      %{
        type: :vision,
        target: :room,
        text: "#{player.name} 走了进来旁观。"
      }
    ]}
  end

  def notify_leave(room, player) do
    {:ok, room, [
      %{
        type: :vision,
        target: :room,
        text: "#{player.name} 离开了棋房。"
      }
    ]}
  end

  # 内部：纯函数引擎（对应 qiyuan.ex）
  defmodule Game do
    @moduledoc "围棋/五子棋纯函数引擎（移植自 qiyuan.ex）"

    # 状态常量
    @black 1
    @white 2
    @blank 0
    @aux_color 8
    @not_playing 3
    @playing 4
    @playing_wuzi 7
    @jie_possible 5
    @no_jie 6
    @winning 9
    @pos_occupied -2
    @jie_banned -3
    @no_qi_banned -4

    @handicap_stars [3 * 19 + 3, 15 * 19 + 15, 15 * 19 + 3, 3 * 19 + 15, 3 * 19 + 9, 15 * 19 + 9, 9 * 19 + 3, 9 * 19 + 15]

    defstruct cells: %{},
              bsize: 19,
              turn: "black",
              status: 3,
              handicap: 0,
              jie_flag: 6,
              jie_x_ban: -1,
              jie_y_ban: -1,
              lastmove: "",
              lastlastmove: "",
              started: false,
              undoable: false

    def new(), do: %__MODULE__{}

    # ... (后续添加纯函数逻辑)
  end
end