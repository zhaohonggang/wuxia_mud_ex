defmodule Kantele.World.RoomActions.MishiTest.FakeRoom do
  use GenServer

  @moduledoc """
  `{:global, {Kalevala.World.Room, room_id}}` 的最小替身（同
  `RoomActions.Shaolin.PutiyuanTest.FakeRoom`）：只提供 `data.state` 供
  `Room.get_state_by_id/put_state_by_id` 读写（`wudu:mishi` 的 `mishi_book`）。
  """

  def start_link({room_id, opts}) do
    GenServer.start_link(__MODULE__, {room_id, opts},
      name: {:global, {Kalevala.World.Room, room_id}}
    )
  end

  @impl
  def init({room_id, opts}) do
    {:ok,
     %{
       data: %Kantele.World.Room{id: room_id, state: Keyword.get(opts, :state, %{})},
       private: %{characters: [], item_instances: []}
     }}
  end
end

defmodule Kantele.World.RoomActions.MishiTest do
  @moduledoc """
  P5-6 门/容器第二批：两间石室「开盒取秘笈」移植测试。

  - `tiezhang:mishi`（`d/tiezhang/mishi.c` `do_open`）：`open he|shi he`，
    `present("tiezhang zhangpu", me)` 判重后发 `tiezhang:zhangpu`。
  - `wudu:mishi`（`d/wudu/mishi.c` `do_open`）：`open xia`，房间状态
    `mishi_book` + 玩家 `can_learn/qianzhu-wandushou` 双门控发
    `wudu:qianzhumiji`；其它参数 `:not_handled` 放行全局 `open`。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Items
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.MishiTest.FakeRoom
  alias Kantele.World.RoomActions.Shaolin.Zhonglou7.Knock, as: Zhonglou7Knock
  alias Kantele.World.RoomActions.Tiezhang.Mishi.Open, as: TiezhangOpen
  alias Kantele.World.RoomActions.Wudu.Mishi.Open, as: WuduOpen

  @tiezhang_room "tiezhang:mishi"
  @wudu_room "wudu:mishi"
  @flag "can_learn/qianzhu-wandushou"

  setup do
    # 测试环境不加载世界数据（Items 缓存为空），注入两条物品定义
    # （与 `tiezhang.ucl` items "zhangpu" / `wudu.ucl` items "qianzhumiji" 对齐）。
    Items.put("tiezhang:zhangpu", %Kalevala.World.Item{
      id: "tiezhang:zhangpu",
      name: "铁掌掌谱",
      meta: %{aliases: ["tiezhang zhangpu", "zhangpu", "pu"]}
    })

    Items.put("wudu:qianzhumiji", %Kalevala.World.Item{
      id: "wudu:qianzhumiji",
      name: "千蛛万毒手秘笈",
      meta: %{aliases: ["qianzhu miji", "miji"]}
    })

    :ok
  end

  # `d/tiezhang/obj/zhangpu.c` 的实例（aliases 与定义一致，供 present 判重用）
  defp zhangpu do
    %Kalevala.World.Item.Instance{
      id: "test-zhangpu",
      item_id: "tiezhang:zhangpu",
      item: %Kalevala.World.Item{
        id: "tiezhang:zhangpu",
        name: "铁掌掌谱",
        meta: %{aliases: ["tiezhang zhangpu", "zhangpu", "pu"]}
      }
    }
  end

  defp conn(room_id, opts \\ []) do
    character = %Kalevala.Character{
      id: "test-player",
      name: "玩家",
      room_id: room_id,
      attributes: Keyword.get(opts, :attributes, %{}),
      meta: Keyword.get(opts, :meta, %PlayerMeta{temp: %{}}),
      inventory: Keyword.get(opts, :inventory, [])
    }

    %Conn{
      character: character,
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp character_of(conn), do: conn.private.update_character || conn.character
  defp output(conn), do: Enum.map_join(conn.output, & &1.data)

  defp published(conn) do
    conn.private.channel_changes
    |> Enum.reverse()
    |> Enum.filter(fn
      {:publish, _chan, %{data: %{type: "vision"}}, _opts, _err} -> true
      _ -> false
    end)
    |> Enum.map(fn {:publish, _chan, event, _opts, _err} -> event.data.text end)
  end

  # 唯一房号：`:global` 名字避免与其它用例串扰（同 break_test 取径）
  defp start_wudu_room(state \\ %{}) do
    room_id = "wudu:mishi:#{System.unique_integer([:positive])}"
    {:ok, _pid} = FakeRoom.start_link({room_id, state: state})
    room_id
  end

  describe "tiezhang:mishi do_open" do
    test "注册到 RoomActionHandlers" do
      assert Kantele.World.RoomActionHandlers.lookup("tiezhang:mishi", "do_open") ==
               {:ok, {TiezhangOpen, :run}}
    end

    test "身上无掌谱 → 发铁掌掌谱 + 文案" do
      result = TiezhangOpen.run(conn(@tiezhang_room), %{trailing: "he", room_id: @tiezhang_room})

      assert output(result) == "你用力打开石盒，发现里面有一本落满尘土的书籍。你急忙把它捡起揣在怀中。\n"
      assert [%{item_id: "tiezhang:zhangpu"}] = character_of(result).inventory
    end

    test "别名 shi he 同样可取" do
      result =
        TiezhangOpen.run(conn(@tiezhang_room), %{trailing: "shi he", room_id: @tiezhang_room})

      assert [%{item_id: "tiezhang:zhangpu"}] = character_of(result).inventory
    end

    test "已有掌谱 → 空空如也，不再发" do
      result =
        TiezhangOpen.run(conn(@tiezhang_room, inventory: [zhangpu()]), %{
          trailing: "he",
          room_id: @tiezhang_room
        })

      assert output(result) == "你用力打开石盒，发现里面空空的什么也没有。\n"
      assert character_of(result).inventory == [zhangpu()]
    end

    test "错词 → 你想打开什么？" do
      result =
        TiezhangOpen.run(conn(@tiezhang_room), %{trailing: "box", room_id: @tiezhang_room})

      assert output(result) == "你想打开什么？\n"
      assert character_of(result).inventory == []
    end

    test "空参数 → 你想打开什么？" do
      assert TiezhangOpen.run(conn(@tiezhang_room), %{trailing: "", room_id: @tiezhang_room})
             |> output() == "你想打开什么？\n"
    end
  end

  describe "wudu:mishi do_open" do
    test "注册到 RoomActionHandlers" do
      assert Kantele.World.RoomActionHandlers.lookup("wudu:mishi", "do_open") ==
               {:ok, {WuduOpen, :run}}
    end

    test "arg != xia → :not_handled（放行全局 open）" do
      assert WuduOpen.run(conn(@wudu_room), %{trailing: "box", room_id: @wudu_room}) ==
               :not_handled

      assert WuduOpen.run(conn(@wudu_room), %{trailing: "", room_id: @wudu_room}) ==
               :not_handled
    end

    test "can_learn flag 未设 → 空空如也（语料无 set 点，分支不可达）" do
      room_id = start_wudu_room()

      result = WuduOpen.run(conn(room_id), %{trailing: "xia", room_id: room_id})

      assert output(result) == "\n你打开石匣，但见里面空空如也。\n"
      assert character_of(result).inventory == []
    end

    test "flag 已设 + mishi_book 在 → 发秘笈 + 广播 + 状态扣减" do
      room_id = start_wudu_room(%{})

      result =
        WuduOpen.run(
          conn(room_id, attributes: %{@flag => 1}),
          %{trailing: "xia", room_id: room_id}
        )

      assert [%{item_id: "wudu:qianzhumiji"}] = character_of(result).inventory
      assert published(result) == ["{npc}打开石匣，发现内有一束绢册，连忙取了出来。\n"]
      assert Room.get_state_by_id(room_id, "mishi_book") == 0
    end

    test "秘笈已取（状态归零）→ 再开也是空空如也" do
      room_id = start_wudu_room(%{"mishi_book" => 0})

      result =
        WuduOpen.run(
          conn(room_id, attributes: %{@flag => 1}),
          %{trailing: "xia", room_id: room_id}
        )

      assert output(result) == "\n你打开石匣，但见里面空空如也。\n"
      assert character_of(result).inventory == []
    end

    test "flag 从 meta.env 读取也认（两级读取）" do
      room_id = start_wudu_room()

      result =
        WuduOpen.run(
          conn(room_id, meta: %PlayerMeta{temp: %{}, env: %{@flag => true}}),
          %{trailing: "xia", room_id: room_id}
        )

      assert [%{item_id: "wudu:qianzhumiji"}] = character_of(result).inventory
    end
  end

  describe "shaolin:zhonglou7 do_knock（敲钟）" do
    test "注册到 RoomActionHandlers" do
      assert Kantele.World.RoomActionHandlers.lookup("shaolin:zhonglou7", "do_knock") ==
               {:ok, {Kantele.World.RoomActions.Shaolin.Zhonglou7.Knock, :run}}
    end

    test "错词 → 你要敲什麽？（繁体逐字保留）" do
      result =
        Zhonglou7Knock.run(conn(@tiezhang_room), %{trailing: "door", room_id: @tiezhang_room})

      assert output(result) == "你要敲什麽？\n"
    end

    test "knock bell → 扣 qi 20 + 房间广播 + 私发警示 + combat_exp ±" do
      stats = %Stats{combat_exp: 1_000}

      result =
        Zhonglou7Knock.run(
          conn(@tiezhang_room,
            meta: %PlayerMeta{stats: stats, vitals: %Vitals{qi: 100}}
          ),
          %{trailing: "bell", room_id: @tiezhang_room}
        )

      character = character_of(result)
      assert character.meta.vitals.qi == 80
      assert character.meta.stats.combat_exp in [998, 1_001]
      assert published(result) == ["{npc}敲了一下大钟，『咣……』声音传遍整个寺庙。\n"]

      assert output(result) =~
               "钟声如迅雷般在你耳边炸响，你头脑中一片糊涂，"
    end
  end
end
