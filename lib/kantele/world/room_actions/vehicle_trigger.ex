defmodule Kantele.World.RoomActions.Vehicle.Trigger do
  @moduledoc """
  P5-8 / 通信中继·载具：`on_board` 载具触发器（数据驱动）。

  房间级 `RoomAction`：按 `room_id` 查 `@configs` 取出该载具的配置，转交
  `Kantele.World.RoomActions.Vehicle.check_trigger/3` 启动定时链路。UCL 里这些房间
  已有 `actions = { insert/do_insert, yell/do_yell, cross/do_cross, shang/do_shang }`
  （转换器直接写出），本模块把它们统一接到载具逻辑，无需改 UCL。

  覆盖房：
  - heimuya:up2 → basket → heimuya:up3（吊篮第一程）
  - heimuya:up3 → basket → heimuya:up4（吊篮第二程）
  - guiyun:taihu → duchuan → guiyun:matou（渡船去程）
  - guiyun:matou → duchuan → guiyun:taihu（渡船回程）

  文案逐字取自 LPC 源（heimuya/up2.c·up3.c、guiyun/taihu.c·matou.c）。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Vehicle

  @configs %{
    # 黑木崖吊篮：第一程 up2 → basket → up3
    "heimuya:up2" => %{
      vehicle: "heimuya:basket",
      enter_dir: "enter",
      out_dir: "out",
      dest: "heimuya:up3",
      timings: %{on_board: 5000, arrive: 10_000, close: 10_000},
      trigger_vision: "只见一个吊篮(basket)从天而降，你不禁一怔！\n",
      busy_vision: "看样子你得等下拨儿。\n",
      already_vision: nil,
      vehicle_vision: nil,
      on_board_vision: "只见吊篮缓缓向上，四周无限美好，\n你似乎置身于一处人间仙境。\n",
      on_board_vehicle_vision: nil,
      arrive_vision: "噔的一声，你似乎一下从天上到了地上。\n",
      close_vision: nil,
      trigger_flag: "vehicle:heimuya_basket",
      timer_key: "vehicle:heimuya:up2"
    },
    # 黑木崖吊篮：第二程 up3 → basket → up4
    "heimuya:up3" => %{
      vehicle: "heimuya:basket",
      enter_dir: "enter",
      out_dir: "out",
      dest: "heimuya:up4",
      timings: %{on_board: 5000, arrive: 10_000, close: 10_000},
      trigger_vision: "只见一个吊篮(basket)从天而降，你不禁一怔！\n",
      busy_vision: "看样子你得等下拨儿。\n",
      already_vision: nil,
      vehicle_vision: nil,
      on_board_vision: "只见吊篮缓缓向上，四周无限美好，\n你似乎置身于一处人间仙境。\n",
      on_board_vehicle_vision: nil,
      arrive_vision: "噔的一声，你似乎一下从天上到了地上。\n",
      close_vision: nil,
      trigger_flag: "vehicle:heimuya_basket",
      timer_key: "vehicle:heimuya:up3"
    },
    # 归云庄渡船：去程 taihu → duchuan → matou
    "guiyun:taihu" => %{
      vehicle: "guiyun:duchuan",
      enter_dir: "enter",
      out_dir: "out",
      dest: "guiyun:matou",
      timings: %{on_board: 15_000, arrive: 20_000, close: 20_000},
      trigger_vision: "一叶扁舟缓缓地驶了过来，艄公将一块踏脚板搭上堤岸，以便乘客\n上下。\n",
      vehicle_vision: "艄公将一块踏脚板搭上堤岸，形成一个向上的阶梯。\n",
      busy_vision: "只听得湖面上隐隐传来：“别急嘛，这儿正忙着呐……”\n",
      already_vision: "岸边一只渡船上的老艄公说道：正等着你呢，上来吧。\n",
      on_board_vision: "艄公把踏脚板收了起来，竹篙一点，扁舟向湖心驶去。\n",
      on_board_vehicle_vision:
        "艄公把踏脚板收起来，说了一声“坐稳喽”，竹篙一点，扁舟向\n湖心驶去。\n",
      arrive_vision: "艄公说“到啦，上岸吧”，随即把一块踏脚板搭上堤岸。\n",
      close_vision: "艄公把踏脚板收起来，把扁舟驶向湖心。\n",
      trigger_flag: "vehicle:guiyun_duchuan",
      timer_key: "vehicle:guiyun:taihu"
    },
    # 归云庄渡船：回程 matou → duchuan → taihu
    "guiyun:matou" => %{
      vehicle: "guiyun:duchuan",
      enter_dir: "enter",
      out_dir: "out",
      dest: "guiyun:taihu",
      timings: %{on_board: 15_000, arrive: 20_000, close: 20_000},
      trigger_vision: "一叶扁舟缓缓地驶了过来，艄公将一块踏脚板搭上堤岸，以便乘客\n上下。\n",
      vehicle_vision: "艄公将一块踏脚板搭上堤岸，形成一个向上的阶梯。\n",
      busy_vision: "只听得湖面上隐隐传来：“别急嘛，这儿正忙着呐……”\n",
      already_vision: "岸边一只渡船上的老艄公说道：正等着你呢，上来吧。\n",
      on_board_vision: "艄公把踏脚板收了起来，竹篙一点，扁舟向湖心驶去。\n",
      on_board_vehicle_vision:
        "艄公把踏脚板收起来，说了一声“坐稳喽”，竹篙一点，扁舟向\n湖心驶去。\n",
      arrive_vision: "艄公说“到啦，上岸吧”，随即把一块踏脚板搭上堤岸。\n",
      close_vision: "艄公把踏脚板收起来，把扁舟驶向湖心。\n",
      trigger_flag: "vehicle:guiyun_duchuan",
      timer_key: "vehicle:guiyun:matou"
    }
  }

  @impl true
  def run(conn, %{room_id: room_id}) do
    case Map.get(@configs, room_id) do
      nil -> conn
      cfg -> Vehicle.check_trigger(conn, room_id, cfg)
    end
  end

  @doc "已配置的触发房列表（覆盖度统计用）。"
  def entries(), do: Map.keys(@configs)

  @doc "测试/调试用：按 room_id 取该载具的完整配置（含文案与定时）。"
  def config(room_id), do: Map.get(@configs, room_id)
end
