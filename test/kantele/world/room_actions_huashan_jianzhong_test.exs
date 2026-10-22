defmodule Kantele.World.RoomActions.Huashan.JianzhongTest.FakeRoom do
  use GenServer

  def start_link({room_id, opts}) do
    GenServer.start_link(__MODULE__, {room_id, opts}, name: {:global, {Kalevala.World.Room, room_id}})
  end

  @impl true
  def init({room_id, opts}) do
    {:ok,
     %{
       data: %Kantele.World.Room{id: room_id, state: Keyword.get(opts, :state, %{})},
       private: %{
         characters: Keyword.get(opts, :characters, []),
         item_instances: []
       }
     }}
  end
end

defmodule Kantele.World.RoomActions.Huashan.JianzhongTest do
  @moduledoc """
  P5-4i：华山剑冢「look fen + move big stone + pick fir/sec/thi sword + jump lianhua」
  （`d/huashan/jianzhong.c`）。
  """

  use ExUnit.Case, async: false

  alias Kantele.Character.Combat
  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kalevala.World.Item
  alias Kantele.World.ItemDescHandlers
  alias Kantele.World.ItemDescHandlers.RoomStateTiers
  alias Kalevala.World.Room.Context
  alias Kantele.World.Items
  alias Kantele.World.Loader
  alias Kantele.World.Room
  alias Kantele.World.RoomActionHandlers
  alias Kantele.World.RoomActions.Huashan.Jianzhong.Jump
  alias Kantele.World.RoomActions.Huashan.Jianzhong.Move
  alias Kantele.World.RoomActions.Huashan.Jianzhong.Pick
  alias Kantele.World.RoomActions.Huashan.JianzhongTest.FakeRoom

  @room "huashan:jianzhong"

  @fen_config %{
    "kind" => "room_state_tiers",
    "tiers" => [
      %{"match" => %{"moved" => 0, "xuantie_taken" => 0, "noname_taken" => 0},
        "text" => "想必这就是剑魔独孤求败埋剑的地方，上面堆满了大石（big stone）。"},
      %{"match" => %{"moved" => 1, "xuantie_taken" => 0, "noname_taken" => 0},
        "text" => "剑冢下露出并列着的三柄长剑。在第一（fir sword）、第二（sec sword）把剑之间，另有一块长条石片（piece）。三柄剑和石片并列於一块大青石之上。"},
      %{"match" => %{"moved" => 1, "xuantie_taken" => 1, "noname_taken" => 0},
        "text" => "剑冢下露出并列着的两柄长剑，在第一（fir sword）的右边另有一块长条石片（piece）。而第二把剑已不知去向，只留下石片（sec piece）上所刻的小字。两柄剑和石片并列於一块大青石之上。"},
      %{"match" => %{"moved" => 1, "xuantie_taken" => 0, "noname_taken" => 1},
        "text" => "剑冢下露出并列着的两柄长剑。在第一（fir sword）、第二（sec sword）把剑之间，另有一块长条石片（piece）。而最右首的剑已不知去向，只留下石片（thi piece）上所刻的小字。两柄剑和石片并列於一块大青石之上。"},
      %{"match" => %{"moved" => 1, "xuantie_taken" => 1, "noname_taken" => 1},
        "text" => "剑冢下露出并列着的一柄长剑，在第一（fir sword）的右边另有一块长条石片（piece）。其余的两把剑已不知去向，只留下石片（sec piece、thi piece）上所刻的小字。这柄剑和石片并列於一块大青石之上。"}
    ]
  }

  setup do
    put_item("clone_lib:xuantiejian", %{"name" => "玄铁重剑"})
    put_item("clone_lib:noname", %{"name" => "无名剑"})
    :ok
  end

  defp put_item(item_id, meta) do
    Items.put(item_id, %Kalevala.World.Item{id: item_id, name: Map.get(meta, "name"), meta: %{"value" => 100, "unit" => "把"}})
  end

  # ---- 注册 ----

  test "lookup/2 注册了剑冢的三个房间动作与 item_desc handler" do
    assert ItemDescHandlers.lookup(@room, "room_state_tiers") == {:ok, {RoomStateTiers, :run}}
    assert RoomActionHandlers.lookup(@room, "do_move") == {:ok, {Move, :run}}
    assert RoomActionHandlers.lookup(@room, "do_pick") == {:ok, {Pick, :run}}
    assert RoomActionHandlers.lookup(@room, "do_jump") == {:ok, {Jump, :run}}
  end

  # ---- Loader state 播种 ----

  test "UCL state 键归一化为字符串并保留整数" do
    base = %{
      name: "剑冢",
      description: "坟（fen）背向山谷，旁立有一大石（stone）。",
      x: 0,
      y: 0,
      z: 2,
      item_desc: %{"fen" => @fen_config},
      actions: %{"jump" => "do_jump", "move" => "do_move", "pick" => "do_pick"},
      state: %{"moved" => 0, "xuantie_taken" => 0, "noname_taken" => 0}
    }

    {_key, room} = Loader.parse_room(%{id: "huashan"}, "jianzhong", base, %{})

    assert room.state == %{"moved" => 0, "xuantie_taken" => 0, "noname_taken" => 0}
    assert room.item_desc["fen"] == @fen_config
  end

  # ---- look fen ----

  describe "look fen（RoomStateTiers）" do
    test "未移石时提示大石" do
      assert fen_text(%{"moved" => 0, "xuantie_taken" => 0, "noname_taken" => 0}) ==
               "想必这就是剑魔独孤求败埋剑的地方，上面堆满了大石（big stone）。\n"
    end

    test "移石后且两剑在 → 三柄长剑" do
      assert fen_text(%{"moved" => 1, "xuantie_taken" => 0, "noname_taken" => 0}) ==
               "剑冢下露出并列着的三柄长剑。在第一（fir sword）、第二（sec sword）把剑之间，另有一块长条石片（piece）。三柄剑和石片并列於一块大青石之上。\n"
    end

    test "玄铁剑已取 → 剩两柄且 sec piece 留下小字" do
      assert fen_text(%{"moved" => 1, "xuantie_taken" => 1, "noname_taken" => 0}) ==
               "剑冢下露出并列着的两柄长剑，在第一（fir sword）的右边另有一块长条石片（piece）。而第二把剑已不知去向，只留下石片（sec piece）上所刻的小字。两柄剑和石片并列於一块大青石之上。\n"
    end

    test "无名剑已取 → 剩两柄且 thi piece 留下小字" do
      assert fen_text(%{"moved" => 1, "xuantie_taken" => 0, "noname_taken" => 1}) ==
               "剑冢下露出并列着的两柄长剑。在第一（fir sword）、第二（sec sword）把剑之间，另有一块长条石片（piece）。而最右首的剑已不知去向，只留下石片（thi piece）上所刻的小字。两柄剑和石片并列於一块大青石之上。\n"
    end

    test "两剑均取 → 仅剩一柄长剑" do
      assert fen_text(%{"moved" => 1, "xuantie_taken" => 1, "noname_taken" => 1}) ==
               "剑冢下露出并列着的一柄长剑，在第一（fir sword）的右边另有一块长条石片（piece）。其余的两把剑已不知去向，只留下石片（sec piece、thi piece）上所刻的小字。这柄剑和石片并列於一块大青石之上。\n"
    end

    test "缺键不误命中：只有 moved=1 时落兜底" do
      assert fen_text(%{"moved" => 1}) == "这里没有这个东西。\n"
    end
  end

  # ---- move big stone ----

  describe "move big stone" do
    test "参数错误 → 你要干什么？" do
      assert move("stone", start_room()) |> output() == "你要干什么？\n"
    end

    test "首次移开石头 → 文案 + state.moved = 1" do
      room_id = start_room()

      assert move("big stone", room_id) |> output() == "$N用力将剑冢上面的石头一块块地移开 ……\n"
      assert Room.get_state_by_id(room_id, "moved") == 1
    end

    test "再次移开石头 → 已经被移开了" do
      room_id = start_room(%{"moved" => 1})

      assert move("big stone", room_id) |> output() == "上面的石头已经被移开了！\n"
      assert Room.get_state_by_id(room_id, "moved") == 1
    end
  end

  # ---- pick swords ----

  describe "pick sword" do
    test "未移开石头 → 你要干什么？" do
      assert pick("fir sword", start_room()) |> output() == "你要干什么？\n"
      assert pick("sec sword", start_room()) |> output() == "你要干什么？\n"
      assert pick("thi sword", start_room()) |> output() == "你要干什么？\n"
    end

    test "未知目标 → 你要取什么？" do
      assert pick("piece", start_room(%{"moved" => 1})) |> output() == "你要取什么？\n"
    end

    test "fir sword 移石后 → 只看不拿" do
      assert pick("fir sword", start_room(%{"moved" => 1})) |> output() ==
               "你将竹剑拿起来看了看，觉得普通之极，便又放了回去。\n"
    end

    test "sec sword 玄铁已取 → 上面的东西已被人拿走了" do
      assert pick("sec sword", start_room(%{"moved" => 1, "xuantie_taken" => 1})) |> output() ==
               "上面的东西已被人拿走了！\n"
    end

    test "sec sword 力量不足 → 脱手火花" do
      character = %{stats: %Stats{str: 10}, combat: %Combat{}}
      assert pick("sec sword", start_room(%{"moved" => 1}, character: character)) |> output() ==
               "你将铁剑只提起数尺，呛的一声，竟然脱手掉下，在石上一碰，火花四溅，不禁吓了一跳。\n"
    end

    test "sec sword 成功 → 发玄铁重剑 + state.xuantie_taken=1 + 播报" do
      room_id = start_room(%{"moved" => 1}, character: full_character(str: 40))

      result = pick("sec sword", room_id)

      assert output(result) == "" 
      assert published(result) == ["$N将玄铁重剑提了起来。\n"]
      assert Room.get_state_by_id(room_id, "xuantie_taken") == 1
      assert [%{item_id: "clone_lib:xuantiejian"}] = character_of(result).inventory
    end

    test "thi sword 已取 → 上面的东西已被人拿走了" do
      assert pick("thi sword", start_room(%{"moved" => 1, "noname_taken" => 1})) |> output() ==
               "上面的东西已被人拿走了！\n"
    end

    test "thi sword 成功 → 发无名剑 + state.noname_taken=1 + 播报" do
      room_id = start_room(%{"moved" => 1}, character: full_character(str: 40))

      result = pick("thi sword", room_id)

      assert published(result) == ["$N将无名剑提了起来。\n"]
      assert Room.get_state_by_id(room_id, "noname_taken") == 1
      assert [%{item_id: "clone_lib:noname"}] = character_of(result).inventory
    end
  end

  # ---- jump lianhua（守门条件；落点房间在完整世界加载后再做端到端） ----

  describe "jump lianhua" do
    test "参数错误 → 你要往哪儿跳？" do
      assert jump("", start_room()) |> output() == "你要往哪儿跳？\n"
      assert jump("stone", start_room()) |> output() == "你要往哪儿跳？\n"
    end

    test "qi 不足 → 你力气不加" do
      character = full_character(qi: 100)
      assert jump("lianhua", start_room(character: character)) |> output() == "你力气不加。\n"
    end

    test "忙乱中 → 等你忙完了再说" do
      character = full_character(qi: 999, combat: %Combat{busy: 2})
      assert jump("lianhua", start_room(character: character)) |> output() == "等你忙完了再说。\n"
    end

    test "战斗中 → 等你忙完了再说" do
      character = full_character(qi: 999, combat: %Combat{enemies: [%{id: "enemy1"}]})
      assert jump("lianhua", start_room(character: character)) |> output() == "等你忙完了再说。\n"
    end
  end

  # ---- helpers ----

  defp start_room(state \\ %{"moved" => 0, "xuantie_taken" => 0, "noname_taken" => 0}, opts \\ []) do
    room_id = "test:jianzhong-#{System.unique_integer([:positive])}"
    start_supervised!({FakeRoom, {room_id, [state: state] ++ opts}}, id: room_id)
    room_id
  end

  defp full_character(opts \\ []) do
    %Kalevala.Character{
      name: "玩家",
      room_id: @room,
      meta: %PlayerMeta{
        stats: %Stats{str: Keyword.get(opts, :str, 40)},
        combat: Keyword.get(opts, :combat, %Combat{}),
        vitals: %Vitals{qi: Keyword.get(opts, :qi, 999), max_qi: Keyword.get(opts, :max_qi, 999)}
      },
      inventory: []
    }
  end

  defp move(arg, room_id) do
    Move.run(conn(room_id), %{verb: "move", trailing: arg, room_id: room_id})
  end

  defp pick(arg, room_id) do
    Pick.run(conn(room_id), %{verb: "pick", trailing: arg, room_id: room_id})
  end

  defp jump(arg, room_id) do
    Jump.run(conn(room_id), %{verb: "jump", trailing: arg, room_id: room_id})
  end

  defp conn(room_id \\ @room) do
    %Conn{
      character: %Kalevala.Character{
        name: "玩家",
        room_id: room_id,
        meta: %PlayerMeta{
          stats: %Stats{str: 40},
          combat: %Combat{},
          vitals: %Vitals{qi: 999, max_qi: 999}
        },
        inventory: []
      },
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp fen_text(state) do
    context = %Kantele.World.Room.Context{data: %Room{id: @room, state: state}}

    context
    |> RoomStateTiers.run(%{pid: self()}, %{config: @fen_config, room_id: @room})
    |> context_output()
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

  defp context_output(%{output: output}) do
    Enum.map_join(output, fn {_pid, %{data: data}} -> data end)
  end
end
