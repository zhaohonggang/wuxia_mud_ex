defmodule Kantele.World.RoomActions.Jueqing.JianshiTest.FakeRoom do
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

defmodule Kantele.World.RoomActions.Jueqing.JianshiTest do
  @moduledoc """
  P5-4aq-B：`d/jueqing/jianshi.c` 的 `do_pull` / `do_pick`。

  - do_pull "hua"：置房间 state `marks/拉`（再拉仅私发「画已经被拉破了」）
  - do_pick "junzi jian"/"shunv jian"：须 `marks/拉` 已置（LPC 的 `marks/君`/`marks/女`
    为死代码，恒假），取剑经 `Items.get` + `Helpers.give_item` 实例化，并置
    `marks/junzi_taken` / `marks/shunv_taken` 防重复取。

  房间 state 测试沿用 FakeRoom + 唯一房号模式（同 putiyuan/jianzhong）：handler 直接
  以 `Jianshi.run/2` 调用并显式传 `room_id`，绕开注册表按房号查找（唯一房号不在
  `@registry` 中）；注册表映射由 `room_action_handlers_test.exs` 覆盖。
  """
  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kalevala.Character.Conn.Private
  alias Kalevala.Character.Conn.Text
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.World.Items
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Jueqing.Jianshi
  alias Kantele.World.RoomActions.Jueqing.JianshiTest.FakeRoom

  @room "jueqing:jianshi"

  defp meta(overrides) do
    overrides = if is_list(overrides), do: Map.new(overrides), else: overrides

    vitals =
      Map.merge(
        %{qi: 200, jing: 200, neili: 100, max_neili: 100, max_qi: 200, max_jing: 200},
        Map.get(overrides, :vitals, %{})
      )

    combat =
      %{Combat.new() | busy: Map.get(overrides, :busy, 0), enemies: Map.get(overrides, :enemies, [])}

    %PlayerMeta{vitals: vitals, stats: Stats.new(), combat: combat, temp: %{}}
  end

  defp conn_in(room_id, overrides \\ %{}) do
    %Conn{
      character: %Kalevala.Character{
        id: "c1",
        name: "测试",
        description: "测试角色",
        room_id: room_id,
        meta: meta(overrides)
      },
      private: %Private{
        room: %Room{id: room_id, key: "r", zone_id: "z", actions: %{}},
        channel_changes: []
      },
      output: [],
      events: []
    }
  end

  defp run(conn, verb, arg), do: Jianshi.run(conn, %{verb: verb, trailing: arg, room_id: conn.character.room_id})

  defp texts(conn) do
    Enum.flat_map(conn.output, fn
      %Text{data: data} -> [data]
      _ -> []
    end)
  end

  defp publishes(conn) do
    conn.private.channel_changes
    |> Enum.reverse()
    |> Enum.filter(&match?({:publish, _c, _e, _o, _f}, &1))
    |> Enum.map(fn {:publish, channel, event, _opts, _err} -> {channel, event.data.text} end)
  end

  defp inventory_ids(conn) do
    char = conn.private.update_character || conn.character
    Enum.map(char.inventory, & &1.item_id)
  end

  setup do
    # 注入与 clone_lib.ucl 的 items "junzijian" / "shunvjian" 一致的物品定义，
    # 供 do_pick 经 Items.get + give_item 实例化。
    Items.put("junzijian", %Kalevala.World.Item{id: "junzijian", name: "君子剑", meta: %{}})
    Items.put("shunvjian", %Kalevala.World.Item{id: "shunvjian", name: "淑女剑", meta: %{}})
    room_id = "#{@room}:test#{System.unique_integer([:positive])}"
    start_supervised!({FakeRoom, {room_id, []}})
    %{room_id: room_id}
  end

  describe "do_pull（拉画）" do
    test "参数非 hua → 提示", %{room_id: room_id} do
      conn = conn_in(room_id)
      conn2 = run(conn, "pull", "foo")
      assert texts(conn2) == ["你要做什么？\n"]
    end

    test "第一次 pull hua → 置 marks/拉 + 广播拉破", %{room_id: room_id} do
      conn = conn_in(room_id)
      conn2 = run(conn, "pull", "hua")
      assert Room.get_state_by_id(room_id, "marks/拉") == 1
      assert Enum.any?(publishes(conn2), fn {_c, t} -> String.contains?(t, "将墙上的画拉破了") end)
    end

    test "已拉 pull hua → 仅私发「画已经被拉破了」（无新广播）", %{room_id: room_id} do
      conn = conn_in(room_id)
      conn2 = run(conn, "pull", "hua")
      conn3 = run(conn2, "pull", "hua")
      # output/channel_changes 在同一 conn 上累积：第一次那条仍在，
      # 关键断言是「没有第二次广播」（总数仍为 1）且末条私发为已拉破提示。
      assert List.last(texts(conn3)) == "画已经被拉破了。\n"
      assert length(publishes(conn3)) == 1
    end
  end

  describe "do_pick（取君子剑/淑女剑）" do
    test "参数非 junzi/shunv jian → 提示", %{room_id: room_id} do
      conn = conn_in(room_id)
      conn2 = run(conn, "pick", "foo")
      assert texts(conn2) == ["你要拿什么？\n"]
    end

    test "未拉画 pick junzi jian → 门控失败「你要拿什么？」", %{room_id: room_id} do
      conn = conn_in(room_id)
      conn2 = run(conn, "pick", "junzi jian")
      assert texts(conn2) == ["你要拿什么？\n"]
      assert Room.get_state_by_id(room_id, "marks/junzi_taken") == nil
    end

    test "拉画后 pick junzi jian → 取剑 + 广播 + 置 taken", %{room_id: room_id} do
      conn0 = conn_in(room_id)
      _ = run(conn0, "pull", "hua")
      conn = conn_in(room_id)
      conn2 = run(conn, "pick", "junzi jian")

      assert Enum.any?(publishes(conn2), fn {_c, t} ->
               String.contains?(t, "君子剑") and String.contains?(t, "取了下来")
             end)

      assert Room.get_state_by_id(room_id, "marks/junzi_taken") == 1
      assert "junzijian" in inventory_ids(conn2)
    end

    test "已取过 pick junzi jian 再取 → 君子剑已被拿走", %{room_id: room_id} do
      conn0 = conn_in(room_id)
      _ = run(conn0, "pull", "hua")
      conn1 = conn_in(room_id)
      _ = run(conn1, "pick", "junzi jian")
      conn2 = conn_in(room_id)
      conn3 = run(conn2, "pick", "junzi jian")
      assert texts(conn3) == ["君子剑已被拿走。\n"]
    end

    test "pick shunv jian 同理（独立标记）", %{room_id: room_id} do
      conn0 = conn_in(room_id)
      _ = run(conn0, "pull", "hua")
      conn = conn_in(room_id)
      conn2 = run(conn, "pick", "shunv jian")

      assert Enum.any?(publishes(conn2), fn {_c, t} ->
               String.contains?(t, "淑女剑") and String.contains?(t, "取了下来")
             end)

      assert Room.get_state_by_id(room_id, "marks/shunv_taken") == 1
      assert "shunvjian" in inventory_ids(conn2)
    end

    test "取完君子剑后 pick shunv jian 仍可取（标记独立）", %{room_id: room_id} do
      conn0 = conn_in(room_id)
      _ = run(conn0, "pull", "hua")
      conn1 = conn_in(room_id)
      _ = run(conn1, "pick", "junzi jian")
      conn = conn_in(room_id)
      conn2 = run(conn, "pick", "shunv jian")
      assert "shunvjian" in inventory_ids(conn2)
      assert Room.get_state_by_id(room_id, "marks/shunv_taken") == 1
    end
  end
end
