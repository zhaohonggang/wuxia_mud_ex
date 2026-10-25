defmodule Kantele.World.RoomActions.City.QiyuanTest.FakeRoom do
  @moduledoc """
  `{:global, {Kalevala.World.Room, room_id}}` 最小替身（同 `banquet_test` / `bet_test`）。

  `Room.get_state_by_id/2` / `put_state_by_id/3` 读写的正是房间进程的
  `state.data.state`，故这里只需一个带 `data: %Room{state: ...}` 的 GenServer。
  """
  use GenServer

  def start_link({room_id, opts}) do
    GenServer.start_link(__MODULE__, {room_id, opts},
      name: {:global, {Kalevala.World.Room, room_id}}
    )
  end

  @impl true
  def init({room_id, opts}) do
    {:ok,
     %{
       data: %Kantele.World.Room{id: room_id, state: Keyword.get(opts, :state, %{})},
       private: %{characters: [], item_instances: []}
     }}
  end
end

defmodule Kantele.World.RoomActions.City.QiyuanTest do
  @moduledoc """
  P5-9 #9 一次性场景：棋苑围棋 / 五子棋对局（移植自 `d/city/qiyuan/qiyuan2.c`，
  qiyuan3/4 同构）。

  分层测试：
  1. **注册表**：qiyuan2/3/4 的 7 个动词（sit/leave/pass/new/play/undo/refresh）
     全部指向 `City.Qiyuan`；非棋室 / 未知动词 / 无角色上下文 → `:not_handled`。
  2. **sit / leave / pass**：入座座位落房 state + `meta.temp["weiqi_seat"]`、
     各失败分支（已坐 / 非法色 / 占位 / 未坐）。
  3. **new**：未坐 / 缺对手 / 开盘播盘 + 「轮到黑方<名>走棋」。
  4. **play**：旁观 / 未开局 / 非本手 / 坐标错 / 占位 / 成功播「上一步」+ 换手 /
     五子连珠判胜。
  5. **undo**：旁观 / 未开局 / 非五子棋 / 未走子 / 非本手 / 已悔过 / 成功回退。
  6. **refresh**：空盘 / 私发盘面 + 上一步 + 轮到谁。
  7. **多棋室**：qiyuan3 / qiyuan4 同样生效。

  注：`City.Qiyuan.run/2` 以 room_id 精确匹配三间棋室（`room_id in @rooms`），
  故本测试用**真实房号**而非唯一后缀，并 `async: false`（同一 `:global` 房名
  在用例间由 `start_supervised!` 逐次启停，顺序执行不冲突）。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kalevala.Character.Conn.Private
  alias Kantele.Character.PlayerMeta
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.City.Qiyuan
  alias Kantele.World.RoomActions.City.QiyuanTest.FakeRoom
  alias Kantele.World.RoomActionHandlers
  alias Kantele.World.Weiqi

  @qiyuan2 "city:qiyuan2"
  @qiyuan3 "city:qiyuan3"
  @qiyuan4 "city:qiyuan4"

  @verbs ~w(do_sit do_leave do_pass do_new do_play do_undo do_refresh)

  setup do
    start_supervised!({FakeRoom, {@qiyuan2, []}}, id: :qiyuan2_room)
    :ok
  end

  # ---- 注册表 ---------------------------------------------------------------

  describe "注册表" do
    test "三间棋室的 7 个动词都指向 City.Qiyuan" do
      for room <- [@qiyuan2, @qiyuan3, @qiyuan4], verb <- @verbs do
        assert RoomActionHandlers.lookup(room, verb) == {:ok, {Qiyuan, :run}},
               "#{room} #{verb} 未注册"
      end
    end

    test "非棋室 → :not_handled" do
      conn = conn("some:room", "p1", "张三")

      assert Qiyuan.run(conn, %{verb: "do_sit", trailing: "black", room_id: "some:room"}) ==
               :not_handled
    end

    test "未知动词 → :not_handled" do
      conn = conn(@qiyuan2, "p1", "张三")

      assert Qiyuan.run(conn, %{verb: "do_dance", trailing: "", room_id: @qiyuan2}) ==
               :not_handled
    end

    test "无角色上下文 → :not_handled" do
      assert Qiyuan.run(%Conn{}, %{verb: "do_sit", trailing: "black", room_id: @qiyuan2}) ==
               :not_handled
    end
  end

  # ---- sit ------------------------------------------------------------------

  describe "sit" do
    test "坐黑棋：房 state 记座、本人 temp 记 seat、播「坐上了黑色的石凳」" do
      result = run(conn(@qiyuan2, "p1", "张三"), "do_sit", "black", @qiyuan2)

      assert seat_of(result) == "black"
      assert state(@qiyuan2).seats["black"] == %{id: "p1", name: "张三"}
      assert state(@qiyuan2).seats["white"] == nil
      assert published(result) == ["{npc}坐上了黑色的石凳。\n"]
    end

    test "坐白棋：播「坐上了白色的石凳」" do
      result = run(conn(@qiyuan2, "p1", "张三"), "do_sit", "white", @qiyuan2)

      assert seat_of(result) == "white"
      assert state(@qiyuan2).seats["white"] == %{id: "p1", name: "张三"}
      assert published(result) == ["{npc}坐上了白色的石凳。\n"]
    end

    test "非法颜色 → 你想玩黑棋还是白棋" do
      result = run(conn(@qiyuan2, "p1", "张三"), "do_sit", "red", @qiyuan2)

      assert output(result) == "你想玩黑棋还是白棋？\n"
      assert state(@qiyuan2) == nil
    end

    test "空参数 → 你想玩黑棋还是白棋" do
      result = run(conn(@qiyuan2, "p1", "张三"), "do_sit", "", @qiyuan2)

      assert output(result) == "你想玩黑棋还是白棋？\n"
    end

    test "已坐着 → 你已经坐着了" do
      conn = run(conn(@qiyuan2, "p1", "张三"), "do_sit", "black", @qiyuan2)

      result = run(conn, "do_sit", "white", @qiyuan2)

      assert output(result) == "你已经坐着了。\n"
      # 座位没变
      assert seat_of(result) == "black"
      assert state(@qiyuan2).seats["white"] == nil
    end

    test "位子有人 → 这个位子上已经有人了" do
      _black = run(conn(@qiyuan2, "p1", "张三"), "do_sit", "black", @qiyuan2)

      result = run(conn(@qiyuan2, "p2", "李四"), "do_sit", "black", @qiyuan2)

      assert output(result) == "这个位子上已经有人了！\n"
      assert seat_of(result) == nil
      # 仍是张三
      assert state(@qiyuan2).seats["black"] == %{id: "p1", name: "张三"}
    end
  end

  # ---- leave / pass ---------------------------------------------------------

  describe "leave" do
    test "未坐 → 你没有在下棋" do
      result = run(conn(@qiyuan2, "p1", "张三"), "do_leave", "", @qiyuan2)

      assert output(result) == "你没有在下棋。\n"
    end

    test "坐着离开 → 播「不想再下了，站了起来」+ 清座 + 弃局" do
      conn = run(conn(@qiyuan2, "p1", "张三"), "do_sit", "black", @qiyuan2)

      result = run(conn, "do_leave", "", @qiyuan2)

      assert published(result) == ["{npc}不想再下了，站了起来。\n"]
      assert seat_of(result) == nil
      assert state(@qiyuan2).seats["black"] == nil
    end

    test "离开同时弃掉进行中的棋局" do
      {black, _white} = seated_pair(@qiyuan2)
      black = run(black, "do_new", "", @qiyuan2)
      assert state(@qiyuan2).game != nil

      _result = run(black, "do_leave", "", @qiyuan2)

      assert state(@qiyuan2).game == nil
      assert state(@qiyuan2).action == nil
    end
  end

  describe "pass" do
    test "未坐 → 你没有在下棋" do
      result = run(conn(@qiyuan2, "p1", "张三"), "do_pass", "", @qiyuan2)

      assert output(result) == "你没有在下棋。\n"
    end

    test "投子认负 → 播「抛下棋子…我输了」+ 清座" do
      conn = run(conn(@qiyuan2, "p1", "张三"), "do_sit", "white", @qiyuan2)

      result = run(conn, "do_pass", "", @qiyuan2)

      assert published(result) == ["{npc}抛下棋子，站起来长叹一声，“我输了”\n"]
      assert seat_of(result) == nil
      assert state(@qiyuan2).seats["white"] == nil
    end
  end

  # ---- new ------------------------------------------------------------------

  describe "new" do
    test "未坐 → 你还没坐好呐" do
      result = run(conn(@qiyuan2, "p1", "张三"), "do_new", "", @qiyuan2)

      assert output(result) == "你还没坐好呐。\n"
    end

    test "只有一方坐着 → 还没有对手呐" do
      conn = run(conn(@qiyuan2, "p1", "张三"), "do_sit", "black", @qiyuan2)

      result = run(conn, "do_new", "", @qiyuan2)

      assert output(result) == "还没有对手呐。\n"
      assert state(@qiyuan2).game == nil
    end

    test "双方就座 → 播盘 + 「现在轮到黑方张三走棋」" do
      {black, _white} = seated_pair(@qiyuan2)

      result = run(black, "do_new", "", @qiyuan2)

      assert [board, turn] = published(result)
      assert String.contains?(board, "Ａ")
      assert turn == "现在轮到黑方张三走棋。\n"

      game = state(@qiyuan2).game
      assert game.bsize == 19
      assert game.status == Weiqi.status_playing()
      assert game.turn == "black"
      assert game.started == 0
      assert state(@qiyuan2).action == 1
    end

    test "-5 开五子棋：status 为 wuzi" do
      {black, _white} = seated_pair(@qiyuan2)

      _result = run(black, "do_new", "-5", @qiyuan2)

      assert state(@qiyuan2).game.status == Weiqi.status_wuzi()
    end

    test "-b9 缩盘：bsize 为 9" do
      {black, _white} = seated_pair(@qiyuan2)

      _result = run(black, "do_new", "-b9", @qiyuan2)

      assert state(@qiyuan2).game.bsize == 9
    end

    test "-b25 越界 → 回落 19" do
      {black, _white} = seated_pair(@qiyuan2)

      _result = run(black, "do_new", "-b25", @qiyuan2)

      assert state(@qiyuan2).game.bsize == 19
    end

    test "-h2 让二子：黑先布两子、轮白方" do
      {black, _white} = seated_pair(@qiyuan2)

      _result = run(black, "do_new", "-h2", @qiyuan2)

      game = state(@qiyuan2).game
      assert game.handicap == 2
      assert game.turn == "white"
      assert Enum.count(game.board, &(&1 == Weiqi.black())) == 2
    end

    test "五子棋下 -h2 让子被清零（LPC：非围棋不认让子）" do
      {black, _white} = seated_pair(@qiyuan2)

      _result = run(black, "do_new", "-5 -h2", @qiyuan2)

      assert state(@qiyuan2).game.handicap == 0
      assert state(@qiyuan2).game.turn == "black"
    end
  end

  # ---- play -----------------------------------------------------------------

  describe "play" do
    test "旁观者 → 你是旁观者，怎么好意思瞎指挥" do
      {black, _white} = seated_pair(@qiyuan2)
      _black = run(black, "do_new", "", @qiyuan2)

      result = run(conn(@qiyuan2, "p9", "王五"), "do_play", "A1", @qiyuan2)

      assert output(result) == "你是旁观者，怎么好意思瞎指挥？\n"
    end

    test "未开局 → 还没新开一局棋呐" do
      {black, _white} = seated_pair(@qiyuan2)

      result = run(black, "do_play", "A1", @qiyuan2)

      assert output(result) == "还没新开一局棋呐。\n"
    end

    test "非本手 → 还没轮到你走棋" do
      {black, white} = seated_pair(@qiyuan2)
      _black = run(black, "do_new", "", @qiyuan2)

      result = run(white, "do_play", "A1", @qiyuan2)

      assert output(result) == "还没轮到你走棋。\n"
    end

    test "坐标错 → 你要下在哪里" do
      {black, _white} = seated_pair(@qiyuan2)
      black = run(black, "do_new", "", @qiyuan2)

      result = run(black, "do_play", "Z9", @qiyuan2)

      assert output(result) == "你要下在哪里？\n"
    end

    test "占位 → 这个位置上已经有子了" do
      {black, white} = seated_pair(@qiyuan2)
      black = run(black, "do_new", "", @qiyuan2)
      black = run(black, "do_play", "A1", @qiyuan2)

      result = run(white, "do_play", "A1", @qiyuan2)

      assert output(result) == "这个位置上已经有子了！\n"
      # 黑子还在
      assert first(state(@qiyuan2).game.board) == Weiqi.black()
      assert black != nil
    end

    test "落子成功 → 播「黑棋上一步走在了A1」+ 盘 + 轮到白方" do
      {black, _white} = seated_pair(@qiyuan2)
      black = run(black, "do_new", "", @qiyuan2)

      result = run(black, "do_play", "A1", @qiyuan2)

      assert [step, board, turn] = published(result)
      assert step == "\n黑棋上一步走在了A1\n"
      assert String.contains?(board, "●")
      assert turn == "现在轮到白方李四走棋。\n"

      game = state(@qiyuan2).game
      assert game.started == 1
      assert game.turn == "white"
      assert game.lastmove == "A1"
      assert first(game.board) == Weiqi.black()
    end

    test "五子连珠 → 判胜「黑方张三胜」" do
      {black, white} = seated_pair(@qiyuan2)
      black = run(black, "do_new", "-5", @qiyuan2)

      {_black, _white, last} =
        plays({black, white}, @qiyuan2, ~w(A1 A19 B1 B19 C1 C19 D1 D19 E1))

      published = published(last)
      assert List.last(published) == "黑方张三胜。\n"
      assert Enum.any?(published, &String.contains?(&1, "●"))
    end

    test "五子棋未连成 → 仍播「轮到白方」" do
      {black, white} = seated_pair(@qiyuan2)
      black = run(black, "do_new", "-5", @qiyuan2)

      {_black, _white, last} = plays({black, white}, @qiyuan2, ~w(A1 A19 B1 B19 C1 C19 D1))

      assert List.last(published(last)) == "现在轮到白方李四走棋。\n"
    end
  end

  # ---- undo -----------------------------------------------------------------

  describe "undo" do
    test "旁观者 → 你是旁观者，怎么好意思瞎指挥" do
      {black, _white} = seated_pair(@qiyuan2)
      _black = run(black, "do_new", "-5", @qiyuan2)

      result = run(conn(@qiyuan2, "p9", "王五"), "do_undo", "", @qiyuan2)

      assert output(result) == "你是旁观者，怎么好意思瞎指挥？\n"
    end

    test "未开局 → 还没新开一局棋呐" do
      {black, _white} = seated_pair(@qiyuan2)

      result = run(black, "do_undo", "", @qiyuan2)

      assert output(result) == "还没新开一局棋呐。\n"
    end

    test "围棋局 → 目前只提供五子棋的悔棋功能" do
      {black, white} = seated_pair(@qiyuan2)
      black = run(black, "do_new", "", @qiyuan2)
      _black = run(black, "do_play", "A1", @qiyuan2)

      result = run(white, "do_undo", "", @qiyuan2)

      assert output(result) == "目前只提供五子棋的悔棋功能。\n"
    end

    test "一步没走 → 一步都没走，悔什么棋" do
      {black, _white} = seated_pair(@qiyuan2)
      black = run(black, "do_new", "-5", @qiyuan2)

      result = run(black, "do_undo", "", @qiyuan2)

      assert output(result) == "一步都没走，悔什么棋。\n"
    end

    test "非本手 → 要悔棋也得跟人家商量一下呀" do
      {black, white} = seated_pair(@qiyuan2)
      black = run(black, "do_new", "-5", @qiyuan2)
      _black = run(black, "do_play", "A1", @qiyuan2)

      # 落子后轮到白方，黑方悔棋 → 非本手
      result = run(black, "do_undo", "", @qiyuan2)

      assert output(result) == "要悔棋也得跟人家商量一下呀。\n"
      assert white != nil
    end

    test "成功悔一步 → 盘面回退 + 轮到黑方" do
      {black, white} = seated_pair(@qiyuan2)
      black = run(black, "do_new", "-5", @qiyuan2)
      black = run(black, "do_play", "A1", @qiyuan2)

      result = run(white, "do_undo", "", @qiyuan2)

      # lastmove 为空（只走过一步）→ 不播「上一步」
      assert [board, turn] = published(result)
      assert String.contains?(board, "Ａ")
      refute String.contains?(board, "●")
      assert turn == "现在轮到黑方张三走棋。\n"

      game = state(@qiyuan2).game
      assert game.undoed == 1
      assert game.started == 0
      assert game.lastmove == ""
      assert game.turn == "black"
      assert black != nil
    end

    test "悔棋播「上一步」取悔棋前的颜色（LPC 原样，与 refresh 的取法相反）" do
      {black, white} = seated_pair(@qiyuan2)
      black = run(black, "do_new", "-5", @qiyuan2)
      {black, white, _last} = plays({black, white}, @qiyuan2, ~w(A1 A19 B1))

      # 三步后轮到白方；白方悔棋 → 悔棋前 turn=white → 文案「白棋上一步走在了A19」
      result = run(white, "do_undo", "", @qiyuan2)

      assert [step, board, turn] = published(result)
      assert step == "\n白棋上一步走在了A19\n"
      assert String.contains?(board, "●")
      assert turn == "现在轮到黑方张三走棋。\n"
      assert black != nil

      game = state(@qiyuan2).game
      assert game.lastmove == "A19"
      assert game.started == 1
      assert game.undoed == 1
      assert game.turn == "black"
    end

    test "已悔过 → 一次只能悔一步棋" do
      {black, white} = seated_pair(@qiyuan2)
      black = run(black, "do_new", "-5", @qiyuan2)
      {black, white, _last} = plays({black, white}, @qiyuan2, ~w(A1 A19 B1))

      # 白方悔掉 B1（最后一步）
      white = run(white, "do_undo", "", @qiyuan2)
      assert state(@qiyuan2).game.undoed == 1
      # 悔后轮到黑方；黑方再悔 → 已悔过
      result = run(black, "do_undo", "", @qiyuan2)

      assert output(result) == "一次只能悔一步棋。\n"
      assert white != nil
    end
  end

  # ---- refresh --------------------------------------------------------------

  describe "refresh" do
    test "空盘 → 棋盘上是空的" do
      result = run(conn(@qiyuan2, "p1", "张三"), "do_refresh", "", @qiyuan2)

      assert output(result) == "棋盘上是空的。\n"
    end

    test "有局 → 私发盘面 + 轮到谁（不广播）" do
      {black, _white} = seated_pair(@qiyuan2)
      black = run(black, "do_new", "", @qiyuan2)

      result = run(black, "do_refresh", "", @qiyuan2)

      out = output(result)
      assert String.contains?(out, "Ａ")
      assert String.contains?(out, "现在轮到黑方张三走棋。\n")
      # 私发，不广播
      assert published(result) == []
    end

    test "已走子 → 先报上一步再报盘面" do
      {black, _white} = seated_pair(@qiyuan2)
      black = run(black, "do_new", "", @qiyuan2)
      black = run(black, "do_play", "A1", @qiyuan2)

      result = run(black, "do_refresh", "", @qiyuan2)

      out = output(result)
      assert String.contains?(out, "黑棋上一步走在了A1")
      assert String.contains?(out, "现在轮到白方李四走棋。\n")
    end
  end

  # ---- 多棋室 ---------------------------------------------------------------

  describe "多棋室" do
    test "qiyuan3 同样可入座开局" do
      start_supervised!({FakeRoom, {@qiyuan3, []}}, id: :qiyuan3_room)

      {black, _white} = seated_pair(@qiyuan3)
      result = run(black, "do_new", "", @qiyuan3)

      assert List.last(published(result)) == "现在轮到黑方张三走棋。\n"
      assert state(@qiyuan3).game != nil
    end

    test "qiyuan4 同样可入座开局" do
      start_supervised!({FakeRoom, {@qiyuan4, []}}, id: :qiyuan4_room)

      {black, _white} = seated_pair(@qiyuan4)
      result = run(black, "do_new", "-5", @qiyuan4)

      assert List.last(published(result)) == "现在轮到黑方张三走棋。\n"
      assert state(@qiyuan4).game.status == Weiqi.status_wuzi()
    end
  end

  # ---- helpers --------------------------------------------------------------

  # 每条命令都是独立一次输入：清掉上一条命令的 output / channel_changes
  # （引擎每轮 flush 后即清空），只保留 private.update_character 里累积的角色状态
  # （座位记在 meta.temp，必须跨命令保留）。
  defp run(conn, verb, trailing, room_id) do
    conn = %{conn | output: [], private: %{conn.private | channel_changes: []}}

    case Qiyuan.run(conn, %{verb: verb, trailing: trailing, room_id: room_id}) do
      {:handled, conn2} -> conn2
      other -> other
    end
  end

  # 黑白双方各坐一侧
  defp seated_pair(room_id) do
    black = run(conn(room_id, "p1", "张三"), "do_sit", "black", room_id)
    white = run(conn(room_id, "p2", "李四"), "do_sit", "white", room_id)
    {black, white}
  end

  # 交替落子（黑先），返回 {black, white, 最后一手的 conn}
  defp plays({black, white}, room_id, coords) do
    coords
    |> Enum.with_index()
    |> Enum.reduce({black, white, nil}, fn {coord, i}, {b, w, _last} ->
      if rem(i, 2) == 0 do
        b2 = run(b, "do_play", coord, room_id)
        {b2, w, b2}
      else
        w2 = run(w, "do_play", coord, room_id)
        {b, w2, w2}
      end
    end)
  end

  defp conn(room_id, id, name, coins \\ 100_000) do
    %Conn{
      character: %Kalevala.Character{
        id: id,
        name: name,
        room_id: room_id,
        meta: %PlayerMeta{temp: %{}, coins: coins},
        inventory: []
      },
      private: %Private{channel_changes: []},
      output: []
    }
  end

  defp character_of(conn), do: conn.private.update_character || conn.character

  defp seat_of(conn) do
    Map.get(character_of(conn).meta.temp || %{}, "weiqi_seat")
  end

  defp output(conn), do: Enum.map_join(conn.output, & &1.data)

  defp state(room_id), do: Room.get_state_by_id(room_id, "qiyuan")

  defp first(list), do: List.first(list)

  defp published(conn) do
    conn.private.channel_changes
    |> Enum.reverse()
    |> Enum.filter(fn
      {:publish, _chan, %{data: %{type: "vision"}}, _opts, _err} -> true
      _ -> false
    end)
    |> Enum.map(fn {:publish, _chan, event, _opts, _err} -> event.data.text end)
  end
end
