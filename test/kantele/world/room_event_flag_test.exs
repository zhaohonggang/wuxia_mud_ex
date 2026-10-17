defmodule Kantele.World.RoomEventFlagTest do
  @moduledoc """
  R6/P3-b 回归：房间事件里的 flag 判定不再直读 Room 结构体不存在的字段。

  历史 bug：`StealRequestEvent` 读 `context.data.skybook/no_fight/no_steal`、
  `SearchRequestEvent` 读 `context.data.no_search` —— Room defstruct 只有
  `flags` 列表，这些直读**每次求值都抛 KeyError**（steal/attempt 三个条件全踩中，
  search 每搜必崩）。修复后统一走 `Room.has_flag?/2` / flags 成员判定。

  覆盖：
  - steal：no_steal / no_fight flag → 拒绝且不崩；无 flag → 正常走到目标查找
  - search：no_search flag → 拒绝；无 flag → 正常消耗路径
  - has_flag?/2 语义（含 nil/非列表/非字符串防御）
  """

  use ExUnit.Case, async: true

  alias Kalevala.Event
  alias Kalevala.World.Room.Context
  alias Kantele.World.Room
  alias Kantele.World.Room.SearchRequestEvent
  alias Kantele.World.Room.StealRequestEvent

  defp requester do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      attributes: %{"qi" => 100, "jing" => 100, "score" => 0},
      meta: %{}
    }
  end

  defp context(room) do
    %Context{
      data: room,
      characters: [requester()],
      item_instances: [],
      assigns: %{},
      events: [],
      output: []
    }
  end

  # Context.render 的产物是 {pid, %Conn.Text{}}（纯文本 push 第三子句包装）
  defp rendered_texts(context) do
    Enum.flat_map(context.output, fn
      {_pid, %Kalevala.Character.Conn.Text{data: data}} -> [IO.iodata_to_binary(data)]
      {_pid, text} when is_binary(text) -> [text]
      _ -> []
    end)
  end

  describe "StealRequestEvent（R6 修复前每次 steal 必 KeyError）" do
    test "no_steal flag 房间：拒绝行窃且不崩" do
      room = %Room{id: "test:room", flags: ["no_steal"]}

      ctx =
        StealRequestEvent.call(context(room), %Event{
          from_pid: self(),
          topic: "steal/attempt",
          data: %{item: "剑", target: "李四"}
        })

      assert rendered_texts(ctx) == ["这里禁止行窃。\n"]
    end

    test "no_fight flag 房间：同样拒绝行窃" do
      room = %Room{id: "test:room", flags: ["no_fight"]}

      ctx =
        StealRequestEvent.call(context(room), %Event{
          from_pid: self(),
          topic: "steal/attempt",
          data: %{item: "剑", target: "李四"}
        })

      assert rendered_texts(ctx) == ["这里禁止行窃。\n"]
    end

    test "无 flag 房间：走到目标查找（目标不在 → 正常提示，不崩）" do
      room = %Room{id: "test:room"}

      ctx =
        StealRequestEvent.call(context(room), %Event{
          from_pid: self(),
          topic: "steal/attempt",
          data: %{item: "剑", target: "李四"}
        })

      assert rendered_texts(ctx) == ["你想行窃的对象不在这里。\n"]
    end

    test "无关 flag 不触发拒绝（仅按具体 flag 名判定）" do
      room = %Room{id: "test:room", flags: ["sleep_room", "outdoors"]}

      ctx =
        StealRequestEvent.call(context(room), %Event{
          from_pid: self(),
          topic: "steal/attempt",
          data: %{item: "剑", target: "李四"}
        })

      assert rendered_texts(ctx) == ["你想行窃的对象不在这里。\n"]
    end
  end

  describe "SearchRequestEvent（同类 KeyError：每次 search 必崩）" do
    test "no_search flag 房间：拒绝搜寻且不崩" do
      room = %Room{id: "test:room", flags: ["no_search"]}

      ctx =
        SearchRequestEvent.call(context(room), %Event{
          from_pid: self(),
          topic: "search/attempt",
          data: %{}
        })

      assert rendered_texts(ctx) == ["这里不允许搜寻。\n"]
    end

    test "无 flag 房间：正常消耗路径（score 0 → 未发现，确定性分支）" do
      room = %Room{id: "test:room"}

      ctx =
        SearchRequestEvent.call(context(room), %Event{
          from_pid: self(),
          topic: "search/attempt",
          data: %{}
        })

      assert rendered_texts(ctx) == ["你东张西望，什么也没找到。\n"]

      updated = Enum.find(ctx.characters, &(&1.id == "player-1"))
      assert updated.attributes["qi"] == 70
      assert updated.attributes["jing"] == 70
    end
  end

  describe "Room.has_flag?/2" do
    test "命中/未命中/防御性输入" do
      assert Room.has_flag?(%Room{flags: ["no_steal", "no_fight"]}, "no_steal")
      refute Room.has_flag?(%Room{flags: ["no_steal"]}, "no_fight")
      refute Room.has_flag?(%Room{}, "no_steal")
      refute Room.has_flag?(%Room{flags: nil}, "no_steal")
      # 非字符串 flag 不参与比较（nil / 原子都不命中）
      refute Room.has_flag?(%Room{flags: [nil, :no_steal]}, "no_steal")
    end
  end
end
